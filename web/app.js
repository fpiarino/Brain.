// Interfaccia della web app Brain: Oggi, dettaglio con calendario, giorno, editor,
// statistiche, archiviati, riordino, backup. Nessuna libreria esterna.
import * as L from './logic.js';
import * as S from './store.js';

const app = document.getElementById('app');
const sheet = document.getElementById('sheet');
const toast = document.getElementById('toast');

const ui = {
  undo: null,
  undoTimer: null,
  months: {},       // mese mostrato nel calendario, per obiettivo
  years: {},        // anno mostrato nelle statistiche, per obiettivo
  draft: null,      // obiettivo in modifica nell'editor
  onSheetClose: null
};

// ================================================================ Utilità

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const cap = s => s ? s[0].toUpperCase() + s.slice(1) : s;

const fmt = {
  weekday: new Intl.DateTimeFormat('it-IT', { weekday: 'long', day: 'numeric', month: 'long' }),
  dayMonth: new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'long' }),
  short: new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'short' }),
  full: new Intl.DateTimeFormat('it-IT', { day: 'numeric', month: 'long', year: 'numeric' }),
  month: new Intl.DateTimeFormat('it-IT', { month: 'long', year: 'numeric' })
};
const weekdayTitle = d => cap(fmt.weekday.format(L.dateFromDay(d)));
const dayMonth = d => fmt.dayMonth.format(L.dateFromDay(d));
const shortDay = d => fmt.short.format(L.dateFromDay(d)).replace('.', '');
const fullDate = d => fmt.full.format(L.dateFromDay(d));
const monthTitle = m => cap(fmt.month.format(new Date(m.y, m.m - 1, 1)));
const daysText = n => n === 1 ? '1 giorno' : `${n} giorni`;
const WEEKDAY_NAMES = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
const WEEKDAY_SHORT = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
const statusText = s => s === L.DONE ? 'fatto' : s === L.MISSED ? 'non fatto' : s === L.PAUSED ? 'in pausa' : 'non registrato';

const ICON = {
  check: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  x: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 7l10 10M17 7L7 17"/></svg>',
  pause: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 6v12M15 6v12"/></svg>',
  plus: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>',
  more: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12h.01M12 12h.01M16 12h.01" stroke-width="2.6"/></svg>',
  left: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 5l-7 7 7 7"/></svg>',
  right: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M9 5l7 7-7 7"/></svg>',
  up: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 15l6-6 6 6"/></svg>',
  down: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg>',
  chart: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 19V11M12 19V5M19 19v-6"/></svg>'
};

function dot(status, size = 'm') {
  const kind = status === L.DONE ? 'done' : status === L.MISSED ? 'missed' : status === L.PAUSED ? 'paused' : 'empty';
  const icon = status === L.DONE ? ICON.check : status === L.MISSED ? ICON.x : status === L.PAUSED ? ICON.pause : '';
  return `<span class="dot dot-${kind} dot-${size}" aria-hidden="true">${icon}</span>`;
}

function colorVars(key) {
  const c = S.COLORS[key] || S.COLORS.blue;
  return `--gl:${c.light};--gd:${c.dark}`;
}

function chip(g, size = 'm') {
  return `<span class="chip chip-${size} tinted" style="${colorVars(g.color)}" aria-hidden="true">${esc(g.emoji)}</span>`;
}

function navBar({ back, backLabel, title = '', action = '' }) {
  return `<header class="navbar">
    ${back ? `<a class="nav-back" href="${back}">${ICON.left}<span>${esc(backLabel)}</span></a>` : '<span></span>'}
    <span class="nav-title">${esc(title)}</span>
    <span class="nav-action">${action}</span>
  </header>`;
}

function announce(message) {
  const live = document.getElementById('live');
  live.textContent = '';
  setTimeout(() => { live.textContent = message; }, 50);
}

// ================================================================ Router

