import { APIError, exactKeys } from './http.mjs';

const eventNames = new Set(['app_opened', 'onboarding_completed', 'paywall_viewed', 'core_action', 'share_tapped', 'error']);
const metadata = {
  platform: new Set(['ios', 'web']),
  feature: new Set(['routine_checkin', 'milestones', 'weekly_reflection', 'journal']),
  surface: new Set(['onboarding', 'home', 'checkin', 'journey', 'milestone', 'reflection', 'settings', 'waitlist']),
  result: new Set(['success', 'empty', 'cancelled', 'failure']),
};

export function validateEvent(input, now = new Date()) {
  exactKeys(input, ['name', 'properties']);
  if (!eventNames.has(input.name)) {
    throw new APIError(400, 'invalid_event', 'This client event is not supported.');
  }
  const properties = input.properties ?? {};
  exactKeys(properties, Object.keys(metadata));
  for (const [key, value] of Object.entries(properties)) {
    if (!metadata[key].has(value)) throw new APIError(400, 'invalid_event_properties', 'Only predefined event metadata is accepted.');
  }
  return { id: crypto.randomUUID(), timestamp: now.toISOString(), name: input.name, ...properties };
}

// Staging adapter seam. Nothing calls this from the demo route. No prompts,
// ingredient strings, appetite, user identity, emails, IP addresses or health data.
export async function sendToTinybird(events, env, fetcher = fetch) {
  if (env.APP_ENV !== 'staging' || env.TINYBIRD_ENABLED !== 'true' || !env.TINYBIRD_APPEND_TOKEN) {
    throw new APIError(503, 'analytics_not_configured', 'Analytics ingestion is not configured.');
  }
  let base;
  try { base = new URL(env.TINYBIRD_API_URL); } catch { throw new APIError(503, 'analytics_not_configured', 'Configure a Tinybird regional endpoint.'); }
  if (base.protocol !== 'https:' || !/^api(?:\.[a-z0-9-]+){0,2}\.tinybird\.co$/.test(base.hostname)
      || base.username || base.password || base.pathname !== '/' || base.search || base.hash
      || !/^[a-zA-Z0-9_]{1,64}$/.test(env.TINYBIRD_DATASOURCE || '') || !Array.isArray(events) || events.length > 100) {
    throw new APIError(503, 'analytics_not_configured', 'Configure a Tinybird regional endpoint and data source.');
  }
  const safeEvents = events.map(event => {
    exactKeys(event, ['id', 'timestamp', 'name', ...Object.keys(metadata)]);
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(event.id || '')
        || typeof event.timestamp !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(event.timestamp)
        || !Number.isFinite(Date.parse(event.timestamp))) {
      throw new APIError(400, 'invalid_event', 'Invalid queued event.');
    }
    const properties = Object.fromEntries(Object.keys(metadata).filter(k => k in event).map(k => [k, event[k]]));
    const valid = validateEvent({ name: event.name, properties });
    return { ...valid, id: event.id, timestamp: event.timestamp };
  });
  const url = new URL('/v0/events', base);
  url.searchParams.set('name', env.TINYBIRD_DATASOURCE);
  url.searchParams.set('wait', 'true');
  const result = await fetcher(url, {
    method: 'POST', headers: { 'authorization': `Bearer ${env.TINYBIRD_APPEND_TOKEN}`, 'content-type': 'application/x-ndjson' },
    body: safeEvents.map(event => JSON.stringify(event)).join('\n') + '\n',
    signal: AbortSignal.timeout(5000),
  });
  if (!result.ok) throw new APIError(502, 'analytics_unavailable', 'Analytics ingestion is unavailable.');
}
