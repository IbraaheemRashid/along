import {cleanEmail} from './model.mjs';

export function waitlistConfiguration(env = {}) {
  const api = env.VITE_API_BASE || '';
  const privacy = env.VITE_PRIVACY_URL || '';
  const key = env.VITE_TURNSTILE_SITE_KEY || '';
  const allowed = /^https:\/\//.test(api) && /^https:\/\//.test(privacy);
  return {enabled: env.VITE_WAITLIST_ENABLED === 'true' && allowed && !!key, api: api.replace(/\/$/,''), privacy, key};
}

export async function joinWaitlist({config, email, consent, token, fetcher = fetch}) {
  if (!config.enabled) throw new Error('This is a preview. Signups are not open and no email has been saved.');
  const normalised = cleanEmail(email);
  if (!normalised) throw new Error('Enter a valid email address.');
  if (!consent) throw new Error('Please agree to receive the launch email.');
  if (!token) throw new Error('Please complete the verification before joining.');
  const response = await fetcher(`${config.api}/waitlist`, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({email:normalised, consent:true, source:'web-validation', variant:'progress-demo-v1', turnstileToken:token}),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.accepted !== true) throw new Error(data.message || 'We could not save your interest. Please try again later.');
  return data.message || 'Your interest has been recorded. No payment was taken.';
}
