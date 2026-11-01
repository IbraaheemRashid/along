import { APIError, exactKeys, json, readJSON, requireLocalDemo } from './http.mjs';

const moods = new Set(['bright', 'steady', 'tough']);
const appetites = new Set(['low', 'comfortable', 'hungry']);
const routines = new Set(['nutrition', 'movement', 'reflection']);
const milestoneKinds = new Set(['everyday', 'strength', 'confidence', 'other']);
const demoUser = 'local-demo';

function validID(value) {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

export function validDay(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T12:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function validText(value, max, required = false) {
  return typeof value === 'string' && value.length <= max
    && (!required || value.trim().length > 0) && !/[\u0000-\u0008\u000b-\u001f\u007f]/.test(value);
}

export function validateCheckIn(input) {
  exactKeys(input, ['id', 'day', 'mood', 'appetite', 'routines', 'note']);
  if (!validID(input.id) || !validDay(input.day) || !moods.has(input.mood)
      || !appetites.has(input.appetite) || !Array.isArray(input.routines)
      || input.routines.length > 3 || input.routines.some(routine => !routines.has(routine))
      || new Set(input.routines).size !== input.routines.length || !validText(input.note, 500)) {
    throw new APIError(400, 'invalid_check_in', 'Check the date, mood, appetite, routines and note (up to 500 characters).');
  }
  return { id: input.id.toLowerCase(), day: input.day, mood: input.mood, appetite: input.appetite, routines: [...input.routines], note: input.note.trim() };
}

export function validateMilestone(input) {
  exactKeys(input, ['id', 'date', 'title', 'note', 'kind']);
  if (!validID(input.id) || !validDay(input.date) || !validText(input.title, 80, true)
      || !validText(input.note, 300) || !milestoneKinds.has(input.kind)) {
    throw new APIError(400, 'invalid_milestone', 'Add a date, title (up to 80 characters), note (up to 300) and supported kind.');
  }
  return { id: input.id.toLowerCase(), date: input.date, title: input.title.trim(), note: input.note.trim(), kind: input.kind };
}

function dayOffset(day, days) {
  const value = new Date(`${day}T12:00:00.000Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

export function sampleJourney(now = new Date()) {
  const today = now.toISOString().slice(0, 10);
  return {
    checkIns: [
      { id: '7e1e7a10-0001-4000-8000-000000000001', day: today, mood: 'steady', appetite: 'comfortable', routines: ['reflection'], note: 'Made a little time to pause today.' },
      { id: '7e1e7a10-0001-4000-8000-000000000002', day: dayOffset(today, -2), mood: 'bright', appetite: 'low', routines: ['nutrition', 'movement'], note: 'Enjoyed a walk with a friend.' },
      { id: '7e1e7a10-0001-4000-8000-000000000003', day: dayOffset(today, -4), mood: 'tough', appetite: 'hungry', routines: [], note: 'A busy day. Glad to have a place to write it down.' },
    ],
    milestones: [
      { id: '7e1e7a10-0002-4000-8000-000000000001', date: dayOffset(today, -2), title: 'Time with a friend', note: 'A small moment I want to remember.', kind: 'everyday' },
    ],
  };
}

function checkInFromRow(row) {
  return validateCheckIn({ id: row.id, day: row.day, mood: row.mood, appetite: row.appetite, routines: JSON.parse(row.routines_json), note: row.note });
}

function milestoneFromRow(row) {
  return validateMilestone({ id: row.id, date: row.date, title: row.title, note: row.note, kind: row.kind });
}

function localJournalDB(env) {
  return env.LOCAL_JOURNAL_STORAGE === 'true' && env.DB;
}

export async function journey(request, env) {
  requireLocalDemo(request, env);
  const db = localJournalDB(env);
  if (!db) return json({ mode: 'demo', storage: 'sample', ...sampleJourney(), notice: 'Sample entries only. This preview does not save a journal on the server.' });
  // A bound LOCAL D1 contains only explicit entries. Do not mix sample records
  // into a user's journal or present sample milestones as their achievements.
  const [entries, milestones] = await Promise.all([
    db.prepare('SELECT id, day, mood, appetite, routines_json, note FROM check_ins WHERE user_id = ? ORDER BY day DESC LIMIT 366').bind(demoUser).all(),
    db.prepare('SELECT id, date, title, note, kind FROM milestones WHERE user_id = ? ORDER BY date DESC, id LIMIT 366').bind(demoUser).all(),
  ]);
  return json({ mode: 'demo', storage: 'local-d1', checkIns: entries.results.map(checkInFromRow), milestones: milestones.results.map(milestoneFromRow), notice: 'Local development journal. No account sync or live service is connected.' });
}

export async function saveCheckIn(request, env) {
  requireLocalDemo(request, env);
  const entry = validateCheckIn(await readJSON(request));
  const db = localJournalDB(env);
  if (!db) return json({ mode: 'demo', stored: false, checkIn: entry, notice: 'Preview only. Keep this entry on your device; the server has not saved it.' }, 200);
  // One entry per calendar day. On repeat, keep its existing ID stable and
  // atomically replace the other fields. Never interpolate notes into SQL.
  const saved = await db.prepare(`INSERT INTO check_ins (id, user_id, day, mood, appetite, routines_json, note, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(user_id, day) DO UPDATE SET mood = excluded.mood, appetite = excluded.appetite,
      routines_json = excluded.routines_json, note = excluded.note, updated_at = excluded.updated_at
    RETURNING id, day, mood, appetite, routines_json, note`)
    .bind(entry.id, demoUser, entry.day, entry.mood, entry.appetite, JSON.stringify(entry.routines), entry.note, Math.floor(Date.now() / 1000)).first();
  if (!saved) throw new Error('No saved entry');
  return json({ mode: 'demo', stored: true, checkIn: checkInFromRow(saved), notice: 'Saved to local development D1 only.' });
}

export async function saveMilestone(request, env) {
  requireLocalDemo(request, env);
  const milestone = validateMilestone(await readJSON(request));
  const db = localJournalDB(env);
  if (!db) return json({ mode: 'demo', stored: false, milestone, notice: 'Preview only. Keep this milestone on your device; the server has not saved it.' }, 200);
  const saved = await db.prepare(`INSERT INTO milestones (id, user_id, date, title, note, kind, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id, user_id) DO UPDATE SET date = excluded.date, title = excluded.title,
      note = excluded.note, kind = excluded.kind, updated_at = excluded.updated_at
    RETURNING id, date, title, note, kind`)
    .bind(milestone.id, demoUser, milestone.date, milestone.title, milestone.note, milestone.kind, Math.floor(Date.now() / 1000)).first();
  if (!saved) throw new Error('No saved milestone');
  return json({ mode: 'demo', stored: true, milestone: milestoneFromRow(saved), notice: 'Saved to local development D1 only.' });
}

export function weeklyReflection(input) {
  exactKeys(input, ['weekStart', 'checkIns']);
  if (!validDay(input.weekStart) || !Array.isArray(input.checkIns) || input.checkIns.length > 7) {
    throw new APIError(400, 'invalid_week', 'Send a week start date and up to seven daily entries.');
  }
  const entries = input.checkIns.map(validateCheckIn);
  const end = dayOffset(input.weekStart, 7);
  if (entries.some(entry => entry.day < input.weekStart || entry.day >= end)
      || new Set(entries.map(entry => entry.day)).size !== entries.length
      || new Set(entries.map(entry => entry.id)).size !== entries.length) {
    throw new APIError(400, 'invalid_week', 'Each entry must be a different day within the selected week.');
  }
  const checkedInDays = entries.length;
  const routineCount = entries.reduce((count, entry) => count + entry.routines.length, 0);
  const body = checkedInDays === 0
    ? 'There are no entries for this week yet. You can begin whenever it suits you. A blank page does not say anything about your progress.'
    : `You recorded ${checkedInDays} ${checkedInDays === 1 ? 'day' : 'days'} and marked ${routineCount} ${routineCount === 1 ? 'routine' : 'routines'} this week. Your entries are moments to look back on, not a score. You decide what matters to you.`;
  // No health inference, note quotation, treatment suggestions, clinical score,
  // streak punishment, or provider call. Notes are intentionally not summarized.
  return { mode: 'demo', title: 'A little space to look back', body, checkedInDays, routineCount };
}

export async function reflect(request, env) {
  requireLocalDemo(request, env);
  const result = weeklyReflection(await readJSON(request, 16384));
  return json(result);
}
