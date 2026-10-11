// Logica di Brain: stessa identica logica dell'app iOS (Shared/Logic), in JavaScript.
// Funzioni pure: ricevono dati e data di oggi, non toccano salvataggio né orologio.
// I giorni sono interi yyyymmdd (es. 20261011), come nell'app iOS e nei backup.

export const DONE = 1;
export const MISSED = 0;
export const PAUSED = 2;

// ---------------------------------------------------------------- Giorni

export function isLeapYear(y) {
  return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0;
}

export function daysInMonth(y, m) {
  if ([1, 3, 5, 7, 8, 10, 12].includes(m)) return 31;
  if ([4, 6, 9, 11].includes(m)) return 30;
  if (m === 2) return isLeapYear(y) ? 29 : 28;
  return 0;
}

export function isValidDay(raw) {
  if (!Number.isInteger(raw) || raw <= 0) return false;
  const y = Math.trunc(raw / 10000), m = Math.trunc(raw / 100) % 100, d = raw % 100;
  return m >= 1 && m <= 12 && d >= 1 && d <= daysInMonth(y, m);
}

export function makeDay(y, m, d) {
  return y * 10000 + m * 100 + d;
}

export function parts(day) {
  return { y: Math.trunc(day / 10000), m: Math.trunc(day / 100) % 100, d: day % 100 };
}

/** Giorni dal 1° gennaio 1970 (algoritmo "days from civil" di Howard Hinnant). */
export function ordinal(day) {
  const { y: yy, m, d } = parts(day);
  const y = m <= 2 ? yy - 1 : yy;
  const era = Math.floor(y / 400);
  const yoe = y - era * 400;
  const mp = (m + 9) % 12;
  const doy = Math.floor((153 * mp + 2) / 5) + d - 1;
  const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe - 719468;
}

export function fromOrdinal(o) {
  const z = o + 719468;
  const era = Math.floor(z / 146097);
  const doe = z - era * 146097;
  const yoe = Math.floor((doe - Math.floor(doe / 1460) + Math.floor(doe / 36524) - Math.floor(doe / 146096)) / 365);
  const doy = doe - (365 * yoe + Math.floor(yoe / 4) - Math.floor(yoe / 100));
  const mp = Math.floor((5 * doy + 2) / 153);
  const d = doy - Math.floor((153 * mp + 2) / 5) + 1;
  const m = mp < 10 ? mp + 3 : mp - 9;
  const y = yoe + era * 400 + (m <= 2 ? 1 : 0);
  return makeDay(y, m, d);
}

export function addDays(day, n) {
  return fromOrdinal(ordinal(day) + n);
}

/** 1 = lunedì … 7 = domenica. */
export function isoWeekday(day) {
  const mod = ((ordinal(day) % 7) + 7) % 7;
  return ((mod + 3) % 7) + 1;
}

export function weekStart(day) {
  return addDays(day, -(isoWeekday(day) - 1));
}

/** Il giorno di oggi nel fuso orario del telefono. */
export function dayFromDate(date) {
  return makeDay(date.getFullYear(), date.getMonth() + 1, date.getDate());
}

export function dateFromDay(day) {
  const { y, m, d } = parts(day);
  return new Date(y, m - 1, d);
}

// ---------------------------------------------------------------- Mesi

export function monthOf(day) {
  const { y, m } = parts(day);
  return { y, m };
}

export function addMonths({ y, m }, n) {
  const index = y * 12 + (m - 1) + n;
  const ny = Math.floor(index / 12);
  return { y: ny, m: index - ny * 12 + 1 };
}

export function compareMonths(a, b) {
  return a.y !== b.y ? a.y - b.y : a.m - b.m;
}

export function firstDayOfMonth({ y, m }) {
  return makeDay(y, m, 1);
}

export function lastDayOfMonth({ y, m }) {
  return makeDay(y, m, daysInMonth(y, m));
}