function route() {
  const parts = location.hash.replace(/^#\/?/, '').split('/').filter(Boolean);
  closeSheet();
  const [first, id, extra] = parts;
  if (first === 'goal' && S.goal(id)) return extra === 'stats' ? renderStats(id) : renderDetail(id);
  if (first === 'new') return renderEditor(null);
  if (first === 'edit' && S.goal(id)) return renderEditor(id);
  if (first === 'archived') return renderArchived();
  if (first === 'reorder') return renderReorder();
  if (first === 'backup') return renderBackup();
  return renderToday();
}

function rerender() {
  // Ridisegna la schermata corrente senza perdere lo scroll.
  if (location.hash.startsWith('#/new') || location.hash.startsWith('#/edit')) return;
  const y = window.scrollY;
  // Rimette il focus sullo stesso controllo (importante con VoiceOver).
  const focused = document.activeElement?.closest?.('[data-action]');
  const key = focused ? ['action', 'id', 'status', 'day', 'delta', 'index'].map(k => focused.dataset[k] ?? '').join('|') : null;
  route();
  window.scrollTo(0, y);
  if (key) {
    const again = [...app.querySelectorAll('[data-action]')]
      .find(el => ['action', 'id', 'status', 'day', 'delta', 'index'].map(k => el.dataset[k] ?? '').join('|') === key);
    again?.focus({ preventScroll: true });
  }
}

// ================================================================ Oggi

function subtitle(g, today) {
  if (!S.canRegister(g, today, today)) return `Inizia il ${shortDay(g.startDay)}`;
  if (S.entry(g, today)?.status === L.PAUSED) return 'Oggi in pausa';
  const map = S.statusMap(g, today);
  if (g.kind === 'weekly') {
    const w = S.currentWeek(g, today);
    const streak = L.weeklyCurrentStreak(map, g.weeklyTarget, g.startDay, today)?.length || 0;
    return `${w.done} di ${w.target} questa settimana${w.state === 'success' ? ' ✓' : ''}${streak > 1 ? ` · serie ${streak} sett.` : ''}`;
  }
  const current = L.currentStreak(map, g.startDay, today)?.length || 0;
  const best = L.bestStreak(map, g.startDay, today)?.length || 0;
  let text = current === 0 ? (best > 0 ? `Serie: 0 · record ${best}` : 'Nessuna serie, per ora')
    : current >= best && current > 1 ? `Serie: ${daysText(current)} · record!` : `Serie: ${daysText(current)}`;
  if (g.kind === 'numeric') text = `${S.targetDescription(g)} · ${text}`;
  return text;
}

function toggleButton(g, status, selected) {
  const isDone = status === L.DONE;
  return `<button class="toggle ${isDone ? 'toggle-done' : 'toggle-missed'}" data-action="toggle" data-id="${g.id}" data-status="${status}"
      aria-pressed="${selected}" aria-label="${isDone ? 'Fatto' : 'Non fatto'}: ${esc(g.name)}">${isDone ? ICON.check : ICON.x}</button>`;
}

function controls(g, today) {
  const stored = S.entry(g, today)?.status;
  if (g.kind === 'daily') return `<div class="controls">${toggleButton(g, L.MISSED, stored === L.MISSED)}${toggleButton(g, L.DONE, stored === L.DONE)}</div>`;
  if (g.kind === 'weekly') return `<div class="controls">${toggleButton(g, L.DONE, stored === L.DONE)}</div>`;
  const value = S.entry(g, today)?.value;
  const status = S.statusOn(g, today, today);
  return `<div class="controls"><button class="value-btn" data-action="value" data-id="${g.id}"
      aria-label="${value != null ? `Valore di oggi ${esc(S.formatValue(g, value))}, ${statusText(status)}` : `Inserisci il valore di oggi: ${esc(g.name)}`}">
      ${value != null ? dot(status, 's') : ''}<span>${value != null ? esc(S.formatValue(g, value)) : 'Inserisci'}</span></button></div>`;
}

function renderToday() {
  const today = S.today();
  const goals = S.activeGoals();
  const archived = S.archivedGoals();
  const registrable = goals.filter(g => S.canRegister(g, today, today));
  const indicators = registrable.map(g => S.todayIndicator(g, today));
  const pending = goals.filter(g => S.needsRegistration(g, today)).length;
  const n = s => indicators.filter(x => x === s).length;

  let summaryText = 'Nessun obiettivo da registrare oggi';
  if (indicators.length) {
    const p = [`${n(L.DONE)} ${n(L.DONE) === 1 ? 'fatto' : 'fatti'}`, `${n(L.MISSED)} ${n(L.MISSED) === 1 ? 'non fatto' : 'non fatti'}`];
    if (n(L.PAUSED)) p.push(`${n(L.PAUSED)} in pausa`);
    summaryText = pending ? [...p, `${pending} da registrare`].join(' · ') : `Tutto registrato: ${p.join(' · ')}`;
  }

  const top = `<header class="navbar">
      <button class="icon-btn" data-action="menu" aria-label="Altro">${ICON.more}</button>
      <span></span>
      <a class="icon-btn" href="#/new" aria-label="Nuovo obiettivo">${ICON.plus}</a>
    </header>
    <h1 class="large-title">Oggi</h1>`;

  if (!goals.length) {
    app.innerHTML = `${top}
      ${installHint()}
      <section class="empty">
        <div class="empty-dots" aria-hidden="true">${dot(L.DONE, 'l')}${dot(L.MISSED, 'l')}${dot(null, 'l')}</div>
        <h2>Nessun obiettivo</h2>
        <p>Crea il tuo primo obiettivo e segna ogni giorno se l'hai rispettato.</p>
        <a class="btn-primary" href="#/new">Crea un obiettivo</a>
        <a class="btn-link" href="#/backup">Ripristina da un backup</a>
        ${archived.length ? `<a class="btn-link" href="#/archived">Obiettivi archiviati (${archived.length})</a>` : ''}
      </section>`;
    return;
  }

  app.innerHTML = `${top}
    ${installHint()}
    <section class="card summary" role="status" aria-label="${esc(weekdayTitle(today))}. ${esc(summaryText)}">
      <p class="summary-date">${esc(weekdayTitle(today))}</p>
      ${indicators.length ? `<div class="segments" aria-hidden="true">${indicators.map(s => `<span class="seg seg-${s === L.DONE ? 'done' : s === L.MISSED ? 'missed' : s === L.PAUSED ? 'paused' : 'empty'}"></span>`).join('')}</div>` : ''}
      <p class="muted">${esc(summaryText)}</p>
    </section>
    <h2 class="section-label">Obiettivi attivi</h2>
    <ul class="card list" role="list">
      ${goals.map(g => {
        const can = S.canRegister(g, today, today);
        return `<li class="row">
          <a class="row-info" href="#/goal/${g.id}" aria-label="${esc(g.name)}, ${esc(subtitle(g, today))}${can ? `, oggi: ${statusText(S.statusOn(g, today, today))}` : ''}">
            ${chip(g)}
            <span class="row-text"><span class="row-title">${esc(g.name)}</span><span class="row-sub">${esc(subtitle(g, today))}</span></span>
          </a>
          ${can ? controls(g, today) : ''}
        </li>`;
      }).join('')}
    </ul>
    <p class="footnote">Un tocco su ✓ o ✗ registra il giorno; un secondo tocco lo riporta a «non registrato». Tocca il nome per il calendario, le note e le pause.</p>`;
}

function isStandalone() {
  return navigator.standalone === true || matchMedia('(display-mode: standalone)').matches;
}

/** In Safari (non ancora installata) spiega come aggiungerla alla Home. */
function installHint() {
  if (isStandalone()) return '';
  return `<section class="card install">
    <span class="chip chip-m tinted" style="${colorVars('blue')}" aria-hidden="true">📲</span>
    <div><b class="install-title">Installa Brain sull'iPhone</b>
    <p>In Safari tocca <b>Condividi</b> e poi <b>Aggiungi alla schermata Home</b>. Poi usa sempre l'icona sulla Home: i dati salvati qui in Safari restano separati da quelli dell'app installata.</p></div>
  </section>`;
}

function showUndo(message, undo) {
  clearTimeout(ui.undoTimer);
  ui.undo = undo;
  toast.innerHTML = `<span>${esc(message)}</span><button data-action="undo">Annulla</button>`;
  toast.hidden = false;
  announce(message);
  ui.undoTimer = setTimeout(hideUndo, 5000);
}

function hideUndo() {
  ui.undo = null;
  toast.hidden = true;
}

// ================================================================ Dettaglio

function renderDetail(id) {
  const g = S.goal(id);
  const today = S.today();
  const map = S.statusMap(g, today);
  const startMonth = L.monthOf(Math.min(g.startDay, today));
  const thisMonth = L.monthOf(today);
  let month = ui.months[id] || thisMonth;
  if (L.compareMonths(month, startMonth) < 0) month = startMonth;
  if (L.compareMonths(month, thisMonth) > 0) month = thisMonth;
  ui.months[id] = month;

  // Serie
  let streaks;
  if (g.kind === 'weekly') {
    const cur = L.weeklyCurrentStreak(map, g.weeklyTarget, g.startDay, today);
    const best = L.weeklyBestStreak(map, g.weeklyTarget, g.startDay, today);
    const w = n => n === 1 ? 'settimana' : 'settimane';
    streaks = [
      ['Serie attuale', cur?.length || 0, w(cur?.length || 0), cur ? `dalla settimana del ${shortDay(cur.start)}` : 'Nessuna serie in corso'],
      ['Record', best?.length || 0, w(best?.length || 0), best ? `dalla settimana del ${shortDay(best.start)}` : 'Ancora nessuno']
    ];
  } else {
    const cur = L.currentStreak(map, g.startDay, today);
    const best = L.bestStreak(map, g.startDay, today);
    const g2 = n => n === 1 ? 'giorno' : 'giorni';
    streaks = [
      ['Serie attuale', cur?.length || 0, g2(cur?.length || 0), cur ? `dal ${dayMonth(cur.start)}` : 'Nessuna serie in corso'],
      ['Record', best?.length || 0, g2(best?.length || 0), best ? (best.start === best.end ? dayMonth(best.start) : `${shortDay(best.start)} – ${shortDay(best.end)}`) : 'Ancora nessuno']
    ];
  }

  // Calendario
  const cells = L.monthGrid(month).map(day => {
    if (day == null) return '<span class="cal-cell" aria-hidden="true"></span>';
    const { d } = L.parts(day);
    const isToday = day === today;
    const registrable = day >= g.startDay && day <= today;
    const e = S.entry(g, day);
    const hasNote = !!e?.note;
    const s = map.get(day) ?? null;
    let label = dayMonth(day) + (isToday ? ', oggi' : '');
    if (registrable) {
      label += `, ${statusText(s)}`;
      if (e?.value != null) label += `, ${S.formatValue(g, e.value)}`;
    } else label += day > today ? ', nel futuro' : ', prima della data di inizio';
    if (hasNote) label += ', con nota';
    return `<button class="cal-cell${isToday ? ' is-today' : ''}" ${registrable ? `data-action="day" data-id="${id}" data-day="${day}"` : 'disabled'} aria-label="${esc(label)}">
      <span class="cal-num">${d}${hasNote ? '<i class="note-mark"></i>' : ''}</span>
      ${registrable ? dot(s) : '<span class="dot dot-future dot-m"></span>'}
    </button>`;
  }).join('');

  // Riepilogo del mese
  let summaryHtml;
  if (g.kind === 'weekly') {
    const ws = L.weeklyMonthSummary(map, month, g.weeklyTarget, g.startDay, today);
    const weekDot = w => dot(w.state === 'success' ? L.DONE : w.state === 'failed' ? L.MISSED : w.state === 'neutral' ? L.PAUSED : null, 's');
    const weekText = w => w.state === 'neutral' ? 'in pausa' : `${w.done} di ${w.target}${w.state === 'inProgress' ? ', in corso' : ''}`;
    summaryHtml = `<div class="sum-row">
        <div class="sum-item">${dot(L.DONE, 's')}<b>${ws.succeeded}</b><span>${ws.succeeded === 1 ? 'settimana riuscita' : 'settimane riuscite'}</span></div>
        <div class="sum-item">${dot(L.MISSED, 's')}<b>${ws.failed}</b><span>${ws.failed === 1 ? 'non riuscita' : 'non riuscite'}</span></div>
        <div class="sum-item"><b>${ws.doneDays}</b><span>${ws.doneDays === 1 ? 'giorno fatto' : 'giorni fatti'}</span></div>
      </div>
      <ul class="week-list" role="list">${ws.weeks.map(w => `<li>${weekDot(w)}<span>Settimana del ${esc(shortDay(w.weekStart))}</span><span class="muted">${weekText(w)}</span></li>`).join('')}</ul>`;
  } else {
    const ms = L.monthSummary(map, month, g.startDay, today);
    const extra = [];
    if (ms.paused) extra.push(ms.paused === 1 ? '1 giorno in pausa' : `${ms.paused} giorni in pausa`);
    if (g.kind === 'numeric') {
      const values = Object.entries(g.entries)
        .filter(([day, e]) => L.compareMonths(L.monthOf(Number(day)), month) === 0 && e.value != null && e.status !== L.PAUSED)
        .map(([, e]) => e.value);
      if (values.length) extra.push(`media ${S.formatValue(g, values.reduce((a, b) => a + b, 0) / values.length)}`);
    }
    summaryHtml = `<div class="sum-row">
        <div class="sum-item">${dot(L.DONE, 's')}<b>${ms.done}</b><span>${ms.done === 1 ? 'fatto' : 'fatti'}</span></div>
        <div class="sum-item">${dot(L.MISSED, 's')}<b>${ms.missed}</b><span>${ms.missed === 1 ? 'non fatto' : 'non fatti'}</span></div>
        <div class="sum-item"><b>${ms.percent == null ? '–' : ms.percent + '%'}</b><span>${ms.registered ? `su ${ms.registered} registrati` : 'nessun giorno registrato'}</span></div>
      </div>
      ${extra.length ? `<p class="muted small center">${esc(extra.join(' · '))}</p>` : ''}`;
  }

  const notes = Object.entries(g.entries)
    .filter(([day, e]) => e.note && L.compareMonths(L.monthOf(Number(day)), month) === 0)
    .sort((a, b) => Number(b[0]) - Number(a[0]));

  const subtitleParts = [];
  if (g.details.trim()) subtitleParts.push(g.details.trim());
  if (g.kind !== 'daily') subtitleParts.push(S.targetDescription(g));
  subtitleParts.push(g.startDay > today ? `inizia il ${fullDate(g.startDay)}` : `dal ${fullDate(g.startDay)}`);
  if (g.archivedAt) subtitleParts.push('archiviato');

  const canBack = L.compareMonths(month, startMonth) > 0;
  const canNext = L.compareMonths(month, thisMonth) < 0;

  app.innerHTML = `${navBar({ back: '#/', backLabel: 'Oggi', action: `<a href="#/edit/${id}">Modifica</a>` })}
    <section class="detail-head">
      ${chip(g, 'l')}
      <div><h1 class="title2">${esc(g.name)}</h1><p class="muted">${esc(subtitleParts.join(' · '))}</p></div>
    </section>
    <section class="streaks">
      ${streaks.map(([t, v, u, c]) => `<div class="card streak" role="group" aria-label="${t}: ${v} ${u}, ${esc(c)}">
        <span class="muted small">${t}</span><span class="streak-value"><b>${v}</b> <span class="muted">${u}</span></span><span class="muted small">${esc(c)}</span>
      </div>`).join('')}
    </section>
    <section class="card calendar">
      <div class="cal-head">
        <button class="icon-btn" data-action="month" data-id="${id}" data-delta="-1" ${canBack ? '' : 'disabled'} aria-label="Mese precedente">${ICON.left}</button>
        <h2>${esc(monthTitle(month))}</h2>
        <button class="icon-btn" data-action="month" data-id="${id}" data-delta="1" ${canNext ? '' : 'disabled'} aria-label="Mese successivo">${ICON.right}</button>
      </div>
      <div class="cal-grid cal-weekdays" aria-hidden="true">${['L', 'M', 'M', 'G', 'V', 'S', 'D'].map(x => `<span>${x}</span>`).join('')}</div>
      <div class="cal-grid">${cells}</div>
      <hr>
      ${summaryHtml}
    </section>
    <p class="footnote">Tocca un giorno per registrarlo, correggerlo, metterlo in pausa o aggiungere una nota.</p>
    ${notes.length ? `<section class="card notes"><h2>Note di ${esc(monthTitle(month).toLowerCase())}</h2>
      ${notes.map(([day, e]) => `<button class="note" data-action="day" data-id="${id}" data-day="${day}">
        ${dot(map.get(Number(day)) ?? null, 's')}<span><b>${esc(weekdayTitle(Number(day)))}</b><span>${esc(e.note)}</span></span></button>`).join('')}
    </section>` : ''}
    <a class="card link-row" href="#/goal/${id}/stats">${ICON.chart}<span>Statistiche</span>${ICON.right}</a>`;
}

// ================================================================ Foglio del giorno

function openSheet(html, onClose) {
  sheet.innerHTML = `<div class="sheet-body">${html}</div>`;
  ui.onSheetClose = onClose || null;
  if (!sheet.open) sheet.showModal();
}

function closeSheet() {
  if (sheet.open) sheet.close();
}

sheet.addEventListener('close', () => {
  const callback = ui.onSheetClose;
  ui.onSheetClose = null;
  if (callback) callback();
  rerender();
});
sheet.addEventListener('click', event => {
  if (event.target === sheet) closeSheet(); // tocco fuori dal foglio
});

function openDaySheet(id, day) {
  const g = S.goal(id);
  const today = S.today();
  const e = S.entry(g, day);
  const current = g.kind === 'numeric' ? (e?.status === L.PAUSED ? L.PAUSED : null) : (e?.status ?? null);
  const hasData = !!e && (e.status != null || e.value != null);
  const option = (status, label, selected) => `<button class="option${selected ? ' selected' : ''}" data-action="day-status" data-id="${id}" data-day="${day}" data-status="${status ?? 'none'}" aria-pressed="${selected}">
      ${dot(status)}<span>${label}</span>${selected ? `<span class="option-check">${ICON.check}</span>` : ''}</button>`;
  const options = [];
  if (g.kind === 'daily') options.push(option(L.DONE, 'Fatto', current === L.DONE), option(L.MISSED, 'Non fatto', current === L.MISSED));
  if (g.kind === 'weekly') options.push(option(L.DONE, 'Fatto', current === L.DONE));
  options.push(option(L.PAUSED, 'Pausa (malattia, viaggio…)', current === L.PAUSED), option(null, 'Non registrato', !hasData));

  const status = S.statusOn(g, day, today);
  openSheet(`
    <div class="sheet-head"><h2 id="sheet-title">${esc(weekdayTitle(day))}</h2><button class="text-btn" data-action="close-sheet">Fine</button></div>
    <p class="muted">${esc(g.emoji)} ${esc(g.name)}</p>
    ${g.kind === 'numeric' ? `<label class="field-label" for="day-value">Valore (obiettivo ${esc(S.targetDescription(g))})</label>
      <div class="value-row">
        <input id="day-value" class="input" inputmode="decimal" autocomplete="off" placeholder="Es. 1650" value="${e?.value != null ? String(e.value).replace('.', ',') : ''}">
        ${g.unit ? `<span class="muted">${esc(g.unit)}</span>` : ''}
        <button class="btn-primary small" data-action="day-value" data-id="${id}" data-day="${day}">Salva</button>
      </div>
      ${status != null && status !== L.PAUSED ? `<p class="muted small">Esito: ${statusText(status)}</p>` : ''}` : ''}
    <div class="options">${options.join('')}</div>
    <p class="muted small">«Pausa» e «Non registrato» non contano nella percentuale. La pausa non interrompe la serie; un giorno non registrato sì.</p>
    <label class="field-label" for="day-note">Nota</label>
    <textarea id="day-note" class="input" rows="3" placeholder="Es. cena fuori, giornata pesante…">${esc(e?.note || '')}</textarea>
  `, () => saveNote(id, day));
  sheet.setAttribute('aria-labelledby', 'sheet-title');
}

function saveNote(id, day) {
  const field = document.getElementById('day-note');
  if (field && S.goal(id)) S.setNote(id, day, field.value);
}

function openValueSheet(id) {
  const g = S.goal(id);
  const day = S.today();
  const e = S.entry(g, day);
  openSheet(`
    <div class="sheet-head"><h2 id="sheet-title">${esc(weekdayTitle(day))}</h2><button class="text-btn" data-action="close-sheet">Annulla</button></div>
    <label class="field-label" for="value-input">${esc(g.emoji)} ${esc(g.name)}</label>
    <div class="value-row">
      <input id="value-input" class="input big" inputmode="decimal" autocomplete="off" placeholder="Es. 1650" value="${e?.value != null ? String(e.value).replace('.', ',') : ''}">
      ${g.unit ? `<span class="muted">${esc(g.unit)}</span>` : ''}
    </div>
    <p class="muted small">Obiettivo: ${esc(S.targetDescription(g))}.</p>
    <button class="btn-primary wide" data-action="save-value" data-id="${id}">Salva</button>
    ${e?.value != null ? `<button class="btn-link danger" data-action="clear-value" data-id="${id}">Cancella il valore</button>` : ''}
  `);
  setTimeout(() => document.getElementById('value-input')?.focus(), 250);
}

function openMenu() {
  const archived = S.archivedGoals().length;
  openSheet(`
    <div class="sheet-head"><h2 id="sheet-title">Altro</h2><button class="text-btn" data-action="close-sheet">Fine</button></div>
    <nav class="menu">
      ${S.activeGoals().length > 1 ? '<a href="#/reorder">Riordina obiettivi</a>' : ''}
      <a href="#/backup">Backup e ripristino</a>
      ${archived ? `<a href="#/archived">Obiettivi archiviati (${archived})</a>` : ''}
    </nav>
  `);
}

// ================================================================ Editor

const EMOJIS = ['🎯', '🥗', '🚶', '🏃', '💧', '📚', '🧘', '😴', '📵', '🏋️', '🍎', '🚭', '✍️', '🎸', '🧹', '💰'];

function renderEditor(id) {
  const existing = id ? S.goal(id) : null;
  if (!ui.draft || ui.draft.editingId !== (id || 'new')) {
    ui.draft = existing
      ? { ...existing, editingId: id, targetText: existing.kind === 'numeric' ? String(existing.target).replace('.', ',') : '' }
      : { editingId: 'new', name: '', details: '', emoji: '🎯', color: S.COLOR_KEYS[S.allGoals().length % S.COLOR_KEYS.length],
          startDay: S.today(), kind: 'daily', weeklyTarget: 3, comparison: 'atMost', targetText: '', unit: '' };
  }
  const d = ui.draft;
  const startIso = (() => { const { y, m, d: dd } = L.parts(d.startDay); return `${y}-${String(m).padStart(2, '0')}-${String(dd).padStart(2, '0')}`; })();
  const kindFooter = d.kind === 'weekly'
    ? 'Segni i giorni in cui lo fai; la settimana (lunedì–domenica) riesce quando arrivi al numero scelto.'
    : d.kind === 'numeric' ? 'Ogni giorno inserisci un valore: è fatto se rispetta la soglia.' : 'Ogni giorno segni fatto o non fatto.';

  app.innerHTML = `<header class="navbar">
      <a class="nav-text" href="${id ? `#/goal/${id}` : '#/'}">Annulla</a>
      <span class="nav-title">${id ? 'Modifica obiettivo' : 'Nuovo obiettivo'}</span>
      <button class="nav-text strong" data-action="save-goal" id="save-goal">Salva</button>
    </header>
    <div class="preview" aria-hidden="true">
      <span class="chip chip-xl tinted" style="${colorVars(d.color)}">${esc(d.emoji)}</span>
      <span id="preview-name" class="preview-name">${esc(d.name.trim() || 'Nuovo obiettivo')}</span>
    </div>
    <div class="card form">
      <label class="field"><span>Nome</span><input id="f-name" class="plain" value="${esc(d.name)}" placeholder="Es. Mangiare meno di 1800 kcal" autocomplete="off" enterkeyhint="done"></label>
      <label class="field"><span>Descrizione</span><textarea id="f-details" class="plain" rows="1" placeholder="Opzionale">${esc(d.details)}</textarea></label>
    </div>

    <h2 class="section-label">Tipo di obiettivo</h2>
    <div class="card form">
      <div class="segmented" role="radiogroup" aria-label="Tipo di obiettivo">
        ${[['daily', 'Sì / No'], ['weekly', 'A settimana'], ['numeric', 'Numerico']].map(([k, label]) =>
          `<button role="radio" aria-checked="${d.kind === k}" data-action="kind" data-kind="${k}">${label}</button>`).join('')}
      </div>
      ${d.kind === 'weekly' ? `<div class="stepper">
          <span>${d.weeklyTarget === 1 ? '1 volta a settimana' : `${d.weeklyTarget} volte a settimana`}</span>
          <span class="stepper-btns">
            <button data-action="weekly" data-delta="-1" ${d.weeklyTarget <= 1 ? 'disabled' : ''} aria-label="Una volta in meno">−</button>
            <button data-action="weekly" data-delta="1" ${d.weeklyTarget >= 7 ? 'disabled' : ''} aria-label="Una volta in più">+</button>
          </span></div>` : ''}
      ${d.kind === 'numeric' ? `<div class="segmented" role="radiogroup" aria-label="Confronto con la soglia">
          ${[['atMost', 'Al massimo'], ['atLeast', 'Almeno']].map(([k, label]) =>
            `<button role="radio" aria-checked="${d.comparison === k}" data-action="comparison" data-comparison="${k}">${label}</button>`).join('')}
        </div>
        <div class="field-row">
          <label class="field"><span>Soglia</span><input id="f-target" class="plain" inputmode="decimal" value="${esc(d.targetText)}" placeholder="Es. 1800" autocomplete="off"></label>
          <label class="field"><span>Unità</span><input id="f-unit" class="plain" value="${esc(d.unit)}" placeholder="es. kcal" autocomplete="off"></label>
        </div>` : ''}
    </div>
    <p class="footnote">${kindFooter}</p>

    <h2 class="section-label">Icona</h2>
    <div class="card form">
      <div class="emoji-grid">
        ${EMOJIS.map(e => `<button class="emoji${e === d.emoji ? ' selected' : ''}" style="${colorVars(d.color)}" data-action="emoji" data-emoji="${e}" aria-pressed="${e === d.emoji}" aria-label="${e}">${e}</button>`).join('')}
      </div>
      <label class="field"><span>Altra emoji</span><input id="f-emoji" class="plain" placeholder="Scrivi un'emoji" autocomplete="off"></label>
    </div>

    <h2 class="section-label">Colore</h2>
    <div class="card form">
      <div class="color-grid">
        ${S.COLOR_KEYS.map(k => `<button class="swatch tinted${k === d.color ? ' selected' : ''}" style="${colorVars(k)}" data-action="color" data-color="${k}" aria-pressed="${k === d.color}" aria-label="${S.COLORS[k].name}"></button>`).join('')}
      </div>
    </div>

    <div class="card form">
      <label class="field inline"><span>Data di inizio</span><input id="f-start" type="date" value="${startIso}"></label>
    </div>
    <p class="footnote">I giorni prima della data di inizio non contano.</p>

    ${existing ? `<div class="card list">
        <button class="list-btn" data-action="archive" data-id="${id}">${existing.archivedAt ? 'Ripristina obiettivo' : 'Archivia obiettivo'}</button>
        <button class="list-btn danger" data-action="delete" data-id="${id}">Elimina obiettivo…</button>
      </div>
      <p class="footnote">Gli obiettivi archiviati spariscono da «Oggi» ma conservano tutto lo storico.</p>` : ''}`;

  updateSaveButton();
  const bind = (fieldId, key, after) => document.getElementById(fieldId)?.addEventListener('input', ev => { d[key] = ev.target.value; after?.(); updateSaveButton(); });
  bind('f-name', 'name', () => { document.getElementById('preview-name').textContent = d.name.trim() || 'Nuovo obiettivo'; });
  bind('f-details', 'details');
  bind('f-target', 'targetText');
  bind('f-unit', 'unit');
  document.getElementById('f-start').addEventListener('change', ev => {
    const [y, m, dd] = ev.target.value.split('-').map(Number);
    if (y && m && dd) d.startDay = L.makeDay(y, m, dd);
  });
  document.getElementById('f-emoji').addEventListener('input', ev => {
    const chars = [...new Intl.Segmenter('it', { granularity: 'grapheme' }).segment(ev.target.value)].map(s => s.segment);
    const picked = chars.reverse().find(c => /\p{Extended_Pictographic}/u.test(c));
    if (picked) { d.emoji = picked; renderEditor(id); }
  });
  if (!id) setTimeout(() => document.getElementById('f-name')?.focus(), 300);
}

function updateSaveButton() {
  const d = ui.draft;
  const ok = d.name.trim() && (d.kind !== 'numeric' || L.parseNumber(d.targetText) != null);
  const button = document.getElementById('save-goal');
  if (button) button.disabled = !ok;
}

function saveGoal() {
  const d = ui.draft;
  const fields = {
    name: d.name.trim(), details: d.details.trim(), emoji: d.emoji, color: d.color, startDay: d.startDay,
    kind: d.kind, weeklyTarget: d.weeklyTarget
  };
  if (d.kind === 'numeric') Object.assign(fields, { target: L.parseNumber(d.targetText) ?? 0, comparison: d.comparison, unit: d.unit.trim() });
  let id = d.editingId;
  if (id === 'new') id = S.createGoal(fields).id;
  else S.updateGoal(id, fields);
  ui.draft = null;
  S.requestPersistence();
  location.hash = d.editingId === 'new' ? '#/' : `#/goal/${id}`;
}

// ================================================================ Statistiche

function renderStats(id) {
  const g = S.goal(id);
  const today = S.today();
  const map = S.statusMap(g, today);
  const year = ui.years[id] || L.parts(today).y;
  const startYear = L.parts(g.startDay).y;
  const totals = L.totals(map, g.startDay, today);
  const weeks = L.weeks(map, g.weeklyTarget, g.startDay, today);
  const ok = weeks.filter(w => w.state === 'success').length;
  const ko = weeks.filter(w => w.state === 'failed').length;

  const columns = L.yearHeatmap(year);
  const monthNames = ['gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic'];
  const yearDone = [...map].filter(([d, s]) => L.parts(d).y === year && s === L.DONE).length;
  const yearMissed = [...map].filter(([d, s]) => L.parts(d).y === year && s === L.MISSED).length;
  const heat = columns.map(col => {
    const first = col.find(d => d && L.parts(d).d === 1);
    return `<div class="heat-col"><span class="heat-month">${first ? monthNames[L.parts(first).m - 1] : ''}</span>${col.map(d => {
      if (!d) return '<span class="heat"></span>';
      const inRange = d >= g.startDay && d <= today;
      const s = map.get(d);
      const cls = !inRange ? 'out' : s === L.DONE ? 'done' : s === L.MISSED ? 'missed' : s === L.PAUSED ? 'paused' : 'empty';
      return `<span class="heat heat-${cls}"></span>`;
    }).join('')}</div>`;
  }).join('');

  const stats = L.weekdayStats(map, g.startDay, today);
  const weakest = g.kind === 'weekly' ? null : L.weakestWeekday(stats);
  const maxDone = Math.max(1, ...stats.map(s => s.done));
  const bars = stats.map(s => {
    const value = g.kind === 'weekly' ? s.done / maxDone : (s.percent ?? 0) / 100;
    const label = g.kind === 'weekly' ? String(s.done) : s.percent == null ? '–' : `${s.percent}%`;
    const a11y = g.kind === 'weekly' ? `${s.done} giorni fatti` : s.percent == null ? 'nessun giorno registrato' : `${s.percent} per cento, ${s.done} fatti su ${s.registered}`;
    return `<div class="bar" role="img" aria-label="${cap(WEEKDAY_NAMES[s.weekday - 1])}: ${a11y}">
      <span class="bar-label">${label}</span>
      <span class="bar-track"><span class="bar-fill${weakest && weakest.weekday === s.weekday ? ' weak' : ''}" style="height:${Math.round(value * 100)}%"></span></span>
      <span class="bar-day">${WEEKDAY_SHORT[s.weekday - 1]}</span></div>`;
  }).join('');

  app.innerHTML = `${navBar({ back: `#/goal/${id}`, backLabel: 'Indietro', title: 'Statistiche' })}
    <section class="card">
      <h2>Da sempre</h2>
      <p>${g.kind === 'weekly'
        ? `${ok} settimane riuscite su ${ok + ko} concluse · ${totals.done} giorni fatti`
        : `${totals.done} fatti · ${totals.missed} non fatti${totals.percent != null ? ` · ${totals.percent}% di successo` : ''}`}</p>
      ${totals.paused || totals.unregistered ? `<p class="muted small">${daysText(totals.paused)} in pausa · ${daysText(totals.unregistered)} ${totals.unregistered === 1 ? 'non registrato' : 'non registrati'}</p>` : ''}
    </section>
    <section class="card">
      <div class="cal-head">
        <button class="icon-btn" data-action="year" data-id="${id}" data-delta="-1" ${year <= startYear ? 'disabled' : ''} aria-label="Anno precedente">${ICON.left}</button>
        <h2>${year}</h2>
        <button class="icon-btn" data-action="year" data-id="${id}" data-delta="1" ${year >= L.parts(today).y ? 'disabled' : ''} aria-label="Anno successivo">${ICON.right}</button>
      </div>
      <div class="heatmap" id="heatmap" role="img" aria-label="Mappa dell'anno ${year}: ${yearDone} giorni fatti, ${yearMissed} non fatti">${heat}</div>
      <div class="legend" aria-hidden="true">
        <span><i class="heat heat-done"></i>fatto</span><span><i class="heat heat-missed"></i>non fatto</span>
        <span><i class="heat heat-paused"></i>pausa</span><span><i class="heat heat-empty"></i>vuoto</span>
      </div>
    </section>
    <section class="card">
      <h2>${g.kind === 'weekly' ? 'Giorni fatti per giorno della settimana' : 'Successo per giorno della settimana'}</h2>
      <div class="bars">${bars}</div>
      ${weakest ? `<p class="muted small">Il giorno più difficile è ${weakest.weekday === 7 ? 'la' : 'il'} ${WEEKDAY_NAMES[weakest.weekday - 1]}: ${weakest.percent}% su ${weakest.registered} giorni registrati.</p>` : ''}
    </section>`;

  // Mostra le settimane più recenti: la colonna di oggi (o la fine dell'anno) a destra.
  const heatmap = document.getElementById('heatmap');
  const columnsEls = heatmap.querySelectorAll('.heat-col');
  const lastIndex = year === L.parts(today).y ? columns.findIndex(col => col.includes(today)) : columns.length - 1;
  const lastCol = columnsEls[Math.max(0, lastIndex)];
  if (lastCol) heatmap.scrollLeft = lastCol.offsetLeft - heatmap.offsetLeft + lastCol.offsetWidth + 48 - heatmap.clientWidth;
}

// ================================================================ Archiviati, riordino, backup

function renderArchived() {
  const goals = S.archivedGoals();
  app.innerHTML = `${navBar({ back: '#/', backLabel: 'Oggi', title: 'Archiviati' })}
    ${goals.length ? `<ul class="card list" role="list">${goals.map(g => `<li class="row">
        <a class="row-info" href="#/goal/${g.id}">${chip(g)}<span class="row-title">${esc(g.name)}</span></a>
        <button class="text-btn" data-action="unarchive" data-id="${g.id}">Ripristina</button></li>`).join('')}</ul>`
      : '<section class="empty"><h2>Nessun obiettivo archiviato</h2><p>Puoi archiviare un obiettivo da «Modifica» nel suo dettaglio.</p></section>'}`;
}

function renderReorder() {
  const goals = S.activeGoals();
  app.innerHTML = `${navBar({ back: '#/', backLabel: 'Oggi', title: 'Riordina' })}
    <ul class="card list" role="list">${goals.map((g, i) => `<li class="row">
      ${chip(g, 's')}<span class="row-title grow">${esc(g.name)}</span>
      <button class="icon-btn" data-action="move" data-index="${i}" data-delta="-1" ${i === 0 ? 'disabled' : ''} aria-label="Sposta su ${esc(g.name)}">${ICON.up}</button>
      <button class="icon-btn" data-action="move" data-index="${i}" data-delta="1" ${i === goals.length - 1 ? 'disabled' : ''} aria-label="Sposta giù ${esc(g.name)}">${ICON.down}</button>
    </li>`).join('')}</ul>
    <p class="footnote">L'ordine vale per la schermata «Oggi».</p>`;
}

function renderBackup(message = '') {
  app.innerHTML = `${navBar({ back: '#/', backLabel: 'Oggi', title: 'Backup' })}
    <div class="card list"><button class="list-btn" data-action="export">Esporta backup</button></div>
    <p class="footnote">Crea un file con tutti gli obiettivi, i giorni registrati e le note. Salvalo in File o in iCloud Drive: i dati di Brain esistono solo su questo iPhone. Il file è compatibile anche con l'app iOS di Brain.</p>
    <div class="card list"><label class="list-btn" for="import-file">Ripristina da un backup</label>
      <input id="import-file" type="file" accept=".json,application/json" hidden></div>
    <p class="footnote">Sostituisce tutti i dati attuali con quelli del file scelto.</p>
    ${message ? `<p class="card" role="status">${esc(message)}</p>` : ''}`;
  document.getElementById('import-file').addEventListener('change', importBackup);
}

async function exportBackup() {
  const text = S.exportBackup();
  const { y, m, d } = L.parts(S.today());
  const name = `Brain-backup-${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}.json`;
  const file = new File([text], name, { type: 'application/json' });
  try {
    if (navigator.canShare && navigator.canShare({ files: [file] })) {
      await navigator.share({ files: [file], title: name });
      return renderBackup('Backup pronto: se l\'hai salvato in File o iCloud Drive è al sicuro.');
    }
  } catch (error) {
    if (error.name === 'AbortError') return;
  }
  const url = URL.createObjectURL(file);
  const a = Object.assign(document.createElement('a'), { href: url, download: name });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10000);
  renderBackup('Backup scaricato.');
}

