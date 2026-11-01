import test from 'node:test';
import assert from 'node:assert/strict';
import { call, demoEnv, localDB, request } from './helpers.mjs';
import { validateEvent, sendToTinybird } from '../../apps/api/src/events.mjs';
import { joinWaitlist, pruneWaitlist } from '../../apps/api/src/waitlist.mjs';

const waitlistInput = { email: 'person@example.com', consent: true, source: 'web-validation', variant: 'progress-demo-v1', turnstileToken: 'test-token' };
function waitlistEnv(DB) {
  return { APP_ENV: 'staging', WAITLIST_ENABLED: 'true', WAITLIST_COLLECTION_APPROVED: 'true', WEB_ORIGIN: 'https://along.example.com', WAITLIST_PRIVACY_URL: 'https://along.example.com/privacy', WAITLIST_CONSENT_VERSION: 'progress-preview-v1', TURNSTILE_SECRET: 'test-only-secret', DB };
}
const verified = async () => Response.json({ success: true, hostname: 'along.example.com', action: 'waitlist' });
const waitlistRequest = body => request('/waitlist', body, { base: 'https://api.example.com', headers: { origin: 'https://along.example.com' } });

test('client events accept only predefined low-detail metadata and never claim ingestion in demo', async () => {
  const result = await call('/events', { name: 'core_action', properties: { feature: 'routine_checkin', platform: 'ios', result: 'success' } });
  assert.equal(result.status, 202);
  assert.equal(result.body.stored, false);
  const sensitive = ['note', 'mood', 'appetite', 'email', 'dose', 'weight', 'ingredients', 'user_id', 'prompt'];
  for (const key of sensitive) {
    const denied = await call('/events', { name: 'core_action', properties: { [key]: 'private' } });
    assert.equal(denied.status, 400, key);
  }
  assert.equal((await call('/events', { name: 'core_action', properties: { feature: 'private health details' } })).status, 400);
  assert.equal((await call('/events', { name: 'subscription_started' })).status, 400);
  assert.equal((await call('/events', { name: 'app_opened', email: 'private@example.com' })).status, 400);
});

test('Tinybird adapter is disabled by default and emits only validated metadata to its regional host', async () => {
  const event = validateEvent({ name: 'core_action', properties: { feature: 'journal', platform: 'ios' } }, new Date('2026-11-01T12:00:00Z'));
  await assert.rejects(sendToTinybird([event], demoEnv), /not configured/);
  const env = { APP_ENV: 'staging', TINYBIRD_ENABLED: 'true', TINYBIRD_APPEND_TOKEN: 'test-token', TINYBIRD_API_URL: 'https://api.tinybird.co', TINYBIRD_DATASOURCE: 'along_events' };
  let calls = 0;
  await sendToTinybird([event], env, async (url, init) => {
    calls++;
    assert.equal(url.origin, 'https://api.tinybird.co');
    assert.equal(url.pathname, '/v0/events');
    assert.equal(url.searchParams.get('wait'), 'true');
    assert.equal(init.headers.authorization, 'Bearer test-token');
    assert.deepEqual(JSON.parse(init.body.trim()), event);
    return new Response('', { status: 200 });
  });
  assert.equal(calls, 1);
  await assert.rejects(sendToTinybird([{ ...event, note: 'private' }], env), /unsupported fields/);
  await assert.rejects(sendToTinybird([event], { ...env, TINYBIRD_API_URL: 'https://evil.example.com' }), /regional endpoint/);
});

test('waitlist is disabled without setup even when valid consent is provided', async () => {
  const result = await call('/waitlist', waitlistInput);
  assert.equal(result.status, 503);
  assert.equal(result.body.error, 'waitlist_disabled');
  const db = localDB();
  try {
    for (const patch of [{ APP_ENV: 'production' }, { WAITLIST_COLLECTION_APPROVED: 'false' }, { TURNSTILE_SECRET: '' }, { WAITLIST_PRIVACY_URL: '' }]) {
      await assert.rejects(joinWaitlist(waitlistRequest(waitlistInput), { ...waitlistEnv(db), ...patch }, verified), /not configured/);
    }
    assert.equal(db.calls.length, 0);
  } finally { db.close(); }
});

test('waitlist requires explicit consent, challenge action and matching hostname before any writes', async t => {
  const db = localDB(); t.after(() => db.close());
  const env = waitlistEnv(db);
  for (const patch of [{ consent: false }, { consent: 'yes' }, { email: 'invalid' }, { turnstileToken: '' }, { variant: 'ingredients-demo-v1' }, { note: 'private' }]) {
    await assert.rejects(joinWaitlist(waitlistRequest({ ...waitlistInput, ...patch }), env, verified));
  }
  for (const result of [{ success: false }, { success: true, hostname: 'evil.test', action: 'waitlist' }, { success: true, hostname: 'along.example.com', action: 'login' }]) {
    await assert.rejects(joinWaitlist(waitlistRequest(waitlistInput), env, async () => Response.json(result)), /fresh verification/);
  }
  assert.equal(db.calls.length, 0);
});

test('waitlist inserts bound email and consent once, does not reveal duplicates, and prunes expired records', async t => {
  const db = localDB(); t.after(() => db.close());
  const env = waitlistEnv(db);
  const first = await joinWaitlist(waitlistRequest({ ...waitlistInput, email: ' Person@Example.com ' }), env, verified);
  const second = await joinWaitlist(waitlistRequest(waitlistInput), env, verified);
  assert.equal(first.status, 202);
  assert.deepEqual(await first.json(), await second.json());
  assert.equal(db.sqlite.prepare('SELECT count(*) AS count FROM waitlist').get().count, 1);
  const row = db.sqlite.prepare('SELECT * FROM waitlist').get();
  assert.equal(row.email, 'person@example.com');
  assert.equal(row.consent_version, 'progress-preview-v1');
  assert.equal(row.expires_at - row.created_at, 90 * 86400);
  assert(db.calls.every(c => !c.sql.includes('person@example.com')));
  db.sqlite.prepare('UPDATE waitlist SET created_at = 1, expires_at = 2').run();
  await pruneWaitlist(env);
  assert.equal(db.sqlite.prepare('SELECT count(*) AS count FROM waitlist').get().count, 0);
});

test('waitlist returns no success when challenge service or D1 fails', async t => {
  const db = localDB(); t.after(() => db.close());
  const env = waitlistEnv(db);
  await assert.rejects(joinWaitlist(waitlistRequest(waitlistInput), env, async () => { throw new Error('private provider error'); }), /Nothing has been saved/);
  const brokenDB = { prepare() { return { bind() { return { async run() { return { success: false }; } }; } }; } };
  await assert.rejects(joinWaitlist(waitlistRequest(waitlistInput), { ...env, DB: brokenDB }, verified), /write failed/);
});