/** Griglia del mese da lunedì: null per le caselle vuote iniziali. */
export function monthGrid(month) {
  const first = firstDayOfMonth(month);
  const blanks = isoWeekday(first) - 1;
  const cells = Array(blanks).fill(null);
  for (let d = 1; d <= daysInMonth(month.y, month.m); d++) cells.push(makeDay(month.y, month.m, d));
  return cells;
}

/** Mappa di un anno: colonne di 7 giorni (lunedì–domenica), null fuori dall'anno. */
export function yearHeatmap(year) {
  const first = makeDay(year, 1, 1);
  const last = makeDay(year, 12, 31);
  const columns = [];
  for (let ws = weekStart(first); ws <= last; ws = addDays(ws, 7)) {
    const column = [];
    for (let k = 0; k < 7; k++) {
      const d = addDays(ws, k);
      column.push(d >= first && d <= last ? d : null);
    }
    columns.push(column);
  }
  return columns;
}

// ---------------------------------------------------------------- Regole

/** Numero scritto all'italiana: "1.800", "1800", "7,5". */
export function parseNumber(text) {
  let c = String(text ?? '').trim().replace(/ /g, '');
  if (!c) return null;
  if (c.includes(',')) c = c.replace(/\./g, '').replace(',', '.');
  else if ((c.match(/\./g) || []).length > 1) c = c.replace(/\./g, '');
  else if (c.includes('.') && c.length - c.indexOf('.') === 4) c = c.replace('.', '');
  if (!/^\d*\.?\d+$|^\d+\.?$/.test(c)) return null;
  const v = Number(c);
  return Number.isFinite(v) && v >= 0 ? v : null;
}

/**
 * Stato effettivo di un giorno (DONE, MISSED, PAUSED o null = non registrato).
 * record = { status, value, fromHealth }
 */
export function effectiveStatus(record, goal, day, today) {
  if (!record) return null;
  if (record.status === PAUSED) return PAUSED;
  if (goal.kind !== 'numeric' || record.value == null) return record.status ?? null;
  const met = goal.comparison === 'atMost' ? record.value <= goal.target : record.value >= goal.target;
  if (record.fromHealth && day >= today) return met && goal.comparison === 'atLeast' ? DONE : null;
  return met ? DONE : MISSED;
}

/** Mappa giorno → stato effettivo (solo i giorni con uno stato). */
export function statusMap(goal, today) {
  const map = new Map();
  for (const [day, record] of Object.entries(goal.entries || {})) {
    const s = effectiveStatus(record, goal, Number(day), today);
    if (s != null) map.set(Number(day), s);
  }
  return map;
}

// ---------------------------------------------------------------- Giornalieri

function count(entries, from, to, today) {
  let done = 0, missed = 0, paused = 0, unregistered = 0;
  for (let o = ordinal(from); o <= ordinal(to); o++) {
    const d = fromOrdinal(o);
    const s = entries.get(d);
    if (s === DONE) done++;
    else if (s === MISSED) missed++;
    else if (s === PAUSED) paused++;
    else if (d < today) unregistered++;
  }
  return summary(done, missed, paused, unregistered);
}

export function summary(done, missed, paused = 0, unregistered = 0) {
  const registered = done + missed;
  const percent = registered === 0 ? null : Math.round((done / registered) * 100 + 1e-9);
  return { done, missed, paused, unregistered, registered, percent };
}

export function monthSummary(entries, month, startDay, today) {
  const from = Math.max(firstDayOfMonth(month), startDay);
  const to = Math.min(lastDayOfMonth(month), today);
  return from <= to ? count(entries, from, to, today) : summary(0, 0);
}

export function totals(entries, startDay, today) {
  return startDay <= today ? count(entries, startDay, today, today) : summary(0, 0);
}

function streakOf(first, last, length) {
  return length > 0 && first != null ? { start: first, end: last, length } : null;
}

export function currentStreak(entries, startDay, today) {
  if (entries.get(today) === MISSED) return null;
  let day = entries.get(today) === DONE ? today : addDays(today, -1);
  let n = 0, first = null, last = null;
  while (day >= startDay) {
    const s = entries.get(day);
    if (s === DONE) {
      n++;
      first = day;
      if (last == null) last = day;
    } else if (s !== PAUSED) {
      break;
    }
    day = addDays(day, -1);
  }
  return streakOf(first, last, n);
}

