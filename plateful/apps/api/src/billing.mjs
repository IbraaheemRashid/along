import { APIError, json, requireLocalDemo } from './http.mjs';

export function entitlements(request, env) {
  requireLocalDemo(request, env);
  return json({
    mode: 'demo', userID: 'local-demo',
    entitlements: [], canUseDemo: true, hasPaidAccess: false,
    notice: 'The local journal preview is available. No trial, subscription or purchase is active.',
  });
}

export function billingWebhook(_provider, _request, _env) {
  // Both Superwall and Stripe remain fail-closed. Before enabling: use the
  // provider's official signature verifier against the exact raw body, enforce
  // timestamp freshness, map product IDs server-side and atomically dedupe event
  // IDs with entitlement updates in D1. Client paywall events cannot grant access.
  throw new APIError(503, 'billing_not_configured', 'Purchase verification is not configured.');
}
