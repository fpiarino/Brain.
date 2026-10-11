// Salvataggio sul telefono (localStorage) e tutte le modifiche ai dati.
// Stesse regole dell'app iOS: una registrazione per giorno, le registrazioni vuote spariscono.
import * as L from './logic.js';

const KEY = 'brain.data.v1';

export const COLORS = {
  blue: { name: 'Blu', light: '#2F5BEA', dark: '#6E8CFF' },
  teal: { name: 'Verde acqua', light: '#0E8C8C', dark: '#3CC4C4' },
  purple: { name: 'Viola', light: '#7B4FD6', dark: '#A889F0' },
  pink: { name: 'Rosa', light: '#D6457A', dark: '#F27BA6' },
  orange: { name: 'Arancione', light: '#E07A1F', dark: '#F5A04F' },
  mustard: { name: 'Senape', light: '#B8860B', dark: '#E0B53A' },
  brown: { name: 'Marrone', light: '#8A6A4F', dark: '#B89A7E' },
  graphite: { name: 'Grafite', light: '#5A5F6B', dark: '#9EA3AE' }
};
export const COLOR_KEYS = Object.keys(COLORS);

let state = load();
const listeners = new Set();

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (raw) {
      const data = JSON.parse(raw);
      if (Array.isArray(data.goals)) return data;
    }
  } catch { /* dati illeggibili: si riparte vuoti */ }
  return { goals: [] };
}

function persist() {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
  } catch (error) {
    alert('Impossibile salvare i dati sul telefono. Fai un backup e libera spazio.');
  }
  for (const listener of listeners) listener();
}

/** Chiede a Safari di non cancellare mai i dati della app. */
export async function requestPersistence() {
  try {
    if (navigator.storage && navigator.storage.persist) await navigator.storage.persist();
  } catch { /* non supportato: nessun problema */ }
}

export function subscribe(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function today() {
  return L.dayFromDate(new Date());
}

// ---------------------------------------------------------------- Lettura

export function allGoals() {
  return [...state.goals].sort((a, b) => a.sortOrder - b.sortOrder || a.createdAt.localeCompare(b.createdAt));
}
export function activeGoals() { return allGoals().filter(g => !g.archivedAt); }
export function archivedGoals() {
  return state.goals.filter(g => g.archivedAt).sort((a, b) => b.archivedAt.localeCompare(a.archivedAt));
}
export function goal(id) { return state.goals.find(g => g.id === id) || null; }

export function entry(g, day) { return g.entries[day] || null; }
export function statusOn(g, day, todayDay) { return L.effectiveStatus(entry(g, day), g, day, todayDay); }
export function statusMap(g, todayDay) { return L.statusMap(g, todayDay); }
export function canRegister(g, day, todayDay) { return day >= g.startDay && day <= todayDay; }

export function currentWeek(g, todayDay) {
  return L.week(L.weekStart(todayDay), statusMap(g, todayDay), g.weeklyTarget, g.startDay, todayDay);
}

/** Oggi c'è ancora qualcosa da registrare? */
export function needsRegistration(g, todayDay) {
  if (!canRegister(g, todayDay, todayDay)) return false;
  const e = entry(g, todayDay);
  if (g.kind === 'weekly') return !(e && e.status != null) && currentWeek(g, todayDay).state !== 'success';
  if (g.kind === 'numeric') return !(e && (e.value != null || e.status != null));
  return !(e && e.status != null);
}

/** Colore del segmento di oggi nel riepilogo. */
export function todayIndicator(g, todayDay) {
  const s = statusOn(g, todayDay, todayDay);
  if (g.kind === 'weekly' && s == null && currentWeek(g, todayDay).state === 'success') return L.DONE;
  return s;
}

// ---------------------------------------------------------------- Obiettivi

export function createGoal(fields) {
  const g = {
    id: crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2),
    name: '', details: '', emoji: '🎯', color: COLOR_KEYS[state.goals.length % COLOR_KEYS.length],
    startDay: today(), createdAt: new Date().toISOString(), archivedAt: null,
    sortOrder: state.goals.reduce((max, x) => Math.max(max, x.sortOrder), -1) + 1,
    kind: 'daily', weeklyTarget: 3, target: 0, comparison: 'atMost', unit: '',
    entries: {}, ...fields
  };
  state.goals.push(g);
  persist();
  return g;
}

export function updateGoal(id, fields) {
  const g = goal(id);
  if (!g) return;
  Object.assign(g, fields);
  persist();
}

export function setArchived(id, archived) {
  updateGoal(id, { archivedAt: archived ? new Date().toISOString() : null });
}

export function deleteGoal(id) {
  state.goals = state.goals.filter(g => g.id !== id);
  persist();
}

export function reorder(ids) {
  ids.forEach((id, index) => { const g = goal(id); if (g) g.sortOrder = index; });
  persist();
}

// ---------------------------------------------------------------- Registrazioni

function write(g, day, change) {
  const e = { status: null, value: null, note: '', fromHealth: false, ...(g.entries[day] || {}) };
  change(e);
  if (e.status == null && e.value == null && !e.note.trim()) delete g.entries[day];
  else g.entries[day] = e;
  persist();
}

/** Imposta lo stato (null = non registrato). Sostituisce un eventuale valore. */
export function setStatus(id, day, status) {
  const g = goal(id);
  if (g) write(g, day, e => { e.status = status; e.value = null; e.fromHealth = false; });
}

export function setValue(id, day, value) {
  const g = goal(id);
  if (g) write(g, day, e => {
    e.value = value;
    e.fromHealth = false;
    if (e.status !== L.PAUSED || value != null) e.status = null;
  });
}

export function setNote(id, day, note) {
  const g = goal(id);
  if (!g) return;
  const clean = String(note || '').trim();
  if ((g.entries[day]?.note || '') === clean) return;
  if (!clean && !g.entries[day]) return;
  write(g, day, e => { e.note = clean; });
}

/** Fatto / non fatto; se era già così torna a non registrato. Restituisce i dati precedenti. */
export function toggle(id, day, status) {
  const g = goal(id);
  if (!g) return null;
  const previous = g.entries[day] ? { ...g.entries[day] } : null;
  setStatus(id, day, g.entries[day]?.status === status ? null : status);
  return previous;
}

export function restore(id, day, snapshot) {
  const g = goal(id);
  if (!g) return;
  if (snapshot) g.entries[day] = { ...snapshot };
  else delete g.entries[day];
  persist();
}

// ---------------------------------------------------------------- Backup

export function exportBackup() {
  return L.encodeBackup(allGoals());
}

export function replaceAll(goals) {
  state = { goals };
  persist();
}

// ---------------------------------------------------------------- Testi

const numberFormat = new Intl.NumberFormat('it-IT', { maximumFractionDigits: 1 });
export function formatNumber(v) { return numberFormat.format(v); }
export function formatValue(g, v) { return `${formatNumber(v)} ${g.unit}`.trim(); }

export function targetDescription(g) {
  if (g.kind === 'weekly') return g.weeklyTarget === 1 ? '1 volta a settimana' : `${g.weeklyTarget} volte a settimana`;
  if (g.kind === 'numeric') return `${g.comparison === 'atMost' ? '≤' : '≥'} ${formatNumber(g.target)} ${g.unit}`.trim();
  return 'Ogni giorno';
}