export function bestStreak(entries, startDay, today) {
  if (startDay > today) return null;
  let best = null, n = 0, first = null, last = null;
  const close = () => {
    const run = streakOf(first, last, n);
    if (run && (!best || run.length >= best.length)) best = run;
    n = 0; first = null; last = null;
  };
  for (let o = ordinal(startDay); o <= ordinal(today); o++) {
    const d = fromOrdinal(o);
    const s = entries.get(d);
    if (s === DONE) {
      n++;
      if (first == null) first = d;
      last = d;
    } else if (s === MISSED) close();
    else if (s == null && d < today) close();
  }
  close();
  return best;
}

// ---------------------------------------------------------------- Settimanali

export function week(ws, entries, target, startDay, today) {
  let done = 0, available = 0;
  for (let k = 0; k < 7; k++) {
    const d = addDays(ws, k);
    if (d < startDay) continue;
    const s = entries.get(d);
    if (s === PAUSED) continue;
    available++;
    if (s === DONE && d <= today) done++;
  }
  const t = Math.min(Math.max(target, 1), available);
  let state;
  if (available === 0) state = 'neutral';
  else if (done >= t) state = 'success';
  else if (addDays(ws, 6) < today) state = 'failed';
  else state = 'inProgress';
  return { weekStart: ws, done, target: t, state };
}

export function weeks(entries, target, startDay, today) {
  if (startDay > today) return [];
  const out = [];
  for (let ws = weekStart(startDay); ws <= weekStart(today); ws = addDays(ws, 7)) {
    out.push(week(ws, entries, target, startDay, today));
  }
  return out;
}

export function weeklyMonthSummary(entries, month, target, startDay, today) {
  const list = weeks(entries, target, startDay, today)
    .filter(w => compareMonths(monthOf(addDays(w.weekStart, 6)), month) === 0);
  let doneDays = 0;
  const from = Math.max(firstDayOfMonth(month), startDay);
  const to = Math.min(lastDayOfMonth(month), today);
  for (let o = ordinal(from); from <= to && o <= ordinal(to); o++) {
    if (entries.get(fromOrdinal(o)) === DONE) doneDays++;
  }
  const succeeded = list.filter(w => w.state === 'success').length;
  const failed = list.filter(w => w.state === 'failed').length;
  const percent = succeeded + failed === 0 ? null : Math.round((succeeded / (succeeded + failed)) * 100 + 1e-9);
  return { weeks: list, doneDays, succeeded, failed, percent };
}

export function weeklyCurrentStreak(entries, target, startDay, today) {
  let n = 0, first = null, last = null;
  for (const w of weeks(entries, target, startDay, today).reverse()) {
    if (w.state === 'success') {
      n++;
      first = w.weekStart;
      if (last == null) last = w.weekStart;
    } else if (w.state === 'failed') break;
  }
  return streakOf(first, last, n);
}

export function weeklyBestStreak(entries, target, startDay, today) {
  let best = null, n = 0, first = null, last = null;
  const close = () => {
    const run = streakOf(first, last, n);
    if (run && (!best || run.length >= best.length)) best = run;
    n = 0; first = null; last = null;
  };
  for (const w of weeks(entries, target, startDay, today)) {
    if (w.state === 'success') {
      n++;
      if (first == null) first = w.weekStart;
      last = w.weekStart;
    } else if (w.state === 'failed') close();
  }
  close();
  return best;
}

// ---------------------------------------------------------------- Statistiche

export function weekdayStats(entries, startDay, today) {
  const done = Array(8).fill(0), missed = Array(8).fill(0);
  if (startDay <= today) {
    for (let o = ordinal(startDay); o <= ordinal(today); o++) {
      const d = fromOrdinal(o);
      const s = entries.get(d);
      if (s === DONE) done[isoWeekday(d)]++;
      else if (s === MISSED) missed[isoWeekday(d)]++;
    }
  }
  return [1, 2, 3, 4, 5, 6, 7].map(w => {
    const registered = done[w] + missed[w];
    return {
      weekday: w, done: done[w], missed: missed[w], registered,
      percent: registered === 0 ? null : Math.round((done[w] / registered) * 100 + 1e-9)
    };
  });
}

