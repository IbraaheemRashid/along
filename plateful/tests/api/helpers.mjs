import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker from '../../apps/api/src/worker.mjs';

export const demoEnv = { APP_ENV: 'local', DEMO_MODE: 'true', WEB_ORIGIN: 'http://localhost:5173' };
export const entry = {
  id: '11111111-1111-4111-8111-111111111111', day: '2026-11-01', mood: 'steady',
  appetite: 'comfortable', routines: ['reflection'], note: 'A moment for myself.',
};
export const milestone = {
  id: '22222222-2222-4222-8222-222222222222', date: '2026-11-01',
  title: 'A small moment', note: 'Worth remembering.', kind: 'everyday',
};

export function request(path, body, extra = {}) {
  const { base = 'http://127.0.0.1:8787', headers, ...options } = extra;
  return new Request(base + path, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { ...(body === undefined ? {} : { 'content-type': 'application/json' }), ...headers },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    ...options,
  });
}

export async function call(path, body, env = demoEnv, extra = {}) {
  const response = await worker.fetch(request(path, body, extra), env);
  return { status: response.status, headers: response.headers, body: await response.json() };
}

// Real SQLite executes the exact migration SQL and parameter bindings. This is
// a small D1 binding adapter, not a mock SQL parser. Worker-runtime/D1 integration
// remains a separate Wrangler check once Wrangler/accounts are configured.
export function localDB() {
  const sqlite = new DatabaseSync(':memory:');
  for (const name of ['0001_app.sql', '0002_journal.sql']) {
    sqlite.exec(readFileSync(new URL(`../../apps/api/migrations/${name}`, import.meta.url), 'utf8'));
  }
  const calls = [];
  return {
    sqlite, calls,
    close() { sqlite.close(); },
    prepare(sql) {
      return { bind(...values) {
        calls.push({ sql, values });
        const statement = sqlite.prepare(sql);
        return {
          async run() { const result = statement.run(...values); return { success: true, meta: { changes: Number(result.changes) } }; },
          async first() { return statement.get(...values) ?? null; },
          async all() { return { success: true, results: statement.all(...values) }; },
        };
      } };
    },
  };
}