async function importBackup(event) {
  const file = event.target.files?.[0];
  if (!file) return;
  try {
    const goals = L.decodeBackup(await file.text());
    const entries = goals.reduce((n, g) => n + Object.keys(g.entries).length, 0);
    if (!confirm(`Il backup contiene ${goals.length} obiettivi e ${entries} giorni registrati. Sostituire tutti i dati attuali?`)) return renderBackup();
    S.replaceAll(goals);
    renderBackup(`Ripristinati ${goals.length} obiettivi.`);
  } catch (error) {
    renderBackup(error instanceof L.BackupError ? error.message : 'Impossibile leggere il file.');
  }
}

// ================================================================ Azioni

document.addEventListener('click', event => {
  const target = event.target.closest('[data-action]');
  if (!target || target.disabled) return;
  const { action, id } = target.dataset;
  const day = Number(target.dataset.day);
  const today = S.today();

  switch (action) {
    case 'toggle': {
      const g = S.goal(id);
      const status = Number(target.dataset.status);
      const previous = S.toggle(id, today, status);
      const now = S.entry(g, today)?.status;
      const message = `${g.emoji} ${now === L.DONE ? 'Segnato come fatto' : now === L.MISSED ? 'Segnato come non fatto' : 'Tornato a non registrato'}`;
      S.requestPersistence();
      showUndo(message, () => S.restore(id, today, previous));
      break;
    }
    case 'undo':
      ui.undo?.();
      hideUndo();
      announce('Modifica annullata');
      break;
    case 'value': openValueSheet(id); break;
    case 'save-value': {
      const value = L.parseNumber(document.getElementById('value-input').value);
      if (value == null) { document.getElementById('value-input').focus(); return; }
      S.setValue(id, today, value);
      closeSheet();
      break;
    }
    case 'clear-value': S.setValue(id, today, null); closeSheet(); break;
    case 'menu': openMenu(); break;
    case 'close-sheet': closeSheet(); break;
    case 'month': {
      ui.months[id] = L.addMonths(ui.months[id], Number(target.dataset.delta));
      rerender();
      break;
    }
    case 'year': ui.years[id] = (ui.years[id] || L.parts(today).y) + Number(target.dataset.delta); rerender(); break;
    case 'day': openDaySheet(id, day); break;
    case 'day-status': {
      const raw = target.dataset.status;
      saveNote(id, day);
      S.setStatus(id, day, raw === 'none' ? null : Number(raw));
      ui.onSheetClose = null;
      closeSheet();
      break;
    }
    case 'day-value': {
      const value = L.parseNumber(document.getElementById('day-value').value);
      if (value == null) { document.getElementById('day-value').focus(); return; }
      saveNote(id, day);
      S.setValue(id, day, value);
      ui.onSheetClose = null;
      closeSheet();
      break;
    }
    case 'kind': ui.draft.kind = target.dataset.kind; renderEditor(idFromHash()); break;
    case 'comparison': ui.draft.comparison = target.dataset.comparison; renderEditor(idFromHash()); break;
    case 'weekly': ui.draft.weeklyTarget = Math.min(7, Math.max(1, ui.draft.weeklyTarget + Number(target.dataset.delta))); renderEditor(idFromHash()); break;
    case 'emoji': ui.draft.emoji = target.dataset.emoji; renderEditor(idFromHash()); break;
    case 'color': ui.draft.color = target.dataset.color; renderEditor(idFromHash()); break;
    case 'save-goal': saveGoal(); break;
    case 'archive': {
      const g = S.goal(id);
      S.setArchived(id, !g.archivedAt);
      ui.draft = null;
      location.hash = g.archivedAt ? '#/' : `#/goal/${id}`;
      break;
    }
    case 'delete': {
      const g = S.goal(id);
      if (confirm(`Eliminare «${g.name}»? Verranno cancellati anche tutti i giorni registrati e le note. L'operazione non si può annullare.`)) {
        S.deleteGoal(id);
        ui.draft = null;
        location.hash = '#/';
      }
      break;
    }
    case 'unarchive': S.setArchived(id, false); break;
    case 'move': {
      const ids = S.activeGoals().map(g => g.id);
      const i = Number(target.dataset.index), j = i + Number(target.dataset.delta);
      [ids[i], ids[j]] = [ids[j], ids[i]];
      S.reorder(ids);
      break;
    }
    case 'export': exportBackup(); break;
  }
});

function idFromHash() {
  const parts = location.hash.replace(/^#\/?/, '').split('/');
  return parts[0] === 'edit' ? parts[1] : null;
}

// ================================================================ Avvio

S.subscribe(rerender);
window.addEventListener('hashchange', () => {
  if (!location.hash.startsWith('#/new') && !location.hash.startsWith('#/edit')) ui.draft = null;
  route();
  window.scrollTo(0, 0);
});
// Un nuovo giorno quando riapri l'app.
document.addEventListener('visibilitychange', () => { if (!document.hidden) rerender(); });
route();

if ('serviceWorker' in navigator && location.protocol === 'https:') {
  navigator.serviceWorker.register('./sw.js').catch(() => {});
}
