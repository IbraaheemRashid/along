-- Sensitive journal data stays local in this prototype. Live user ownership,
-- deletion/export and access-control rules must be implemented before sync.
CREATE TABLE IF NOT EXISTS check_ins (
  id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  day TEXT NOT NULL,
  mood TEXT NOT NULL CHECK(mood IN ('bright', 'steady', 'tough')),
  appetite TEXT NOT NULL CHECK(appetite IN ('low', 'comfortable', 'hungry')),
  routines_json TEXT NOT NULL CHECK(json_valid(routines_json)),
  note TEXT NOT NULL CHECK(length(note) <= 500),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(id, user_id),
  UNIQUE(user_id, day)
);
CREATE INDEX IF NOT EXISTS check_ins_by_user_day ON check_ins(user_id, day DESC);

CREATE TABLE IF NOT EXISTS milestones (
  id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  date TEXT NOT NULL,
  title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 80),
  note TEXT NOT NULL CHECK(length(note) <= 300),
  kind TEXT NOT NULL CHECK(kind IN ('everyday', 'strength', 'confidence', 'other')),
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(id, user_id)
);
CREATE INDEX IF NOT EXISTS milestones_by_user_date ON milestones(user_id, date DESC);
