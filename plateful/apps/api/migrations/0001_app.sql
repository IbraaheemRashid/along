-- Application tables only. Generate Better Auth tables with its official CLI
-- after pinning/configuring Better Auth; do not hand-roll session tables.
CREATE TABLE IF NOT EXISTS entitlements (
  user_id TEXT NOT NULL,
  entitlement TEXT NOT NULL,
  source TEXT NOT NULL CHECK(source IN ('superwall', 'stripe')),
  product_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('active', 'trialing', 'expired', 'revoked')),
  current_period_end INTEGER,
  original_transaction_id TEXT,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(user_id, entitlement)
);

CREATE TABLE IF NOT EXISTS billing_events (
  source TEXT NOT NULL CHECK(source IN ('superwall', 'stripe')),
  event_id TEXT NOT NULL,
  processed_at INTEGER NOT NULL,
  PRIMARY KEY(source, event_id)
);

CREATE TABLE IF NOT EXISTS usage_ledger (
  id TEXT PRIMARY KEY NOT NULL,
  user_id TEXT NOT NULL,
  feature TEXT NOT NULL,
  units INTEGER NOT NULL CHECK(units >= 0),
  cost_micros INTEGER NOT NULL CHECK(cost_micros >= 0),
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS usage_by_user_time ON usage_ledger(user_id, created_at);

-- Reserved for atomic quota admission, not an eventually consistent KV counter.
CREATE TABLE IF NOT EXISTS daily_usage (
  user_id TEXT NOT NULL,
  feature TEXT NOT NULL,
  day TEXT NOT NULL,
  units INTEGER NOT NULL CHECK(units >= 0),
  PRIMARY KEY(user_id, feature, day)
);

CREATE TABLE IF NOT EXISTS waitlist (
  id TEXT PRIMARY KEY NOT NULL,
  email TEXT NOT NULL UNIQUE,
  source TEXT NOT NULL,
  variant TEXT NOT NULL,
  consent_version TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL CHECK(expires_at > created_at)
);
CREATE INDEX IF NOT EXISTS waitlist_by_expiry ON waitlist(expires_at);
