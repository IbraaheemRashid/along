import { APIError, exactKeys, json, readJSON } from './http.mjs';

const disabled = () => new APIError(503, 'waitlist_disabled', 'This is a preview. Email collection is not configured; nothing has been saved.');

export function waitlistConfigured(env) {
  if (env.APP_ENV !== 'staging' || env.WAITLIST_ENABLED !== 'true'
      || env.WAITLIST_COLLECTION_APPROVED !== 'true' || !env.DB
      || !env.TURNSTILE_SECRET || !env.WAITLIST_CONSENT_VERSION) return false;
  try {
    const origin = new URL(env.WEB_ORIGIN);
    const privacy = new URL(env.WAITLIST_PRIVACY_URL);
    return origin.protocol === 'https:' && origin.origin === env.WEB_ORIGIN
      && privacy.protocol === 'https:' && privacy.origin === origin.origin
      && !origin.hostname.endsWith('.invalid') && !origin.username && !origin.password;
  } catch { return false; }
}

export function validateWaitlist(input) {
  exactKeys(input, ['email', 'consent', 'source', 'variant', 'turnstileToken']);
  const email = typeof input.email === 'string' ? input.email.trim().toLowerCase() : '';
  if (input.consent !== true || email.length > 254
      || !/^[^\s@\u0000-\u001f]+@[^\s@\u0000-\u001f]+\.[^\s@\u0000-\u001f]+$/.test(email)
      || typeof input.turnstileToken !== 'string' || input.turnstileToken.length < 1 || input.turnstileToken.length > 2048
      || (input.source !== undefined && !['web-validation', 'ios-validation'].includes(input.source))
      || (input.variant !== undefined && input.variant !== 'progress-demo-v1')) {
    throw new APIError(400, 'invalid_waitlist', 'A valid email, explicit consent and verification are required.');
  }
  return { email, consent: true, source: input.source || 'web-validation', variant: input.variant || 'progress-demo-v1', turnstileToken: input.turnstileToken };
}

export async function joinWaitlist(request, env, fetcher = fetch) {
  if (!waitlistConfigured(env)) throw disabled();
  // Only the configured website can collect leads. A public anonymous native
  // route would need a separately reviewed abuse-control mechanism.
  if (request.headers.get('origin') !== env.WEB_ORIGIN) throw new APIError(403, 'origin_not_allowed', 'Use the configured waitlist website.');
  const input = validateWaitlist(await readJSON(request));
  let verification;
  try {
    const response = await fetcher('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ secret: env.TURNSTILE_SECRET, response: input.turnstileToken }),
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error('Verification unavailable');
    verification = await response.json();
  } catch { throw new APIError(503, 'verification_unavailable', 'Please retry verification. Nothing has been saved.'); }
  if (verification.success !== true || verification.hostname !== new URL(env.WEB_ORIGIN).hostname || verification.action !== 'waitlist') {
    throw new APIError(400, 'verification_failed', 'Please complete a fresh verification challenge.');
  }
  const now = Math.floor(Date.now() / 1000);
  // No interpolated values and no email enumeration in the response. A repeated
  // signup does not silently extend the original retention/consent period.
  const written = await env.DB.prepare(`INSERT INTO waitlist (id, email, source, variant, consent_version, created_at, expires_at)
    VALUES (?, ?, ?, ?, ?, ?, ?) ON CONFLICT(email) DO NOTHING`)
    .bind(crypto.randomUUID(), input.email, input.source, input.variant, env.WAITLIST_CONSENT_VERSION, now, now + 90 * 86400).run();
  if (written.success !== true) throw new Error('Waitlist write failed');
  return json({ mode: 'staging', accepted: true, message: 'Your interest has been recorded. No payment was taken.' }, 202);
}

export async function pruneWaitlist(env) {
  if (!waitlistConfigured(env)) return;
  await env.DB.prepare('DELETE FROM waitlist WHERE expires_at <= ?').bind(Math.floor(Date.now() / 1000)).run();
}
