'use client';

import { useState, useEffect, useRef, FormEvent } from 'react';

/* ── types ───────────────────────────────────────────────── */

interface Order {
  orderId: string;
  customerName: string;
  itemSku: string;
  quantity: number;
  status: string;
  createdAt: string;
  lastUpdated: string;
}

interface AppEvent {
  timestamp: string;
  eventType: string;
  orderId: string;
  source: string;
  message: string;
}

/* ── helpers ─────────────────────────────────────────────── */

const STATUS_COLOR: Record<string, string> = {
  NEW: '#3b82f6',
  PROCESSING: '#f59e0b',
  FULFILLED: '#10b981',
  FAILED: '#ef4444',
};

const EVENT_COLOR: Record<string, string> = {
  OrderCreated: '#3b82f6',
  OrderProcessing: '#f59e0b',
  OrderFulfilled: '#10b981',
  OrderFailed: '#ef4444',
};

function short(id: string) {
  return id.length > 8 ? id.slice(0, 8) + '…' : id;
}

function fmtTime(iso: string) {
  return new Date(iso).toLocaleTimeString();
}

/* ── component ───────────────────────────────────────────── */

export default function Home() {
  const [events, setEvents] = useState<AppEvent[]>([]);
  const [order, setOrder] = useState<Order | null>(null);
  const [recentIds, setRecentIds] = useState<string[]>([]);
  const [searchId, setSearchId] = useState('');
  const [customerName, setCustomerName] = useState('');
  const [itemSku, setItemSku] = useState('');
  const [quantity, setQuantity] = useState(1);
  const [submitting, setSubmitting] = useState(false);
  const [connected, setConnected] = useState(false);
  const streamRef = useRef<HTMLDivElement>(null);

  // SSE connection for live events
  useEffect(() => {
    const es = new EventSource('/api/events/stream');
    es.onopen = () => setConnected(true);
    es.onmessage = (msg) => {
      try {
        const evt: AppEvent = JSON.parse(msg.data);
        setEvents(prev => {
          const next = [...prev, evt];
          return next.length > 100 ? next.slice(-100) : next;
        });
      } catch { /* skip bad data */ }
    };
    es.onerror = () => setConnected(false);
    return () => es.close();
  }, []);

  // Poll recent-orders index
  useEffect(() => {
    const load = async () => {
      try {
        const r = await fetch('/api/orders');
        const d = await r.json();
        setRecentIds(d.orderIds || []);
      } catch { /* ignore */ }
    };
    load();
    const id = setInterval(load, 3000);
    return () => clearInterval(id);
  }, []);

  // Auto-scroll event stream
  useEffect(() => {
    streamRef.current?.scrollTo({ top: streamRef.current.scrollHeight, behavior: 'smooth' });
  }, [events]);

  // Submit one order
  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      const r = await fetch('/api/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ customerName, itemSku, quantity }),
      });
      const data = await r.json();
      if (r.ok) {
        setOrder(data);
        setSearchId(data.orderId);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setSubmitting(false);
    }
  };

  // Generate 10 random orders
  const handleGenerate10 = async () => {
    setSubmitting(true);
    const skus = ['Running Shoes', 'Laptop Stand', 'Wireless Earbuds', 'Yoga Mat', 'Coffee Maker', 'Backpack', 'Sunglasses', 'Water Bottle', 'Desk Lamp', 'Phone Case'];
    const names = ['Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank', 'Grace', 'Heidi', 'Ivan', 'Judy'];
    try {
      for (let i = 0; i < 10; i++) {
        await fetch('/api/orders', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            customerName: names[i],
            itemSku: skus[i % skus.length],
            quantity: (i % 5) + 1,
          }),
        });
      }
    } catch (err) {
      console.error(err);
    } finally {
      setSubmitting(false);
    }
  };

  // Lookup an order by id
  const lookupOrder = async (id: string) => {
    if (!id) return;
    try {
      const r = await fetch(`/api/orders/${id}`);
      if (r.ok) {
        setOrder(await r.json());
        setSearchId(id);
      } else {
        setOrder(null);
      }
    } catch { /* ignore */ }
  };

  /* ── styles (inline for zero-config) ───────────────────── */

  const panel: React.CSSProperties = {
    background: 'var(--surface)',
    border: '1px solid var(--border)',
    borderRadius: 12,
    padding: 20,
    display: 'flex',
    flexDirection: 'column',
    gap: 12,
    minHeight: 0,
  };

  const label: React.CSSProperties = {
    fontSize: 11,
    textTransform: 'uppercase',
    letterSpacing: '0.08em',
    color: 'var(--text-dim)',
    fontWeight: 600,
  };

  const input: React.CSSProperties = {
    width: '100%',
    padding: '8px 12px',
    border: '1px solid var(--border)',
    borderRadius: 8,
    background: 'var(--surface2)',
    color: 'var(--text)',
    fontSize: 14,
    outline: 'none',
  };

  const btn: React.CSSProperties = {
    padding: '10px 16px',
    border: 'none',
    borderRadius: 8,
    fontWeight: 600,
    fontSize: 14,
    cursor: 'pointer',
    transition: 'opacity 0.15s',
  };

  const chip = (color: string): React.CSSProperties => ({
    display: 'inline-block',
    padding: '2px 10px',
    borderRadius: 999,
    fontSize: 12,
    fontWeight: 700,
    background: color + '22',
    color,
    border: `1px solid ${color}44`,
  });

  /* ── render ────────────────────────────────────────────── */

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <header style={{
        padding: '16px 24px',
        borderBottom: '1px solid var(--border)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <h1 style={{ fontSize: 20, fontWeight: 700 }}>Order Console</h1>
          <span style={{
            ...chip('#6366f1'),
            fontSize: 10,
          }}>local</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{
            width: 8, height: 8, borderRadius: '50%',
            background: connected ? 'var(--green)' : 'var(--red)',
          }} />
          <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>
            {connected ? 'SSE connected' : 'Reconnecting…'}
          </span>
        </div>
      </header>

      {/* 3-column layout */}
      <main style={{
        flex: 1,
        display: 'grid',
        gridTemplateColumns: '300px 1fr 340px',
        gap: 16,
        padding: 16,
        minHeight: 0,
        overflow: 'hidden',
      }}>
        {/* ── Left: Create Order ─────────────────────────── */}
        <div style={{ ...panel, overflow: 'auto' }}>
          <span style={label}>Create Order</span>
          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            <div>
              <span style={{ ...label, fontSize: 10 }}>Customer Name</span>
              <input
                style={input}
                placeholder="e.g. Alice"
                value={customerName}
                onChange={e => setCustomerName(e.target.value)}
              />
            </div>
            <div>
              <span style={{ ...label, fontSize: 10 }}>Item SKU</span>
              <input
                style={input}
                placeholder="e.g. WIDGET-A"
                value={itemSku}
                onChange={e => setItemSku(e.target.value)}
              />
            </div>
            <div>
              <span style={{ ...label, fontSize: 10 }}>Quantity</span>
              <input
                style={input}
                type="number"
                min={1}
                value={quantity}
                onChange={e => setQuantity(Number(e.target.value))}
              />
            </div>
            <button
              type="submit"
              disabled={submitting}
              style={{ ...btn, background: 'var(--accent)', color: '#fff', opacity: submitting ? 0.5 : 1 }}
            >
              Submit Order
            </button>
          </form>

          <div style={{ borderTop: '1px solid var(--border)', paddingTop: 12 }}>
            <button
              onClick={handleGenerate10}
              disabled={submitting}
              style={{ ...btn, width: '100%', background: 'var(--surface2)', color: 'var(--text)', border: '1px solid var(--border)', opacity: submitting ? 0.5 : 1 }}
            >
              Generate 10 Orders
            </button>
          </div>
        </div>

        {/* ── Middle: Live Event Stream ──────────────────── */}
        <div style={{ ...panel, overflow: 'hidden' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={label}>Live Event Stream</span>
            <span style={{ fontSize: 11, color: 'var(--text-dim)' }}>{events.length} events</span>
          </div>
          <div
            ref={streamRef}
            style={{
              flex: 1,
              overflow: 'auto',
              display: 'flex',
              flexDirection: 'column',
              gap: 4,
              fontSize: 13,
            }}
          >
            {events.length === 0 && (
              <div style={{ color: 'var(--text-dim)', textAlign: 'center', padding: 40 }}>
                No events yet. Submit an order to get started.
              </div>
            )}
            {events.map((e, i) => (
              <div
                key={i}
                style={{
                  display: 'grid',
                  gridTemplateColumns: '70px 130px 1fr 110px',
                  gap: 8,
                  padding: '6px 10px',
                  background: i % 2 === 0 ? 'transparent' : 'var(--surface2)',
                  borderRadius: 6,
                  alignItems: 'center',
                }}
              >
                <span style={{ color: 'var(--text-dim)', fontSize: 11, fontFamily: 'monospace' }}>
                  {fmtTime(e.timestamp)}
                </span>
                <span style={chip(EVENT_COLOR[e.eventType] || '#6b7280')}>
                  {e.eventType}
                </span>
                <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {e.message}
                </span>
                <span
                  style={{ fontFamily: 'monospace', fontSize: 11, color: 'var(--accent)', cursor: 'pointer' }}
                  onClick={() => lookupOrder(e.orderId)}
                  title={e.orderId}
                >
                  {short(e.orderId)}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* ── Right: Order State Viewer ──────────────────── */}
        <div style={{ ...panel, overflow: 'auto' }}>
          <span style={label}>Order State Viewer</span>

          {/* Search */}
          <div style={{ display: 'flex', gap: 6 }}>
            <input
              style={{ ...input, flex: 1, fontSize: 12 }}
              placeholder="Paste orderId to look up…"
              value={searchId}
              onChange={e => setSearchId(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && lookupOrder(searchId)}
            />
            <button
              onClick={() => lookupOrder(searchId)}
              style={{ ...btn, background: 'var(--surface2)', color: 'var(--text)', border: '1px solid var(--border)', fontSize: 12, padding: '6px 12px' }}
            >
              Go
            </button>
          </div>

          {/* Order detail card */}
          {order && (
            <div style={{
              background: 'var(--surface2)',
              borderRadius: 8,
              padding: 14,
              fontSize: 13,
              display: 'flex',
              flexDirection: 'column',
              gap: 8,
              border: '1px solid var(--border)',
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontWeight: 700 }}>Order Detail</span>
                <span style={chip(STATUS_COLOR[order.status] || '#6b7280')}>{order.status}</span>
              </div>
              <div style={{ fontFamily: 'monospace', fontSize: 11, color: 'var(--text-dim)', wordBreak: 'break-all' }}>
                {order.orderId}
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 6, fontSize: 12 }}>
                <div><span style={{ color: 'var(--text-dim)' }}>Customer:</span> {order.customerName}</div>
                <div><span style={{ color: 'var(--text-dim)' }}>SKU:</span> {order.itemSku}</div>
                <div><span style={{ color: 'var(--text-dim)' }}>Qty:</span> {order.quantity}</div>
                <div><span style={{ color: 'var(--text-dim)' }}>Created:</span> {fmtTime(order.createdAt)}</div>
              </div>
              <div style={{ fontSize: 11, color: 'var(--text-dim)' }}>
                Updated: {new Date(order.lastUpdated).toLocaleString()}
              </div>
              <button
                onClick={() => lookupOrder(order.orderId)}
                style={{ ...btn, fontSize: 11, padding: '4px 10px', background: 'var(--surface)', color: 'var(--text-dim)', border: '1px solid var(--border)' }}
              >
                Refresh
              </button>
            </div>
          )}

          {/* Recent orders */}
          <div style={{ borderTop: '1px solid var(--border)', paddingTop: 10 }}>
            <span style={{ ...label, fontSize: 10 }}>Recent Orders</span>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2, marginTop: 6 }}>
              {recentIds.length === 0 && (
                <span style={{ fontSize: 12, color: 'var(--text-dim)' }}>None yet</span>
              )}
              {recentIds.slice(0, 15).map(id => (
                <div
                  key={id}
                  onClick={() => lookupOrder(id)}
                  style={{
                    fontFamily: 'monospace',
                    fontSize: 11,
                    padding: '4px 8px',
                    borderRadius: 4,
                    cursor: 'pointer',
                    color: 'var(--accent)',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}
                  onMouseEnter={e => (e.currentTarget.style.background = 'var(--surface2)')}
                  onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                >
                  {id}
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}
