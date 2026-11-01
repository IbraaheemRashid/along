export class APIError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function json(value, status = 200, extra = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
      ...extra,
    },
  });
}

export function object(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

export function exactKeys(value, allowed) {
  if (!object(value) || Object.keys(value).some(key => !allowed.includes(key))) {
    throw new APIError(400, 'invalid_fields', 'The request contains unsupported fields.');
  }
}

// Bound the bytes actually read; Content-Length alone is untrusted and optional.
export async function readJSON(request, maxBytes = 8192) {
  if (!/^application\/json(?:\s*;|$)/i.test(request.headers.get('content-type') || '')) {
    throw new APIError(415, 'json_required', 'Send application/json.');
  }
  if (Number(request.headers.get('content-length')) > maxBytes) {
    throw new APIError(413, 'body_too_large', 'The request is too large.');
  }
  if (!request.body) throw new APIError(400, 'invalid_json', 'Send a JSON object.');
  const reader = request.body.getReader();
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let bytes = 0;
  let text = '';
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > maxBytes) {
        await reader.cancel();
        throw new APIError(413, 'body_too_large', 'The request is too large.');
      }
      text += decoder.decode(value, { stream: true });
    }
    text += decoder.decode();
    const data = JSON.parse(text);
    if (!object(data)) throw new Error('Object required');
    return data;
  } catch (error) {
    if (error instanceof APIError) throw error;
    throw new APIError(400, 'invalid_json', 'Send a valid JSON object.');
  } finally {
    reader.releaseLock();
  }
}

export function isLocalDemo(request, env) {
  const url = new URL(request.url);
  return env.APP_ENV === 'local' && env.DEMO_MODE === 'true'
    && ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
}

export function requireLocalDemo(request, env) {
  if (!isLocalDemo(request, env)) {
    throw new APIError(503, 'live_not_configured', 'Live accounts and journal sync are not configured.');
  }
}

export function checkOrigin(request, env) {
  const origin = request.headers.get('origin');
  if (!origin) return {};
  // No wildcard or suffix matching. Native clients do not send Origin.
  const permitted = env.WEB_ORIGIN && origin === env.WEB_ORIGIN;
  if (!permitted) throw new APIError(403, 'origin_not_allowed', 'This website is not allowed.');
  return {
    'access-control-allow-origin': origin,
    'access-control-allow-methods': 'GET, POST, OPTIONS',
    'access-control-allow-headers': 'Content-Type, Authorization, Accept',
    'access-control-expose-headers': 'set-auth-token',
    'vary': 'Origin',
  };
}

// The demo returns a completed result, not fabricated token streaming.
export function resultStream(result) {
  const body = new ReadableStream({
    start(controller) {
      const encoder = new TextEncoder();
      controller.enqueue(encoder.encode(`event: result\ndata: ${JSON.stringify(result)}\n\n`));
      controller.enqueue(encoder.encode('event: done\ndata: {}\n\n'));
      controller.close();
    },
  });
  return new Response(body, { headers: {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  } });
}