export function weakestWeekday(stats, minimum = 3) {
  const candidates = stats.filter(s => s.registered >= minimum && s.percent != null);
  let weakest = null;
  for (const s of candidates) if (!weakest || s.percent < weakest.percent) weakest = s;
  return weakest;
}

// ---------------------------------------------------------------- Backup

export const BACKUP_VERSION = 1;

export class BackupError extends Error {}

/** Legge un backup (anche quelli dell'app iOS) e lo ripulisce. Restituisce l'elenco degli obiettivi. */
export function decodeBackup(text) {
  let file;
  try {
    file = JSON.parse(text);
  } catch {
    throw new BackupError('Il file non è un backup di Brain.');
  }
  if (!file || file.app !== 'Brain' || !Array.isArray(file.goals)) {
    throw new BackupError('Il file non è un backup di Brain.');
  }
  if (file.formatVersion > BACKUP_VERSION) {
    throw new BackupError(`Il backup è stato creato da una versione più recente di Brain (formato ${file.formatVersion}).`);
  }
  const seen = new Set();
  const goals = [];
  for (const g of file.goals) {
    if (!g || typeof g.id !== 'string' || seen.has(g.id)) continue;
    seen.add(g.id);
    const entries = {};
    for (const e of g.entries || []) {
      if (!isValidDay(e.day)) continue;
      const status = [0, 1, 2].includes(e.status) ? e.status : null;
      const value = typeof e.value === 'number' && Number.isFinite(e.value) ? e.value : null;
      const note = typeof e.note === 'string' ? e.note : '';
      if (status == null && value == null && !note) continue;
      entries[e.day] = { status, value, note, fromHealth: !!e.fromHealth };
    }
    goals.push({
      id: g.id,
      name: String(g.name || 'Obiettivo'),
      details: String(g.details || ''),
      emoji: String(g.emoji || '🎯'),
      color: String(g.color || 'blue'),
      startDay: isValidDay(g.startDay) ? g.startDay : dayFromDate(new Date(g.createdAt || Date.now())),
      createdAt: g.createdAt || new Date().toISOString(),
      archivedAt: g.archivedAt || null,
      sortOrder: Number.isInteger(g.sortOrder) ? g.sortOrder : goals.length,
      kind: ['daily', 'weekly', 'numeric'].includes(g.kind) ? g.kind : 'daily',
      weeklyTarget: Math.min(Math.max(Number(g.weeklyTarget) || 3, 1), 7),
      target: Number(g.numericTarget) || 0,
      comparison: g.comparison === 'atLeast' ? 'atLeast' : 'atMost',
      unit: String(g.unit || ''),
      entries
    });
  }
  return goals;
}

/** Crea un backup nello stesso formato dell'app iOS. */
export function encodeBackup(goals, exportedAt = new Date()) {
  return JSON.stringify({
    app: 'Brain',
    formatVersion: BACKUP_VERSION,
    exportedAt: exportedAt.toISOString().replace(/\.\d{3}Z$/, 'Z'),
    goals: goals.map(g => ({
      id: g.id, name: g.name, details: g.details, emoji: g.emoji, color: g.color,
      startDay: g.startDay, createdAt: g.createdAt, archivedAt: g.archivedAt || undefined,
      sortOrder: g.sortOrder, kind: g.kind, weeklyTarget: g.weeklyTarget,
      numericTarget: g.target, comparison: g.comparison, unit: g.unit,
      entries: Object.keys(g.entries).map(Number).sort((a, b) => a - b).map(day => {
        const e = g.entries[day];
        const out = { day };
        if (e.status != null) out.status = e.status;
        if (e.value != null) out.value = e.value;
        if (e.note) out.note = e.note;
        if (e.fromHealth) out.fromHealth = true;
        return out;
      })
    }))
  }, null, 2);
}
