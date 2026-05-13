/**
 * Next.js Route Handler – proxies GET /api/events to orders-api at runtime.
 */

const API_URL = () => process.env.API_URL || 'http://localhost:3000';

export const dynamic = 'force-dynamic';

export async function GET() {
  const res = await fetch(`${API_URL()}/api/events`, { cache: 'no-store' });
  const data = await res.json();
  return Response.json(data, { status: res.status });
}
