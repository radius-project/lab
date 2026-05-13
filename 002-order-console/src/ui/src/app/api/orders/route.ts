/**
 * Next.js Route Handler – proxies GET/POST /api/orders to orders-api at runtime.
 * This avoids the Next.js rewrites limitation where destination URLs are baked at build time.
 */

const API_URL = () => process.env.API_URL || 'http://localhost:3000';

export const dynamic = 'force-dynamic';

export async function GET() {
  const res = await fetch(`${API_URL()}/api/orders`, { cache: 'no-store' });
  const data = await res.json();
  return Response.json(data, { status: res.status });
}

export async function POST(request: Request) {
  const body = await request.json();
  const res = await fetch(`${API_URL()}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    cache: 'no-store',
  });
  const data = await res.json();
  return Response.json(data, { status: res.status });
}
