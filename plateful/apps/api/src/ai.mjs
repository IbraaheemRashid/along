import { APIError } from './http.mjs';

export async function generateLiveReflection(_entries, _env) {
  // Deliberately not wired into the router. Future staging integration uses
  // OpenRouter/DeepSeek through AI Gateway, following authentication, consent,
  // deterministic redaction, a scoped prompt, output validation, quotas and a
  // privacy review. Keys alone must never activate transmission of journal data.
  throw new APIError(503, 'ai_not_configured', 'Live reflections are not configured.');
}
