/**
 * Next.js Route Handler – proxies the SSE stream from orders-api.
 * This is needed because Next.js rewrites buffer responses, which
 * prevents EventSource from receiving streamed chunks in real-time.
 */

const API_URL = () => process.env.API_URL || 'http://localhost:3000';

export const dynamic = 'force-dynamic';   // never cache
export const runtime  = 'nodejs';          // need Node stream support

export async function GET() {
  const upstream = await fetch(`${API_URL()}/api/events/stream`, {
    headers: { Accept: 'text/event-stream' },
    cache: 'no-store',
  });

  if (!upstream.ok || !upstream.body) {
    return new Response('upstream unavailable', { status: 502 });
  }

  // Pipe the upstream ReadableStream straight through
  return new Response(upstream.body as ReadableStream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache, no-transform',
      Connection: 'keep-alive',
      'X-Accel-Buffering': 'no',
    },
  });
}
