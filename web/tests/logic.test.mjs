// Test della logica della web app: gli stessi casi dei test XCTest dell'app iOS.
// Esecuzione: node --test web/tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as L from '../logic.js';

const { DONE, MISSED, PAUSED } = L;

function days(from, to) {
  const out = [];
  for (let o = L.ordinal(from); o <= L.ordinal(to); o++) out.push(L.fromOrdinal(o));
  return out;
}
function entries({ done = [], missed = [], paused = [] } = {}) {
  const m = new Map();
  for (const d of done) m.set(d, DONE);
  for (const d of missed) m.set(d, MISSED);
  for (const d of paused) m.set(d, PAUSED);
  return m;
}
const START = 20260915, TODAY = 20261011, SEP = { y: 2026, m: 9 }, OCT = { y: 2026, m: 10 };
const mock = () => entries({
  done: [20260915, ...days(20260918, 20260926), ...days(20260928, 20261003), ...days(20261007, 20261011)],
  missed: [20260916, 20260927, 20261004, 20261005]
});

test('giorni: ordinali, settimane, mesi', () => {
  assert.equal(L.ordinal(19700101), 0);
  assert.equal(L.ordinal(19691231), -1);
  assert.equal(L.ordinal(20000301), 11017);
  assert.equal(L.ordinal(20261011), 20737);
  for (let o = -719000; o < 2900000; o += 997) {
    const d = L.fromOrdinal(o);
    assert.equal(L.ordinal(d), o);
    const ref = new Date(Date.UTC(1970, 0, 1) + o * 86400000);
    assert.equal(d, ref.getUTCFullYear() * 10000 + (ref.getUTCMonth() + 1) * 100 + ref.getUTCDate());
  }
  assert.equal(L.addDays(20261231, 1), 20270101);
  assert.equal(L.addDays(20240228, 1), 20240229);
  assert.deepEqual([19700101, 20261001, 20261011, 20261012].map(L.isoWeekday), [4, 4, 7, 1]);
  assert.equal(L.weekStart(20270101), 20261228);
  assert.deepEqual(L.addMonths({ y: 2026, m: 1 }, -1), { y: 2025, m: 12 });
  assert.deepEqual(L.addMonths({ y: 2026, m: 10 }, 14), { y: 2027, m: 12 });
  assert.equal(L.isValidDay(20250229), false);
  assert.equal(L.isValidDay(20240229), true);
  const grid = L.monthGrid(OCT);
  assert.equal(grid.length, 34);
  assert.equal(grid[3], 20261001);
  const heat = L.yearHeatmap(2026);
  assert.equal(heat.length, 53);
  assert.equal(heat.flat().filter(Boolean).length, 365);
});

test('riepilogo del mese come nei mockup', () => {
  const oct = L.monthSummary(mock(), OCT, START, TODAY);
  assert.deepEqual([oct.done, oct.missed, oct.unregistered, oct.percent], [8, 2, 1, 80]);
  const sep = L.monthSummary(mock(), SEP, START, TODAY);
  assert.deepEqual([sep.done, sep.missed, sep.unregistered, sep.percent], [13, 2, 1, 87]);
  assert.equal(L.monthSummary(mock(), { y: 2026, m: 11 }, START, TODAY).registered, 0);
  assert.deepEqual([L.summary(2, 1).percent, L.summary(1, 2).percent, L.summary(1, 7).percent], [67, 33, 13]);
  const t = L.totals(mock(), START, TODAY);
  assert.deepEqual([t.done, t.missed, t.unregistered, t.percent], [21, 4, 2, 84]);
});

test('serie attuale e record', () => {
  assert.deepEqual(L.currentStreak(mock(), START, TODAY), { start: 20261007, end: 20261011, length: 5 });
  assert.deepEqual(L.bestStreak(mock(), START, TODAY), { start: 20260918, end: 20260926, length: 9 });
  const m2 = mock(); m2.delete(20261011);
  assert.equal(L.currentStreak(m2, START, TODAY).length, 4);
  const m3 = mock(); m3.set(20261011, MISSED);
  assert.equal(L.currentStreak(m3, START, TODAY), null);
  assert.equal(L.currentStreak(entries({ done: [20261008, 20261009, 20261011] }), 20261001, TODAY).length, 1);
  const tie = entries({ done: [...days(20261001, 20261003), ...days(20261006, 20261008)], missed: [20261004] });
  assert.equal(L.bestStreak(tie, 20261001, TODAY).start, 20261006);
});

test('pause: neutre per percentuale e serie', () => {
  const m = entries({ done: days(20261001, 20261003), missed: [20261006], paused: [20261004, 20261005] });
  const s = L.monthSummary(m, OCT, 20261001, 20261008);
  assert.deepEqual([s.done, s.missed, s.paused, s.unregistered, s.percent], [3, 1, 2, 1, 75]);
  const p = entries({ done: [...days(20261005, 20261006), ...days(20261009, 20261011)], paused: [20261007, 20261008] });
  assert.deepEqual(L.currentStreak(p, 20261001, TODAY), { start: 20261005, end: 20261011, length: 5 });
  const b = entries({
    done: [...days(20261001, 20261003), ...days(20261005, 20261006), ...days(20261008, 20261011)],
    missed: [20261007], paused: [20261004]
  });
  assert.deepEqual(L.bestStreak(b, 20261001, TODAY), { start: 20261001, end: 20261006, length: 5 });
});

