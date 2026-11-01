import { APIError, checkOrigin, isLocalDemo, json, readJSON, requireLocalDemo } from './http.mjs';
import { anonymousSession } from './auth.mjs';
import { entitlements, billingWebhook } from './billing.mjs';
import { journey, saveCheckIn, saveMilestone, reflect } from './journal.mjs';
import { validateEvent } from './events.mjs';
import { joinWaitlist, pruneWaitlist } from './waitlist.mjs';

const routes = new Map([
  ['/health', 'GET'], ['/api/auth/sign-in/anonymous', 'POST'],
  ['/me/entitlements', 'GET'], ['/journey', 'GET'], ['/check-ins', 'POST'],
  ['/milestones', 'POST'], ['/weekly-reflection', 'POST'], ['/events', 'POST'],
  ['/waitlist', 'POST'], ['/webhooks/superwall', 'POST'], ['/webhooks/stripe', 'POST'],
]);

async function route(request, env) {
  const { pathname } = new URL(request.url);
  const method = routes.get(pathname);
  if (!method) throw new APIError(404, 'not_found', 'Route not found.');
  if (request.method !== method) return json({ error: 'method_not_allowed', message: 'Method not allowed.' }, 405, { allow: method });
  switch (pathname) {
    case '/health': {
      const demo = isLocalDemo(request, env);
      return json({ service: 'along-api', version: 1, mode: demo ? 'demo' : 'unconfigured',
        status: demo ? 'ok' : 'setup_required', liveReady: false,
        notice: demo ? 'Local sample data; no live AI, billing or account.' : 'Live app services are disabled.' }, demo ? 200 : 503);
    }
    case '/api/auth/sign-in/anonymous': return anonymousSession(request, env);
    case '/me/entitlements': return entitlements(request, env);
    case '/journey': return journey(request, env);
    case '/check-ins': return saveCheckIn(request, env);
    case '/milestones': return saveMilestone(request, env);
    case '/weekly-reflection': return reflect(request, env);
    case '/events': {
      requireLocalDemo(request, env);
      validateEvent(await readJSON(request));
      return json({ mode: 'demo', accepted: true, stored: false, notice: 'Validated locally; no analytics were sent or stored.' }, 202);
    }
    case '/waitlist': return joinWaitlist(request, env);
    case '/webhooks/superwall': return billingWebhook('superwall', request, env);
    case '/webhooks/stripe': return billingWebhook('stripe', request, env);
  }
}

export default {
  async fetch(request, env = {}) {
    let cors = {};
    let response;
    try {
      cors = checkOrigin(request, env);
      if (request.method === 'OPTIONS') {
        if (!routes.has(new URL(request.url).pathname)) throw new APIError(404, 'not_found', 'Route not found.');
        response = new Response(null, { status: 204 });
      } else {
        response = await route(request, env);
      }
    } catch (error) {
      // Do not echo thrown provider/DB messages, input, tokens or stack traces.
      response = error instanceof APIError
        ? json({ error: error.code, message: error.message }, error.status)
        : json({ error: 'service_unavailable', message: 'Please try again. The service is unavailable.' }, 503);
    }
    const headers = new Headers(response.headers);
    for (const [key, value] of Object.entries(cors)) headers.set(key, value);
    headers.set('x-content-type-options', 'nosniff');
    headers.set('cache-control', 'no-store');
    return new Response(response.body, { status: response.status, headers });
  },
  async scheduled(_controller, env) {
    await pruneWaitlist(env);
  },
};
