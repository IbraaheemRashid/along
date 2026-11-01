import test from 'node:test';
import assert from 'node:assert/strict';
import { call, demoEnv, entry, milestone, localDB } from './helpers.mjs';
import { sampleJourney, validateCheckIn, validateMilestone, weeklyReflection, validDay } from '../../apps/api/src/journal.mjs';

test('journey is conspicuously sample data with valid calendar days and entries', async () => {
  const result = await call('/journey');
  assert.equal(result.status, 200);
  assert.equal(result.body.mode, 'demo');
  assert.equal(result.body.storage, 'sample');
  assert.match(result.body.notice, /does not save/);
  result.body.checkIns.forEach(validateCheckIn);
  result.body.milestones.forEach(validateMilestone);
  assert.equal(result.body.checkIns.length, 3);
  assert.equal(sampleJourney(new Date('2026-01-01T10:00:00Z')).checkIns[1].day, '2025-12-30');
});

test('preview validates check-ins and milestones without pretending to persist them', async () => {
  const checkIn = await call('/check-ins', entry);
  assert.equal(checkIn.status, 200);
  assert.equal(checkIn.body.stored, false);
  assert.deepEqual(checkIn.body.checkIn, entry);
  const savedMilestone = await call('/milestones', milestone);
  assert.equal(savedMilestone.status, 200);
  assert.equal(savedMilestone.body.stored, false);
  assert.deepEqual(savedMilestone.body.milestone, milestone);
});

test('check-in schema rejects unknown health fields, invalid enums, duplicate routines and long notes', async () => {
  const patches = [
    { id: 'not-a-uuid' }, { day: '2026-02-29' }, { day: '2026-11-01T00:00:00Z' },
    { mood: 'bad' }, { appetite: 'nausea' }, { routines: ['movement', 'movement'] },
    { routines: ['medication'] }, { routines: null }, { note: 'x'.repeat(501) },
    { note: 'null\u0000character' }, { dose: 5 }, { user_id: 'another-user' },
  ];
  for (const patch of patches) assert.equal((await call('/check-ins', { ...entry, ...patch })).status, 400, JSON.stringify(patch));
  assert.equal((await call('/check-ins', { ...entry, note: '', routines: [] })).status, 200);
  assert.equal(validDay('2024-02-29'), true);
  assert.equal(validDay('2026-04-31'), false);
});

test('milestones reject invalid titles, notes, kinds and unexpected attributes', async () => {
  for (const patch of [{ title: '' }, { title: ' ' }, { title: 'x'.repeat(81) }, { note: 'x'.repeat(301) }, { kind: 'weight' }, { date: 'tomorrow' }, { weight: 70 }]) {
    assert.equal((await call('/milestones', { ...milestone, ...patch })).status, 400);
  }
});

test('local D1 persists notes using bindings, replaces a day atomically, and preserves stable ID', async t => {
  const db = localDB(); t.after(() => db.close());
  const env = { ...demoEnv, LOCAL_JOURNAL_STORAGE: 'true', DB: db };
  const input = { ...entry, note: "'); DROP TABLE check_ins; --" };
  const first = await call('/check-ins', input, env);
  assert.equal(first.status, 200);
  assert.equal(first.body.stored, true);
  assert.equal(first.body.checkIn.note, input.note);
  const update = await call('/check-ins', { ...entry, id: '33333333-3333-4333-8333-333333333333', mood: 'tough', routines: [] }, env);
  assert.equal(update.status, 200);
  assert.equal(update.body.checkIn.id, entry.id);
  const journey = await call('/journey', undefined, env);
  assert.equal(journey.body.storage, 'local-d1');
  assert.equal(journey.body.checkIns.length, 1);
  assert.equal(journey.body.checkIns[0].mood, 'tough');
  assert.deepEqual(journey.body.milestones, []);
  assert(db.calls.some(c => c.values.includes(input.note)));
  assert(db.calls.every(c => !c.sql.includes(input.note)));
});

test('a DB binding alone cannot opt users into journal storage', async t => {
  const db = localDB(); t.after(() => db.close());
  const result = await call('/check-ins', entry, { ...demoEnv, DB: db });
  assert.equal(result.body.stored, false);
  assert.equal(db.calls.length, 0);
});

test('milestone IDs are idempotent and only local user records appear in the journey', async t => {
  const db = localDB(); t.after(() => db.close());
  const env = { ...demoEnv, DB: db, LOCAL_JOURNAL_STORAGE: 'true' };
  await call('/milestones', milestone, env);
  await call('/milestones', { ...milestone, title: 'Updated title' }, env);
  db.sqlite.prepare('INSERT INTO milestones VALUES (?, ?, ?, ?, ?, ?, ?)').run('private-id', 'other-user', '2026-11-01', 'Private', 'Private note', 'other', 1);
  const result = await call('/journey', undefined, env);
  assert.equal(result.body.milestones.length, 1);
  assert.equal(result.body.milestones[0].title, 'Updated title');
  assert(!JSON.stringify(result.body).includes('Private note'));
});

test('failed D1 writes cannot claim stored:true or expose private error details', async () => {
  const DB = { prepare() { throw new Error('PRIVATE_TOKEN_AND_NOTE'); } };
  const result = await call('/check-ins', entry, { ...demoEnv, DB, LOCAL_JOURNAL_STORAGE: 'true' });
  assert.equal(result.status, 503);
  assert(!JSON.stringify(result.body).includes('PRIVATE'));
  assert.equal(result.body.stored, undefined);
});

test('weekly reflection counts unique daily entries and routines, never echoes notes or infers health', async () => {
  const entries = [entry, { ...entry, id: '44444444-4444-4444-8444-444444444444', day: '2026-11-02', mood: 'tough', appetite: 'low', routines: ['movement', 'nutrition'], note: 'PRIVATE clinical information' }];
  const result = await call('/weekly-reflection', { weekStart: '2026-11-01', checkIns: entries });
  assert.equal(result.status, 200);
  assert.equal(result.body.mode, 'demo');
  assert.equal(result.body.checkedInDays, 2);
  assert.equal(result.body.routineCount, 3);
  assert(!JSON.stringify(result.body).includes('PRIVATE'));
  const changedSensitiveValues = entries.map(e => ({ ...e, mood: 'bright', appetite: 'hungry', note: '' }));
  assert.deepEqual(result.body, weeklyReflection({ weekStart: '2026-11-01', checkIns: changedSensitiveValues }));
});

test('zero entries and zero routines produce nonjudgmental reflection', async () => {
  const empty = await call('/weekly-reflection', { weekStart: '2026-11-01', checkIns: [] });
  assert.equal(empty.body.checkedInDays, 0);
  assert.equal(empty.body.routineCount, 0);
  assert.match(empty.body.body, /does not say anything about your progress/);
  const noRoutines = weeklyReflection({ weekStart: '2026-11-01', checkIns: [{ ...entry, routines: [] }] });
  assert.equal(noRoutines.routineCount, 0);
  assert.match(noRoutines.body, /not a score/);
});

test('weekly reflection rejects duplicate days, duplicate IDs, out-of-week data and more than seven entries', async () => {
  for (const checkIns of [[entry, entry], [entry, { ...entry, day: '2026-11-02' }], [{ ...entry, day: '2026-11-08' }], Array(8).fill(entry)]) {
    assert.equal((await call('/weekly-reflection', { weekStart: '2026-11-01', checkIns })).status, 400);
  }
});
