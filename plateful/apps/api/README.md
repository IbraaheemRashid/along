# Along API preview

Plain Cloudflare Worker routing, parameterized D1 SQL, and a dependency-free local harness for Along's progress journal. The repository directory retains its earlier working name; the product is Along. The pantry concept and meal endpoint are removed.

## Run locally

From the `plateful` directory, with Node 24 (or Node 22.18+) on PATH:

```sh
node apps/api/dev.mjs
node --test tests/api/*.test.mjs
```

The server listens only on `http://127.0.0.1:8787`. Set `ALONG_API_PORT` to change the port. The same `src/worker.mjs` fetch handler runs in this harness and Cloudflare. The native app defaults to its own device storage; this backend is an optional integration preview.

```sh
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/journey
```

No package installation, account, API key or payment is needed. The Node harness intentionally does not load secrets or connect to D1. Its writes return `stored:false`; clients must retain their own entries. Sample journey entries are clearly identified. There is no live AI, account session, analytics transmission, subscription or automatic deployment.

## Routes

| Route | Local preview behavior |
| --- | --- |
| `GET /health` | Mode and readiness; `liveReady:false` |
| `POST /api/auth/sign-in/anonymous` | Explicit fake local marker; creates no real session |
| `GET /journey` | `{mode,storage,checkIns,milestones,notice}` |
| `POST /check-ins` | Validates one entry; `{mode,stored,checkIn,notice}` |
| `POST /milestones` | Validates one milestone; `{mode,stored,milestone,notice}` |
| `POST /weekly-reflection` | Deterministic demo recap, no provider call |
| `GET /me/entitlements` | No paid entitlements; `hasPaidAccess:false` |
| `POST /events` | Strict metadata allowlist; `stored:false` |
| `POST /waitlist` | Disabled by default; returns 503, not false signup success |
| `POST /webhooks/stripe`, `/webhooks/superwall` | Disabled; no unverified entitlement writes |

Journal routes require all three: `APP_ENV=local`, `DEMO_MODE=true`, and a loopback request hostname. A bearer marker cannot bypass this gate. Staging and production app routes fail closed even if secrets exist. CORS allows only the exact configured `WEB_ORIGIN`; the default is `http://localhost:5173`.

Daily entry fields are `id` (UUID), `day` (`YYYY-MM-DD`), `mood` (`bright|steady|tough`), `appetite` (`low|comfortable|hungry`), `routines` (unique values from `nutrition|movement|reflection`) and `note` (string, at most 500 UTF-16 code units). Empty notes and routines are valid. No medication, dosage, weight or additional fields are accepted.

Milestone fields are `id` (UUID), `date` (`YYYY-MM-DD`), `title` (nonempty, at most 80 code units), `note` (at most 300), and `kind` (`everyday|strength|confidence|other`). Dates are calendar days, not UTC instants.

Reflection input is `{weekStart:"YYYY-MM-DD",checkIns:[...]}` with up to seven distinct days/IDs within that week. Output is `{mode:"demo",title,body,checkedInDays,routineCount}`. It counts supplied entries and routine selections only. It neither quotes private notes nor infers health, treatment outcomes or failure from blank logs. It does not provide medication advice.

## Local D1 and migrations

`migrations/0001_app.sql` contains reserved entitlement, verified-billing-event, usage and waitlist tables. Billing/usage tables are presently unused; their presence does not imply connected payments. `0002_journal.sql` adds check-ins and milestones. SQL is executed with bound parameters.

To test D1 with Wrangler when available, add a **local** `DB` D1 binding to the local configuration, set `LOCAL_JOURNAL_STORAGE=true`, apply both migrations using Wrangler's `--local` option, then run `wrangler dev --local`. Keep remote environments separate and leave their journal routes disabled. No real database ID has been supplied and no remote migration was run.

With that explicit local flag and binding, check-ins upsert one record per day and preserve the existing ID. Milestones upsert by ID. `GET /journey` returns local records only, never mixes sample records into a stored journal, and limits each list to the latest 366 records. Without both the flag and binding, writes remain previews. Local development uses a fixed local user; it is deliberately unavailable on public hosts. Live sync still needs real ownership, export/deletion, retention, pagination and access-control implementation.

## Integration activation boundaries

- **Better Auth:** `src/auth.mjs` is a disabled seam. Install/pin the official package, configure D1 plus anonymous, bearer and Apple sign-in, generate its schema with its official CLI, and enforce `auth.api.getSession` before any live journal route. Do not use the local marker as a real session. [Anonymous plugin](https://better-auth.com/docs/plugins/anonymous), [bearer plugin](https://better-auth.com/docs/plugins/bearer).
- **AI Gateway / OpenRouter / DeepSeek:** `src/ai.mjs` always rejects live calls. A future implementation requires reviewed consent/data handling, scoped prompts, output validation, quotas, model evaluation and timeouts. No journal content currently leaves this backend. Provider credentials alone cannot activate it. AI Gateway payload logging and Logpush require separate configuration. [Provider routing](https://developers.cloudflare.com/ai-gateway/usage/providers/openrouter/), [logging](https://developers.cloudflare.com/ai-gateway/observability/logging/).
- **Superwall / Stripe:** webhook seams reject every request until official signature verification, replay protection, product mapping and atomic entitlement updates are implemented. Client events cannot grant paid access. No trial or purchase is active.
- **Tinybird:** the staged outbound NDJSON adapter is implemented and unit-tested with mocked fetch; no route currently invokes it. Before connecting it, configure a scoped append token, regional endpoint, data source and reliable queue delivery. Only predefined event names and enum metadata are accepted; no note, mood, appetite, email, identity, weight, dosage or free text. [Events API](https://www.tinybird.co/docs/forward/ingest-data/events-api), [regional endpoints](https://www.tinybird.co/docs/api-reference).
- **Waitlist:** only an explicitly approved staging configuration can collect: `WAITLIST_ENABLED=true`, `WAITLIST_COLLECTION_APPROVED=true`, a real HTTPS `WEB_ORIGIN` and same-origin `WAITLIST_PRIVACY_URL`, a consent version, D1 binding and Turnstile secret. Payload is `{email,consent:true,source:"web-validation",variant:"progress-demo-v1",turnstileToken}`. Server-side verification checks the exact website hostname and `action:"waitlist"` before writing. Duplicate signup responses are identical. Records expire after 90 days; configure the daily scheduled handler at activation and provide a deletion/contact process. Preview configuration saves nothing. [Turnstile server verification](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/).

Production remains disabled; deployment is outside this prototype. Secrets belong in server bindings, never the native or web bundles. `.dev.vars.example` documents empty settings; populated `.dev.vars` files are ignored.

## Verification performed

The Node suite covers schema validation, sensitive-data rejection, fail-closed environment gates, CORS, body limits, sample/persisted semantics, deterministic reflection, webhook rejection, waitlist consent/challenge handling and bound SQL. A small D1-compatible test adapter executes the actual migrations and queries against Node's real in-memory SQLite database, including update/idempotency checks.

25 tests pass. No external provider integration was exercised. Wrangler/Cloudflare runtime checks and live D1 have not been run. Direct Worker fetch-handler tests passed. A parent-run local HTTP smoke test also passed for health, an honest `stored:false` check-in response and the disabled waitlist (503).
