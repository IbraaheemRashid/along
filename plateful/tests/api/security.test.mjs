import test from 'node:test';
import assert from 'node:assert/strict';
import worker from '../../apps/api/src/worker.mjs';
import { call, demoEnv, entry, milestone } from './helpers.mjs';
import { requireLiveSession } from '../../apps/api/src/auth.mjs';
import { generateLiveReflection } from '../../apps/api/src/ai.mjs';

test('live, staging, unset and remotely hosted demo configurations cannot access journal routes', async () => {
  const endpoints = [['/journey', undefined], ['/check-ins', entry], ['/milestones', milestone], ['/weekly-reflection', { weekStart: '2026-11-01', checkIns: [] }], ['/api/auth/sign-in/anonymous', {}], ['/me/entitlements', undefined], ['/events', { name: 'app_opened' }]];
  for (const env of [{}, { APP_ENV: 'production', DEMO_MODE: 'true' }, { APP_ENV: 'staging', DEMO_MODE: 'true' }, { APP_ENV: 'local', DEMO_MODE: 'false' }]) {
    for (const [path, body] of endpoints) assert.equal((await call(path, body, env)).status, 503, `${env.APP_ENV} ${path}`);
  }
  for (const [path, body] of endpoints) assert.equal((await call(path, body, demoEnv, { base: 'https://along.example.com' })).status, 503);
});

test('health identifies demo and setup-required modes without revealing secrets', async () => {
  const demo = await call('/health');
  assert.equal(demo.body.service, 'along-api');
  assert.equal(demo.body.mode, 'demo');
  assert.equal(demo.body.liveReady, false);
  const live = await call('/health', undefined, { APP_ENV: 'production', OPENROUTER_API_KEY: 'private-secret' });
  assert.equal(live.status, 503);
  assert.equal(live.body.mode, 'unconfigured');
  assert(!JSON.stringify(live.body).includes('private-secret'));
});

test('demo identity and entitlement cannot be mistaken for paid access or real sessions', async () => {
  const auth = await call('/api/auth/sign-in/anonymous', {});
  assert.equal(auth.body.mode, 'demo');
  assert.equal(auth.headers.get('set-auth-token'), 'along-local-demo');
  const paid = await call('/me/entitlements', undefined, demoEnv, { headers: { authorization: 'Bearer pretend-paid', 'x-user-id': 'admin' } });
  assert.equal(paid.body.hasPaidAccess, false);
  assert.deepEqual(paid.body.entitlements, []);
  await assert.rejects(requireLiveSession(new Request('https://example.com'), { BETTER_AUTH_SECRET: 'fake' }), /not configured/);
  await assert.rejects(generateLiveReflection([], { OPENROUTER_API_KEY: 'fake' }), /not configured/);
});

test('unverified webhooks cannot mutate a DB even when keys are present', async () => {
  let touched = false;
  const env = { ...demoEnv, STRIPE_WEBHOOK_SECRET: 'fake', SUPERWALL_WEBHOOK_SECRET: 'fake', DB: { prepare() { touched = true; } } };
  for (const provider of ['stripe', 'superwall']) {
    const result = await call(`/webhooks/${provider}`, { type: 'subscription.started', user: 'local-demo' }, env);
    assert.equal(result.status, 503);
    assert.equal(result.body.error, 'billing_not_configured');
  }
  assert.equal(touched, false);
});

test('removed pantry route is unavailable in every mode', async () => {
  for (const env of [demoEnv, { APP_ENV: 'production' }]) assert.equal((await call('/meals/suggest', {}, env)).status, 404);
});

test('CORS permits only the exact configured origin, including errors', async () => {
  for (const origin of ['http://localhost:5173.evil.test', 'http://evil.test', 'null']) {
    const denied = await call('/journey', undefined, demoEnv, { headers: { origin } });
    assert.equal(denied.status, 403);
    assert.equal(denied.headers.get('access-control-allow-origin'), null);
  }
  const permitted = await call('/check-ins', {}, demoEnv, { headers: { origin: demoEnv.WEB_ORIGIN } });
  assert.equal(permitted.status, 400);
  assert.equal(permitted.headers.get('access-control-allow-origin'), demoEnv.WEB_ORIGIN);
  const preflight = await worker.fetch(new Request('http://localhost/journey', { method: 'OPTIONS', headers: { origin: demoEnv.WEB_ORIGIN } }), demoEnv);
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), demoEnv.WEB_ORIGIN);
});

test('invalid JSON, non-object JSON, wrong content types and excess bodies are rejected', async () => {
  for (const body of ['{', 'null', '[]', '"hello"']) {
    const response = await worker.fetch(new Request('http://localhost/check-ins', { method: 'POST', headers: { 'content-type': 'application/json' }, body }), demoEnv);
    assert.equal(response.status, 400);
  }
  const wrongType = await call('/check-ins', entry, demoEnv, { headers: { 'content-type': 'text/plain' } });
  assert.equal(wrongType.status, 415);
  const oversized = await call('/check-ins', { ...entry, note: 'x'.repeat(10000) });
  assert.equal(oversized.status, 413);
  assert.equal((await call('/journey', {})).status, 405);
});

test('all application responses prevent caching sensitive journal data', async () => {
  for (const path of ['/journey', '/health', '/not-found']) {
    const response = await call(path);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(response.headers.get('x-content-type-options'), 'nosniff');
  }
});