test('obiettivi settimanali', () => {
  const S = 20260928;
  assert.equal(L.week(20260928, entries({ done: [20260928, 20260930, 20261002] }), 3, S, TODAY).state, 'success');
  assert.equal(L.week(20261005, entries({ done: [20261006] }), 3, S, 20261012).state, 'failed');
  assert.equal(L.week(20261005, entries({ done: [20261005] }), 3, S, 20261011).state, 'inProgress');
  const paused = entries({ done: [20261005, 20261006, 20261007], paused: days(20261008, 20261011) });
  const w = L.week(20261005, paused, 5, S, 20261012);
  assert.deepEqual([w.target, w.state], [3, 'success']);
  const neutral = entries({ done: [20260928, 20260929, 20261012, 20261013], paused: days(20261005, 20261011) });
  assert.deepEqual(L.weeklyCurrentStreak(neutral, 2, S, 20261014), { start: 20260928, end: 20261012, length: 2 });
  assert.equal(L.weeklyCurrentStreak(entries({ done: [20260928, 20260929, 20261005] }), 2, S, 20261013), null);
  const ms = L.weeklyMonthSummary(entries({ done: [20260928, 20260929, 20261005, 20261012, 20261013] }), OCT, 2, S, 20261020);
  assert.deepEqual([ms.weeks.length, ms.succeeded, ms.failed, ms.percent, ms.doneDays], [4, 2, 1, 67, 3]);
});

test('obiettivi numerici e numeri italiani', () => {
  const kcal = { kind: 'numeric', target: 1800, comparison: 'atMost' };
  const steps = { kind: 'numeric', target: 10000, comparison: 'atLeast' };
  assert.equal(L.effectiveStatus({ value: 1650 }, kcal, 20261010, TODAY), DONE);
  assert.equal(L.effectiveStatus({ value: 1800 }, kcal, 20261010, TODAY), DONE);
  assert.equal(L.effectiveStatus({ value: 1950 }, kcal, 20261010, TODAY), MISSED);
  assert.equal(L.effectiveStatus({ value: 9999 }, steps, TODAY, TODAY), MISSED);
  assert.equal(L.effectiveStatus({ status: PAUSED, value: 3000 }, kcal, 20261010, TODAY), PAUSED);
  assert.equal(L.effectiveStatus({ status: MISSED, value: 10 }, { kind: 'daily' }, 20261010, TODAY), MISSED);
  const cases = { '1800': 1800, '1.800': 1800, '10.000': 10000, '1.234.567': 1234567, '7,5': 7.5, '1.800,5': 1800.5, ' 2,25 ': 2.25, '7.5': 7.5 };
  for (const [text, value] of Object.entries(cases)) assert.equal(L.parseNumber(text), value, text);
  for (const text of ['', 'abc', '-5']) assert.equal(L.parseNumber(text), null, text);
});

test('statistiche per giorno della settimana', () => {
  const stats = L.weekdayStats(mock(), START, TODAY);
  assert.deepEqual([stats[6].done, stats[6].missed, stats[6].percent], [2, 2, 50]);
  assert.equal(L.weakestWeekday(stats).weekday, 7);
});

test('backup compatibile con l\'app iOS', () => {
  const goals = [{
    id: '6E0B7A3C-0000-4000-8000-000000000001', name: 'Meno di 1800 kcal', details: '', emoji: '🥗', color: 'orange',
    startDay: 20260915, createdAt: '2026-09-15T08:00:00Z', archivedAt: null, sortOrder: 0, kind: 'numeric',
    weeklyTarget: 3, target: 1800, comparison: 'atMost', unit: 'kcal',
    entries: { 20261010: { status: null, value: 1650, note: 'cena fuori', fromHealth: false }, 20261011: { status: PAUSED, value: null, note: '', fromHealth: false } }
  }];
  const back = L.decodeBackup(L.encodeBackup(goals, new Date('2026-10-11T12:00:00Z')));
  assert.deepEqual(back, goals);
  assert.throws(() => L.decodeBackup('{"ciao":1}'), L.BackupError);
  assert.throws(() => L.decodeBackup(JSON.stringify({ app: 'Brain', formatVersion: 99, goals: [] })), /più recente/);
  const dirty = JSON.parse(L.encodeBackup(goals));
  dirty.goals[0].entries.push({ day: 20260230, status: 1 }, { day: 20261001, status: 7 });
  dirty.goals.push(dirty.goals[0]);
  const clean = L.decodeBackup(JSON.stringify(dirty));
  assert.equal(clean.length, 1);
  assert.deepEqual(Object.keys(clean[0].entries).map(Number), [20261010, 20261011]);
});
