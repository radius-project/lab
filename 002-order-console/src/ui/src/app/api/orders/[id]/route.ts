/**
 * Next.js Route Handler – proxies GET /api/orders/:id to orders-api at runtime.
 */

const API_URL = () => process.env.API_URL || 'http://localhost:3000';

export const dynamic = 'force-dynamic';

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;
  const res = await fetch(`${API_URL()}/api/orders/${id}`, { cache: 'no-store' });
  if (!res.ok) {
    const data = await res.json().catch(() => ({ error: 'Not found' }));
    return Response.json(data, { status: res.status });
  }
  const data = await res.json();
  return Response.json(data, { status: res.status });
}
