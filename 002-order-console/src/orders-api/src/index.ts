import express, { Request, Response } from 'express';
import cors from 'cors';
import { randomUUID } from 'crypto';

const app = express();
app.use(cors());
app.use(express.json({ type: ['application/json', 'application/cloudevents+json'] }));

const DAPR_PORT = process.env.DAPR_HTTP_PORT || '3500';
const DAPR_URL = `http://localhost:${DAPR_PORT}`;
const STATE_STORE = process.env.CONNECTION_STATESTORE_COMPONENTNAME || 'statestore';
const PUBSUB_NAME = process.env.CONNECTION_PUBSUB_COMPONENTNAME || 'pubsub';
const TOPIC = 'orders';
const APP_PORT = parseInt(process.env.APP_PORT || '3000', 10);

/* ── Dapr helpers ────────────────────────────────────────── */

async function saveState(items: { key: string; value: unknown }[]) {
  const res = await fetch(`${DAPR_URL}/v1.0/state/${STATE_STORE}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(items),
  });
  if (!res.ok) throw new Error(`saveState failed ${res.status}: ${await res.text()}`);
}

async function getState<T = unknown>(key: string): Promise<T | null> {
  const res = await fetch(`${DAPR_URL}/v1.0/state/${STATE_STORE}/${key}`);
  if (res.status === 204 || res.status === 404) return null;
  if (!res.ok) throw new Error(`getState failed ${res.status}: ${await res.text()}`);
  return (await res.json()) as T;
}

async function publishMessage(topic: string, data: unknown) {
  const res = await fetch(`${DAPR_URL}/v1.0/publish/${PUBSUB_NAME}/${topic}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`publish failed ${res.status}: ${await res.text()}`);
}

/* ── Event ring-buffer helper ────────────────────────────── */

interface AppEvent {
  timestamp: string;
  eventType: string;
  orderId: string;
  source: string;
  message: string;
}

async function appendEvent(event: AppEvent) {
  const events: AppEvent[] = (await getState<AppEvent[]>('events:recent')) || [];
  events.push(event);
  if (events.length > 100) events.splice(0, events.length - 100);
  await saveState([{ key: 'events:recent', value: events }]);
  return event;
}

/* ── Routes ──────────────────────────────────────────────── */

// Health
app.get('/healthz', async (_req, res) => {
  try {
    const r = await fetch(`${DAPR_URL}/v1.0/metadata`);
    res.json({ status: 'healthy', dapr: r.ok });
  } catch {
    res.status(503).json({ status: 'unhealthy' });
  }
});

// Create order
app.post('/api/orders', async (req: Request, res: Response) => {
  try {
    const { customerName, itemSku, quantity } = req.body;
    const orderId = randomUUID();
    const now = new Date().toISOString();

    const order = {
      orderId,
      customerName: customerName || 'Walk-in Customer',
      itemSku: itemSku || 'GENERIC',
      quantity: Math.max(1, Number(quantity) || 1),
      status: 'NEW',
      createdAt: now,
      lastUpdated: now,
    };

    // 1. Persist order in Dapr state store
    await saveState([{ key: `order:${orderId}`, value: order }]);

    // 2. Append OrderCreated event
    await appendEvent({
      timestamp: now,
      eventType: 'OrderCreated',
      orderId,
      source: 'orders-api',
      message: `Order created for ${order.customerName} — ${order.quantity}× ${order.itemSku}`,
    });

    // 3. Update recent orders index
    const index: string[] = (await getState<string[]>('orders:index')) || [];
    index.unshift(orderId);
    if (index.length > 50) index.length = 50;
    await saveState([{ key: 'orders:index', value: index }]);

    // 4. Publish to Kafka via Dapr pub/sub
    await publishMessage(TOPIC, {
      orderId,
      customerName: order.customerName,
      itemSku: order.itemSku,
      quantity: order.quantity,
      createdAt: now,
    });

    console.log(`Order ${orderId} created and published`);
    res.status(201).json(order);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('POST /api/orders error:', msg);
    res.status(500).json({ error: msg });
  }
});

// Get single order
app.get('/api/orders/:orderId', async (req: Request, res: Response) => {
  try {
    const order = await getState(`order:${req.params.orderId}`);
    if (!order) return res.status(404).json({ error: 'Order not found' });
    res.json(order);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: msg });
  }
});

// List recent order IDs
app.get('/api/orders', async (_req: Request, res: Response) => {
  try {
    const index = (await getState<string[]>('orders:index')) || [];
    res.json({ orderIds: index });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: msg });
  }
});

// Events (polling)
app.get('/api/events', async (_req: Request, res: Response) => {
  try {
    const events = (await getState<AppEvent[]>('events:recent')) || [];
    res.json(events);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: msg });
  }
});

// Events SSE stream
app.get('/api/events/stream', async (req: Request, res: Response) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no');
  res.flushHeaders();

  // Send initial batch
  let lastTimestamp = '';
  try {
    const events = (await getState<AppEvent[]>('events:recent')) || [];
    for (const evt of events) {
      res.write(`data: ${JSON.stringify(evt)}\n\n`);
    }
    if (events.length > 0) {
      lastTimestamp = events[events.length - 1].timestamp;
    }
  } catch { /* ignore */ }

  // Poll state for new events (captures both orders-api and worker events)
  const interval = setInterval(async () => {
    try {
      const events = (await getState<AppEvent[]>('events:recent')) || [];
      const newer = events.filter(e => e.timestamp > lastTimestamp);
      for (const evt of newer) {
        res.write(`data: ${JSON.stringify(evt)}\n\n`);
      }
      if (events.length > 0) {
        lastTimestamp = events[events.length - 1].timestamp;
      }
    } catch { /* ignore transient errors */ }
  }, 1000);

  req.on('close', () => clearInterval(interval));
});

/* ── Start ───────────────────────────────────────────────── */

app.listen(APP_PORT, () => {
  console.log(`orders-api listening on :${APP_PORT}`);
});
