// Local test harness for the SAME fetch handler used by Cloudflare. This is not
// a production server or replacement for Wrangler's D1 integration testing.
import { createServer } from 'node:http';
import { Readable } from 'node:stream';
import worker from './src/worker.mjs';

const port = Number(process.env.ALONG_API_PORT || 8787);
if (!Number.isInteger(port) || port < 1024 || port > 65535) throw new Error('Invalid ALONG_API_PORT');
const env = { APP_ENV: 'local', DEMO_MODE: 'true', WAITLIST_ENABLED: 'false', WEB_ORIGIN: 'http://localhost:5173' };
const server = createServer(async (incoming, outgoing) => {
  try {
    const url = new URL(incoming.url, `http://127.0.0.1:${port}`);
    const body = ['GET', 'HEAD'].includes(incoming.method) ? undefined : Readable.toWeb(incoming);
    const request = new Request(url, { method: incoming.method, headers: incoming.headers, body, ...(body ? { duplex: 'half' } : {}) });
    const result = await worker.fetch(request, env);
    outgoing.writeHead(result.status, Object.fromEntries(result.headers));
    if (result.body) Readable.fromWeb(result.body).pipe(outgoing);
    else outgoing.end();
  } catch {
    outgoing.writeHead(400, { 'content-type': 'application/json' });
    outgoing.end('{"error":"bad_request"}');
  }
});
server.listen(port, '127.0.0.1', () => {
  console.log(`Along LOCAL DEMO at http://127.0.0.1:${port}; sample data only, no accounts, analytics or billing.`);
});
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, () => server.close());
