import express, { Request, Response } from 'express';

const app = express();
app.use(express.json({ type: ['application/json', 'application/cloudevents+json'] }));

const DAPR_PORT = process.env.DAPR_HTTP_PORT || '3500';
const DAPR_URL = `http://localhost:${DAPR_PORT}`;
const STATE_STORE = process.env.CONNECTION_STATESTORE_COMPONENTNAME || 'statestore';
const PUBSUB_NAME = process.env.CONNECTION_PUBSUB_COMPONENTNAME || 'pubsub';
const APP_PORT = parseInt(process.env.APP_PORT || '3002', 10);

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
}

function sleep(ms: number) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/* ── Programmatic Dapr subscription ──────────────────────── */

app.get('/dapr/subscribe', (_req, res) => {
  res.json([
    {
      pubsubname: PUBSUB_NAME,
      topic: 'orders',
      route: '/orders',
    },
  ]);
});

/* ── Fulfillment handler ─────────────────────────────────── */

interface Order {
  orderId: string;
  customerName: string;
  itemSku: string;
  quantity: number;
  status: string;
  createdAt: string;
  lastUpdated: string;
}

app.post('/orders', async (req: Request, res: Response) => {
  const message = req.body?.data || req.body;
  const { orderId } = message || {};

  if (!orderId) {
    console.warn('No orderId in message, skipping');
    return res.sendStatus(200); // ack to Dapr
  }

  console.log(`[fulfillment] Received order ${orderId}`);

  try {
    // Read order from Dapr state store
    const order = await getState<Order>(`order:${orderId}`);
    if (!order) {
      console.warn(`Order ${orderId} not found in state store`);
      return res.sendStatus(200);
    }

    const now = () => new Date().toISOString();

    // ── Step 1: Mark as PROCESSING ──
    order.status = 'PROCESSING';
    order.lastUpdated = now();
    await saveState([{ key: `order:${orderId}`, value: order }]);
    await appendEvent({
      timestamp: now(),
      eventType: 'OrderProcessing',
      orderId,
      source: 'fulfillment-worker',
      message: `Processing order for ${order.customerName}`,
    });
    console.log(`[fulfillment] Order ${orderId} → PROCESSING`);

    // ── Step 2: Simulate work (500–1500 ms) ──
    await sleep(500 + Math.random() * 1000);

    // ── Step 3: Mark as FULFILLED ──
    order.status = 'FULFILLED';
    order.lastUpdated = now();
    await saveState([{ key: `order:${orderId}`, value: order }]);
    await appendEvent({
      timestamp: now(),
      eventType: 'OrderFulfilled',
      orderId,
      source: 'fulfillment-worker',
      message: `Order fulfilled for ${order.customerName}`,
    });
    console.log(`[fulfillment] Order ${orderId} → FULFILLED`);

    res.sendStatus(200);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`[fulfillment] Error processing ${orderId}:`, msg);

    // Try to record failure
    try {
      const order = await getState<Order>(`order:${orderId}`);
      if (order) {
        order.status = 'FAILED';
        order.lastUpdated = new Date().toISOString();
        await saveState([{ key: `order:${orderId}`, value: order }]);
        await appendEvent({
          timestamp: new Date().toISOString(),
          eventType: 'OrderFailed',
          orderId,
          source: 'fulfillment-worker',
          message: `Order failed: ${msg}`,
        });
      }
    } catch { /* best effort */ }

    res.sendStatus(500);
  }
});

/* ── Health ───────────────────────────────────────────────── */

app.get('/healthz', (_req, res) => res.json({ status: 'healthy' }));

/* ── Start ───────────────────────────────────────────────── */

app.listen(APP_PORT, () => {
  console.log(`fulfillment-worker listening on :${APP_PORT}`);
});
