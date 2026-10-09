/* vps tell you — mobile UI redesign interactive demo (static, no backend). */
(() => {
'use strict';

// ---------- icons ----------
const P = {
  server: '<rect x="3" y="4" width="18" height="7" rx="2"/><rect x="3" y="13" width="18" height="7" rx="2"/><path d="M7 7.5h.01M7 16.5h.01"/>',
  chart: '<path d="M4 20V10M10 20V4M16 20v-7M21 20H3"/>',
  wrench: '<path d="M14.7 6.3a4 4 0 0 0-5.3 5.3L3.5 17.5a1.8 1.8 0 0 0 2.5 2.5l5.9-5.9a4 4 0 0 0 5.3-5.3l-2.5 2.5-2.3-.4-.4-2.3z"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  chevR: '<path d="m9 6 6 6-6 6"/>',
  chevL: '<path d="m15 5-7 7 7 7"/>',
  arrowL: '<path d="M20 12H5M11 5l-7 7 7 7"/>',
  chevD: '<path d="m6 9 6 6 6-6"/>',
  star: '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1 6.2L12 17.3 6.5 20.2l1-6.2L3 9.6l6.2-.9z"/>',
  archive: '<rect x="3" y="4" width="18" height="5" rx="1.5"/><path d="M5 9v9a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9M10 13h4"/>',
  terminal: '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="m7 9 3 3-3 3M13 15h4"/>',
  pulse: '<path d="M3 12h4l2-5 4 10 2-5h6"/>',
  card: '<rect x="3" y="5" width="18" height="14" rx="2.5"/><path d="M3 10h18M7 15h3"/>',
  power: '<path d="M12 3v8M6.3 6.3a8 8 0 1 0 11.4 0"/>',
  copy: '<rect x="8" y="8" width="12" height="12" rx="2.5"/><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2"/>',
  building: '<path d="M4 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16M16 9h2a2 2 0 0 1 2 2v10M3 21h18M8 7h4M8 11h4M8 15h4"/>',
  cloud: '<path d="M7 18a4.5 4.5 0 0 1-.5-9 6 6 0 0 1 11.6 1.5A3.8 3.8 0 0 1 17.5 18z"/>',
  link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
  bell: '<path d="M6 16V11a6 6 0 1 1 12 0v5l1.5 2h-15z"/><path d="M10 21h4"/>',
  calc: '<rect x="5" y="3" width="14" height="18" rx="2.5"/><path d="M8 7h8M8 12h.01M12 12h.01M16 12h.01M8 16h.01M12 16h.01M16 16h.01"/>',
  code: '<path d="m8 8-4 4 4 4M16 8l4 4-4 4M14 5l-4 14"/>',
  shield: '<path d="M12 3 5 6v6c0 4.5 3 7.5 7 9 4-1.5 7-4.5 7-9V6z"/><path d="m9 12 2 2 4-4"/>',
  folder: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
  moon: '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z"/>',
  currency: '<path d="M17 7a6 6 0 1 0 0 10M4 10h10M4 14h10"/>',
  download: '<path d="M12 4v11M7 10l5 5 5-5M5 20h14"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5h.01"/>',
  sliders: '<path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/>',
  more: '<circle cx="5" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="19" cy="12" r="1.3"/>',
  moreV: '<circle cx="12" cy="5" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="12" cy="19" r="1.3"/>',
  check: '<path d="m5 12.5 4.5 4.5L19 7.5"/>',
  x: '<path d="M6 6l12 12M18 6 6 18"/>',
  sort: '<path d="M7 4v16M3 16l4 4 4-4M17 20V4M13 8l4-4 4 4"/>',
  alert: '<path d="M12 4 2.5 20h19z"/><path d="M12 10v4.5M12 17.5h.01"/>',
  key: '<circle cx="8" cy="15" r="4"/><path d="m11 12 9-9M16 7l3 3M14 9l2 2"/>',
  cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><path d="M9 2v4M15 2v4M9 18v4M15 18v4M2 9h4M2 15h4M18 9h4M18 15h4"/>',
  mem: '<rect x="2" y="7" width="20" height="10" rx="1.5"/><path d="M6 11v2M10 11v2M14 11v2M18 11v2"/>',
  disk: '<ellipse cx="12" cy="6" rx="8" ry="3"/><path d="M4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"/>',
  traffic: '<path d="M7 20V4M3 8l4-4 4 4M17 4v16M13 16l4 4 4-4"/>',
  tag: '<path d="M3 12V4h8l10 10-8 8z"/><circle cx="7.5" cy="8.5" r="1.3"/>',
  receipt: '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2z"/><path d="M9 8h6M9 12h6"/>',
  pencil: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2.5"/><path d="M3 10h18M8 3v4M16 3v4"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  hand: '<path d="M8 13V5.5a1.5 1.5 0 0 1 3 0V12M11 11V4.5a1.5 1.5 0 0 1 3 0V11M14 11V6a1.5 1.5 0 0 1 3 0v8a7 7 0 0 1-7 7 6 6 0 0 1-5-3l-2.5-4.5a1.5 1.5 0 0 1 2.6-1.5L8 14"/>',
  refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>',
};
const ic = (n, extra = '') => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" ${extra}>${P[n]}</svg>`;
const icFill = n => `<svg viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1" stroke-linejoin="round">${P[n]}</svg>`;
const chev = `<svg class="chev" viewBox="0 0 8 14" width="8" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="m1 1 6 6-6 6"/></svg>`;

// ---------- data ----------
const TODAY = '2026-10-09';
const FX = { USD: 7.12, EUR: 7.80, CNY: 1 };
const SYM = { USD: '$', EUR: '€', CNY: '¥' };
const PROVIDERS = [
  { name: '搬瓦工', mark: 'BWG', color: '#F07A2A' },
  { name: 'DigitalOcean', mark: 'DO', color: '#1F7AE0' },
  { name: 'GreenCloud', mark: 'GC', color: '#22A06B' },
  { name: 'RackNerd', mark: 'RN', color: '#6D5AE6' },
  { name: 'Hetzner', mark: 'HZ', color: '#D6334A' },
];
const seed = () => [
  { id: 'hk', name: 'HK-01', purpose: '生产主站', provider: '搬瓦工', region: '香港', host: '192.0.2.18', billing: 'prepaid', amount: 49.99, cur: 'USD', cycle: 12, start: '2025-10-16', due: '2026-10-16', days: 7, fav: true, group: '生产', os: 'Debian 12', spec: 'CN2 GIA', hw: { cpu: '2 核', ram: '2 GiB', disk: '40 GiB', traffic: '1 TiB/月', ip: '192.0.2.18', hostname: 'hk01.example' }, panel: null, ssh: 'root@192.0.2.18:22', trust: true, notes: '主站 Nginx + 证书自动续期。', updated: 2 },
  { id: 'us', name: 'US-01', purpose: 'API 服务', provider: 'DigitalOcean', region: '美国', host: '198.51.100.10', billing: 'metered', amount: 12.00, cur: 'USD', cycle: 1, fav: true, group: '生产', os: 'Ubuntu 24.04', spec: '', hw: { cpu: '1 核', ram: '1 GiB', disk: '25 GiB', traffic: '1 TiB/月', ip: '198.51.100.10', hostname: null }, panel: null, ssh: 'deploy@198.51.100.10:22', trust: true, notes: '', updated: 1 },
  { id: 'jp', name: 'JP-01', purpose: '开发环境', provider: 'GreenCloud', region: '日本', host: '203.0.113.22', billing: 'prepaid', amount: 45.00, cur: 'USD', cycle: 12, start: '2025-10-07', due: '2026-10-07', days: -2, fav: false, group: '开发', os: 'Debian 12', spec: '', hw: { cpu: '2 核', ram: '4 GiB', disk: '60 GiB', traffic: '2 TiB/月', ip: '203.0.113.22', hostname: null }, panel: null, ssh: null, trust: false, notes: '', updated: 4 },
  { id: 'de', name: 'DE-01', purpose: '备份存储', provider: 'Hetzner', region: '德国', host: '198.51.100.77', billing: 'prepaid', amount: 4.51, cur: 'EUR', cycle: 1, start: '2026-10-01', due: '2026-11-01', days: 23, fav: false, group: '未分组', os: 'Debian 12', spec: 'BX11', hw: { cpu: '2 核', ram: '4 GiB', disk: '40 GiB', traffic: '20 TiB/月', ip: null, hostname: null }, panel: null, ssh: null, trust: false, notes: '', updated: 6 },
  { id: 'la', name: 'LA-02', purpose: '代理节点', provider: 'RackNerd', region: '洛杉矶', host: '203.0.113.90', billing: 'prepaid', amount: 10.99, cur: 'USD', cycle: 12, start: '2026-02-06', due: '2027-02-06', days: 120, fav: false, group: '未分组', os: 'AlmaLinux 9', spec: '', hw: { cpu: null, ram: '1 GiB', disk: '20 GiB', traffic: '1 TiB/月', ip: '203.0.113.90', hostname: 'la02.example' }, panel: 'RackNerd ctrl · 只读', ssh: 'root@203.0.113.90:22', trust: true, notes: '', updated: 3 },
  { id: 'sg', name: 'SG-01', purpose: '备用', provider: null, region: '新加坡', host: 'example.invalid', billing: 'unknown', amount: null, cur: 'USD', cycle: 1, fav: false, group: '未分组', os: '', spec: '', hw: { cpu: null, ram: null, disk: null, traffic: null, ip: null, hostname: null }, panel: null, ssh: null, trust: false, notes: '', updated: 5 },
];

const S = {
  platform: 'ios', theme: 'light', data: 'demo', tab: 'servers',
  servers: seed(), filter: 'all', group: null, due: 'all', sort: 'due', query: '',
  costSplit: 'provider', costMonth: 0, hwOpen: true, billingKind: 'prepaid',
};
const byId = id => S.servers.find(s => s.id === id);
const prov = name => PROVIDERS.find(p => p.name === name);
const cyc = m => ({ 1: '月', 3: '季', 6: '半年', 12: '年', 24: '两年', 36: '三年' }[m] || `${m} 个月`);
const money = (v, cur, d = 2) => `${SYM[cur]}${v.toLocaleString('en-US', { minimumFractionDigits: d, maximumFractionDigits: d })}`;
const cny = (v, cur) => v * FX[cur];
const isPending = s => s.billing === 'prepaid' && s.days != null && s.days <= 30;

function dueInfo(s) {
  if (s.billing === 'metered') return { text: '按量计费', cls: '' };
  if (s.billing === 'unknown') return { text: '费用未填', cls: '' };
  if (s.days < 0) return { text: `已过期 ${-s.days} 天`, short: `过期 ${-s.days} 天`, cls: 'red' };
  if (s.days === 0) return { text: '今天到期', short: '今天', cls: 'red' };
  if (s.days <= 30) return { text: `${s.days} 天后到期`, short: `${s.days} 天`, cls: 'amber' };
  return { text: `${s.days} 天后到期`, short: `${s.days} 天`, cls: '' };
}
function avatar(s, lg = false) {
  const p = prov(s.provider);
  const star = s.fav ? `<span class="star">${icFill('star')}</span>` : '';
  return `<div class="avatar${lg ? ' lg' : ''}" style="background:${p ? p.color : '#8E96A6'}">${p ? p.mark : '?'}${lg ? '' : star}</div>`;
}

// ---------- platform helpers ----------
// 统一设计：两端都使用同一套（iOS 基准）组件；平台切换只影响机身、状态栏和系统字体。
const ios = () => true;
const $ = sel => document.querySelector(sel);
const device = $('#device'), pagesEl = $('#pages'), overlay = $('#overlay'), tabbar = $('#tabbar'), fab = $('#fab');

// ---------- toast ----------
let toastTimer;
function toast(msg, action, fn) {
  const t = $('#toast');
  t.innerHTML = `<span>${msg}</span>${action ? `<button>${action}</button>` : ''}`;
  if (action) t.querySelector('button').onclick = () => { fn && fn(); t.classList.remove('on'); };
  t.classList.add('on');
  t.style.bottom = (stack.length > 1 && top().modal) ? '40px' : (ios() ? '96px' : '104px');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('on'), action ? 4500 : 2200);
}

// ---------- overlays ----------
let overlayClose = null, overlaySeq = 0;
function openOverlay(html, { cls = '', blur = false, clear = false, onClose } = {}) {
  overlaySeq++;
  overlay.innerHTML = `<div class="scrim${clear ? ' clear' : ''}"></div>${html}`;
  overlay.className = 'overlay' + (blur ? ' blur' : '') + (cls ? ' ' + cls : '');
  overlay.querySelector('.scrim').onclick = closeOverlay;
  overlayClose = onClose || null;
  requestAnimationFrame(() => requestAnimationFrame(() => overlay.classList.add('on')));
  return overlay;
}
function closeOverlay() {
  overlay.classList.remove('on');
  const cb = overlayClose, seq = overlaySeq; overlayClose = null;
  // A newer overlay opened during the exit animation must survive this cleanup.
  setTimeout(() => { if (seq === overlaySeq) overlay.innerHTML = ''; }, 320);
  cb && cb();
}
function sheet(title, body, { close = true } = {}) {
  return openOverlay(`<div class="sheet"><div class="grabber"></div>
    ${title ? `<div class="sheet-h"><b>${title}</b></div>` : ''}
    ${close && title ? `<button class="sheet-close" data-close>${ic('x')}</button>` : ''}
    <div class="sheet-body">${body}</div></div>`);
}
overlay.addEventListener('click', e => { if (e.target.closest('[data-close]')) closeOverlay(); });

/** Centered alert on both platforms. buttons: [{t, cls, fn}] */
function alertBox(title, msg, buttons) {
  const btns = ios() ? buttons : buttons;
  const o = openOverlay(`<div class="alert"><div class="a-body"><h3>${title}</h3><p>${msg}</p></div>
    <div class="a-btns">${btns.map((b, i) => `<button data-i="${i}" class="${b.cls || ''}">${b.t}</button>`).join('')}</div></div>`);
  o.querySelectorAll('.a-btns button').forEach(b => b.onclick = () => { closeOverlay(); const f = btns[+b.dataset.i].fn; f && setTimeout(f, 180); });
}
/** Action sheet on both platforms. items: [{t, icon, cls, fn}] */
function actionMenu(title, items) {
  if (ios()) {
    const o = openOverlay(`<div class="actionsheet"><div class="as-group">${title ? `<div class="as-title">${title}</div>` : ''}
      ${items.map((it, i) => `<button data-i="${i}" class="${it.cls || ''}">${it.t}</button>`).join('')}</div>
      <button class="cancel" data-close>取消</button></div>`);
    o.querySelectorAll('.as-group button').forEach(b => b.onclick = () => { closeOverlay(); const f = items[+b.dataset.i].fn; f && setTimeout(f, 200); });
  } else {
    const o = sheet('', `${title ? `<div class="footnote" style="padding:0 24px 8px">${title}</div>` : ''}
      ${items.map((it, i) => `<div class="row${it.cls === 'red' ? ' destructive' : ''}" data-i="${i}" style="background:transparent;padding:0 24px;gap:16px">
        <span style="width:24px;color:${it.cls === 'red' ? 'var(--red)' : 'var(--text2)'}">${ic(it.icon || 'chevR', 'width="22" height="22"')}</span>
        <div class="label"><div class="t">${it.t}</div></div></div>`).join('')}`);
    o.querySelectorAll('.row[data-i]').forEach(b => b.onclick = () => { closeOverlay(); const f = items[+b.dataset.i].fn; f && setTimeout(f, 200); });
  }
}
/** Single choice picker (group/currency/cycle…) */
function picker(title, options, current, onPick, footnote = '') {
  const o = sheet(title, `<div class="group">${options.map((op, i) => `<div class="row" data-i="${i}">
      <div class="label"><div class="t">${op.t || op}</div>${op.s ? `<div class="s">${op.s}</div>` : ''}</div>
      ${(op.v ?? op) === current ? ic('check', 'class="check"') : ''}</div>`).join('')}</div>
      ${footnote ? `<div class="footnote">${footnote}</div>` : ''}`);
  o.querySelectorAll('.row[data-i]').forEach(r => r.onclick = () => { const op = options[+r.dataset.i]; closeOverlay(); onPick(op.v ?? op); });
}

// ---------- navigation ----------
const stack = []; // {key, args, el, modal}
const top = () => stack[stack.length - 1];
const PAGES = {};

function buildPage(entry) {
  const def = PAGES[entry.key](...(entry.args || []));
  entry.def = def;
  const el = entry.el || document.createElement('div');
  el.className = 'page' + (stack.indexOf(entry) > 0 ? ' pushed' : '') + (entry.modal ? ' modal-page' : '');
  const backLabel = def.backLabel || (stack[stack.indexOf(entry) - 1]?.def?.title) || '返回';
  let left = '';
  if (entry.modal) left = ios() ? `<button class="nbtn" data-act="pop">取消</button>` : `<button class="nbtn" data-act="pop">${ic('x')}</button>`;
  else if (stack.indexOf(entry) > 0) left = `<button class="nbtn back" data-act="pop">${ios() ? ic('chevL') : ic('arrowL')}<span class="back-label">${backLabel}</span></button>`;
  const right = def.actions ? def.actions() : '';
  el.innerHTML = `<header class="navbar">
      <div class="nav-row">${left}<div class="nav-title">${def.navTitle || def.title}</div><div class="nav-actions">${right}</div></div>
    </header>
    <div class="scroll">${def.large ? `<div class="large-title">${def.title}${def.sub ? `<div class="large-sub">${def.sub}</div>` : ''}</div>` : ''}${def.body()}</div>`;
  const scroll = el.querySelector('.scroll'), nav = el.querySelector('.navbar');
  // Large-title and hero pages reveal the inline title only after the big heading scrolls away.
  const threshold = def.large ? 34 : (def.heroThreshold ?? 2);
  if (!def.large && def.heroThreshold == null) nav.classList.add('always');
  const onScroll = () => nav.classList.toggle('scrolled', scroll.scrollTop > threshold);
  scroll.addEventListener('scroll', onScroll); onScroll();
  el.querySelectorAll('[data-act="pop"]').forEach(b => b.onclick = () => pop());
  def.mount && def.mount(el);
  entry.el = el;
  return el;
}
function rerender(entry = top(), keepScroll = true) {
  const sc = entry.el?.querySelector('.scroll')?.scrollTop || 0;
  buildPage(entry);
  if (keepScroll) entry.el.querySelector('.scroll').scrollTop = sc;
  chrome();
}
function rerenderAll() { stack.forEach(e => rerender(e)); }

function push(key, args = [], { modal = false } = {}) {
  closeOverlay();
  const prev = top();
  const entry = { key, args, modal };
  stack.push(entry);
  const el = buildPage(entry);
  pagesEl.appendChild(el);
  el.classList.add(modal ? 'anim-modal-in' : 'anim-push-in');
  if (modal) { if (ios()) prev.el.classList.add('under-modal'); }
  else { prev.el.classList.add('anim-under-out'); }
  setTimeout(() => { el.classList.remove('anim-modal-in', 'anim-push-in'); if (!modal) { prev.el.classList.remove('anim-under-out'); prev.el.style.visibility = 'hidden'; } }, 420);
  chrome(); notes();
}
function pop(after) {
  if (stack.length < 2) return;
  const entry = stack.pop(), prev = top();
  prev.el.style.visibility = '';
  if (entry.modal) prev.el.classList.remove('under-modal');
  else prev.el.classList.add('anim-under-in');
  entry.el.classList.add(entry.modal ? 'anim-modal-out' : 'anim-push-out');
  setTimeout(() => { entry.el.remove(); prev.el.classList.remove('anim-under-in'); }, 330);
  rerender(prev);
  notes();
  after && setTimeout(after, 250);
}
function resetTo(tab) {
  S.tab = tab;
  pagesEl.innerHTML = ''; stack.length = 0;
  const entry = { key: tab, args: [] };
  stack.push(entry);
  const el = buildPage(entry);
  pagesEl.appendChild(el);
  el.classList.add('anim-fade');
  chrome(); notes();
}
function chrome() {
  const t = top();
  tabbar.classList.toggle('hidden', !!(t && t.modal) || !!document.querySelector('.term'));
  const tabs = [['servers', '服务器', 'server'], ['costs', '费用', 'chart'], ['tools', '工具', 'wrench'], ['settings', '设置', 'gear']];
  tabbar.innerHTML = tabs.map(([k, l, i]) => `<button class="tab${S.tab === k ? ' on' : ''}" data-tab="${k}"><span class="ind">${ic(i)}</span>${l}</button>`).join('');
  tabbar.querySelectorAll('.tab').forEach(b => b.onclick = () => {
    if (S.tab === b.dataset.tab && stack.length > 1) { while (stack.length > 1) stack.pop().el.remove(); top().el.style.visibility = ''; rerender(top()); return; }
    if (S.tab === b.dataset.tab) { top().el.querySelector('.scroll').scrollTo({ top: 0, behavior: 'smooth' }); return; }
    resetTo(b.dataset.tab);
  });
  fab.classList.remove('show');
  $('#statusbar').classList.toggle('on-dark', !!document.querySelector('.term') || S.theme === 'dark');
}

// ---------- pages: servers ----------
function visibleServers() {
  let list = S.servers.slice();
  if (S.filter === 'fav') list = list.filter(s => s.fav);
  if (S.filter === 'pending') list = list.filter(isPending);
  if (S.group) list = list.filter(s => s.group === S.group);
  if (S.due === 'overdue') list = list.filter(s => s.billing === 'prepaid' && s.days < 0);
  if (S.due === 'next30') list = list.filter(s => s.billing === 'prepaid' && s.days >= 0 && s.days <= 30);
  if (S.due === 'unknown') list = list.filter(s => s.billing === 'unknown');
  const q = S.query.trim().toLowerCase();
  if (q) list = list.filter(s => [s.name, s.host, s.provider, s.purpose, s.region].join(' ').toLowerCase().includes(q));
  const dueKey = s => s.billing === 'prepaid' ? s.days : 9999;
  const sorters = { due: (a, b) => dueKey(a) - dueKey(b), fav: (a, b) => (b.fav - a.fav) || dueKey(a) - dueKey(b), name: (a, b) => a.name.localeCompare(b.name), updated: (a, b) => a.updated - b.updated };
  return list.sort(sorters[S.sort]);
}
const SORTS = [{ v: 'due', t: '到期时间' }, { v: 'fav', t: '常用优先' }, { v: 'name', t: '名称' }, { v: 'updated', t: '最近更新' }];

function serverRow(s) {
  const d = dueInfo(s), p = prov(s.provider);
  const price = s.billing === 'unknown' ? `<span class="muted">—</span>` : `${money(s.amount, s.cur)}<small>/${cyc(s.cycle)}${s.billing === 'metered' ? '估' : ''}</small>`;
  return `<div class="srow-wrap" data-id="${s.id}">
    <div class="srow-actions">
      <button class="ssh" data-sw="ssh">${ic('terminal')}SSH</button>
      <button class="fav" data-sw="fav">${s.fav ? ic('star') : icFill('star')}${s.fav ? '取消常用' : '常用'}</button>
      <button class="arch" data-sw="arch">${ic('archive')}归档</button>
    </div>
    <div class="srow">
      ${avatar(s)}
      <div class="main">
        <div class="l1"><span class="name">${s.name}</span><span class="purpose">${s.purpose}</span></div>
        <div class="l2">${s.panel ? ic('cloud') : ''}${[p ? p.name : '未指定提供商', s.region].filter(Boolean).join(' · ')}</div>
      </div>
      <div class="side"><span class="price">${price}</span><span class="pill ${d.cls}">${d.cls ? '<span class="dot"></span>' : ''}${d.short || d.text}</span></div>
    </div></div>`;
}

PAGES.servers = () => ({
  title: '服务器', large: true,
  sub: S.data === 'empty' ? '本地台账 · 尚无记录' : `${S.servers.length} 台 · 仅保存在本机`,
  actions: () => S.data === 'empty' ? '' :
    `<button class="nbtn" data-a="providers" title="提供商">${ic('building')}</button>` +
    (ios() ? `<button class="nbtn" data-a="add" title="添加">${ic('plus')}</button>` : `<button class="nbtn" data-a="filter">${ic('sliders')}</button>`),
  body() {
    if (S.data === 'empty') return `
      <div class="empty"><div class="art">${ic('server')}</div>
        <h2>记下你的第一台 VPS</h2>
        <p>到期、费用、硬件和 SSH 都在这一处。<br>只保存在本机，不需要账号。</p>
        <button class="btn primary" data-a="manual">${ic('pencil')}手动添加</button>
        <button class="btn tonal" data-a="add">${ic('cloud')}从面板账户导入</button>
        <button class="btn plain" data-a="demo">先看看演示数据</button>
      </div>
      <div class="footnote" style="text-align:center;padding-top:24px">演示数据使用文档保留地址，不会联网，可随时归档。</div>`;
    const all = S.servers, vis = visibleServers();
    const pending = all.filter(isPending), overdue = pending.filter(s => s.days < 0);
    const groups = [...new Set(all.map(s => s.group))];
    const filtered = S.group || S.due !== 'all';
    const chips = [
      ['all', '全部', all.length], ['fav', '常用', all.filter(s => s.fav).length], ['pending', '待续费', pending.length],
    ].map(([k, t, n]) => `<button class="chip${S.filter === k && !S.group ? ' on' : ''}" data-filter="${k}">${t}<span class="cnt">${n}</span></button>`).join('')
      + groups.map(g => `<button class="chip${S.group === g ? ' on' : ''}" data-groupchip="${g}">${g}</button>`).join('')
      + `<button class="chip dotted" data-a="filter">${ic('sliders')}${filtered ? '筛选 ·' + ((S.group ? 1 : 0) + (S.due !== 'all' ? 1 : 0)) : '筛选'}</button>`;
    const showStats = S.filter === 'all' && !S.group && !S.query && S.due === 'all';
    const stats = showStats ? `<div class="stats">
        <button class="stat red" data-due="overdue"><div class="v">${overdue.length}</div><div class="k"><i style="background:var(--red)"></i>已过期</div></button>
        <button class="stat amber" data-due="next30"><div class="v">${pending.length - overdue.length}</div><div class="k"><i style="background:var(--amber-solid)"></i>30 天内到期</div></button>
        <button class="stat" data-tabgo="costs"><div class="v" style="font-size:20px;padding-top:3px">¥184</div><div class="k">月费用参考</div></button>
      </div>` : '';
    const sortT = SORTS.find(x => x.v === S.sort).t;
    const title = S.filter === 'fav' ? '常用服务器' : S.filter === 'pending' ? '待续费' : S.group ? S.group : '全部服务器';
    return `<div class="ptr" id="ptr"></div>
      <div class="search">${ic('search')}<input id="q" placeholder="名称、地址、提供商或地区" value="${S.query}">${S.query ? `<span data-a="clearq" style="cursor:pointer">${ic('x')}</span>` : ''}</div>
      <div class="chips">${chips}</div>
      ${stats}
      <div class="section-h"><b style="font-size:17px">${title}</b><button class="sort-btn" data-a="sort">${ic('sort')}${sortT}</button></div>
      ${vis.length ? `<div class="list-group">${vis.map(serverRow).join('')}</div>` :
        `<div class="card" style="text-align:center;padding:28px 16px"><div class="muted" style="margin-bottom:12px">没有符合条件的服务器</div><button class="btn tonal" data-a="reset" style="height:38px;font-size:14px">清除筛选</button></div>`}
      <div class="footnote" style="text-align:center">运行状态未检测 · ${ios() ? '左滑或长按' : '长按或左滑'}服务器查看快捷操作</div>`;
  },
  mount(el) {
    const scroll = el.querySelector('.scroll');
    el.querySelectorAll('[data-a]').forEach(b => b.onclick = () => ({
      add: () => App.openAddSheet(), manual: () => push('form', [null], { modal: true }), providers: () => push('providers'),
      demo: () => { S.data = 'demo'; S.servers = seed(); syncCtl(); rerender(); toast('已载入 6 条演示记录'); },
      filter: () => openFilterSheet(), sort: () => openSortMenu(b), clearq: () => { S.query = ''; rerender(); },
      reset: () => { Object.assign(S, { filter: 'all', group: null, due: 'all', query: '' }); rerender(); },
    }[b.dataset.a])());
    el.querySelectorAll('[data-filter]').forEach(b => b.onclick = () => { S.filter = b.dataset.filter; S.group = null; rerender(); });
    el.querySelectorAll('[data-groupchip]').forEach(b => b.onclick = () => { S.group = S.group === b.dataset.groupchip ? null : b.dataset.groupchip; S.filter = 'all'; rerender(); });
    el.querySelectorAll('[data-due]').forEach(b => b.onclick = () => { S.filter = 'pending'; rerender(); });
    el.querySelectorAll('[data-tabgo]').forEach(b => b.onclick = () => resetTo(b.dataset.tabgo));
    const q = el.querySelector('#q');
    if (q) q.oninput = () => { S.query = q.value; const pos = q.selectionStart; rerender(); const nq = top().el.querySelector('#q'); nq.focus(); nq.setSelectionRange(pos, pos); };
    el.querySelectorAll('.srow-wrap').forEach(w => bindRow(w));
    if (S.data !== 'empty') bindPullToRefresh(scroll, el.querySelector('#ptr'));
  },
});

let openRow = null;
function bindRow(wrap) {
  const row = wrap.querySelector('.srow'), id = wrap.dataset.id;
  let sx, sy, dx = 0, drag = false, moved = false, lp, base = 0, down = false;
  const W = 228;
  const set = x => { row.style.transform = x ? `translateX(${x}px)` : ''; };
  row.addEventListener('pointerdown', e => {
    down = true; sx = e.clientX; sy = e.clientY; dx = 0; drag = false; moved = false;
    base = openRow === wrap ? -W : 0;
    if (openRow && openRow !== wrap) { openRow.querySelector('.srow').style.transform = ''; openRow = null; moved = true; }
    row.classList.add('pressed');
    lp = setTimeout(() => { if (!moved) { moved = true; down = false; row.classList.remove('pressed'); contextMenu(id, wrap); } }, 520);
  });
  row.addEventListener('pointermove', e => {
    if (!down) return;
    const mx = e.clientX - sx, my = e.clientY - sy;
    if (!drag && Math.abs(mx) > 8 && Math.abs(mx) > Math.abs(my)) { drag = true; moved = true; clearTimeout(lp); row.classList.add('dragging'); row.setPointerCapture(e.pointerId); }
    if (!drag && Math.abs(my) > 8) { moved = true; clearTimeout(lp); }
    if (drag) { dx = Math.min(0, Math.max(-W - 30, base + mx)); set(dx); }
  });
  const end = () => {
    clearTimeout(lp); row.classList.remove('pressed');
    if (!down) return; down = false;
    if (drag) {
      row.classList.remove('dragging');
      if (dx < -70) { set(-W); openRow = wrap; } else { set(0); if (openRow === wrap) openRow = null; }
      return;
    }
    if (!moved) { if (openRow === wrap) { set(0); openRow = null; } else push('detail', [id]); }
  };
  row.addEventListener('pointerup', end);
  row.addEventListener('pointercancel', () => { clearTimeout(lp); down = false; row.classList.remove('pressed', 'dragging'); });
  row.addEventListener('contextmenu', e => e.preventDefault());
  wrap.querySelectorAll('[data-sw]').forEach(b => b.onclick = () => {
    set(0); openRow = null;
    const s = byId(id);
    if (b.dataset.sw === 'fav') { s.fav = !s.fav; setTimeout(() => { rerender(); toast(s.fav ? `已将 ${s.name} 设为常用` : `已取消常用`); }, 200); }
    if (b.dataset.sw === 'arch') confirmArchive(s);
    if (b.dataset.sw === 'ssh') openSshSheet(s);
  });
}

function contextMenu(id, wrap) {
  const s = byId(id);
  const items = [
    { t: '复制主机地址', icon: 'copy', fn: () => toast(`已复制 ${s.host}`) },
    { t: 'SSH 连接', icon: 'terminal', fn: () => openSshSheet(s) },
    ...(s.billing === 'prepaid' ? [{ t: '记录已付款', icon: 'card', fn: () => openPaySheet(s) }] : []),
    { t: s.fav ? '取消常用' : '设为常用', icon: 'star', fn: () => { s.fav = !s.fav; rerender(); } },
    { t: '归档', icon: 'archive', cls: 'red', fn: () => confirmArchive(s) },
  ];
  if (!ios()) return actionMenu(`${s.name} · ${s.host}`, items);
  const r = wrap.getBoundingClientRect(), sr = $('#screen').getBoundingClientRect();
  const topPx = Math.min(Math.max(r.top - sr.top, 70), 820 - 70 - 44 * items.length - 40);
  const o = openOverlay(`<div class="ctx" style="top:${topPx}px"><div class="preview">${wrap.querySelector('.srow').outerHTML}</div>
    <div class="menu">${items.map((it, i) => `<button data-i="${i}" class="${(it.cls || '') + (i === items.length - 1 ? ' sep' : '')}">${it.t}${ic(it.icon)}</button>`).join('')}</div></div>`, { blur: true });
  o.querySelector('.preview .srow').style.transform = '';
  o.querySelectorAll('.menu button').forEach(b => b.onclick = () => { closeOverlay(); setTimeout(items[+b.dataset.i].fn, 200); });
}

function bindPullToRefresh(scroll, ptr) {
  let sy = null, d = 0;
  scroll.addEventListener('pointerdown', e => { if (scroll.scrollTop <= 0 && !e.target.closest('input')) { sy = e.clientY; d = 0; } });
  scroll.addEventListener('pointermove', e => {
    if (sy == null) return;
    d = e.clientY - sy;
    if (d > 0) { ptr.style.height = Math.min(d * .5, 64) + 'px'; ptr.innerHTML = d * .5 > 48 ? '<div class="spinner" style="animation:none"></div>' : '<div class="spinner" style="animation:none;opacity:.5"></div>'; }
  });
  const end = () => {
    if (sy == null) return; sy = null;
    if (d * .5 > 48) {
      ptr.innerHTML = '<div class="spinner"></div>';
      setTimeout(() => { ptr.style.transition = 'height .25s'; ptr.style.height = '0'; toast('已重新读取本地台账'); setTimeout(() => ptr.style.transition = '', 300); }, 900);
    } else { ptr.style.height = '0'; }
  };
  scroll.addEventListener('pointerup', end); scroll.addEventListener('pointerleave', end);
}

function openSortMenu(btn) {
  if (!ios()) return picker('排序', SORTS, S.sort, v => { S.sort = v; rerender(); });
  const r = btn.getBoundingClientRect(), sr = $('#screen').getBoundingClientRect();
  const o = openOverlay(`<div class="popmenu" style="top:${r.bottom - sr.top + 6}px">${SORTS.map(x => `<button data-v="${x.v}"><span class="ck">${S.sort === x.v ? ic('check', 'width="16"') : ''}</span>${x.t}</button>`).join('')}</div>`, { clear: true });
  o.querySelectorAll('.popmenu button').forEach(b => b.onclick = () => { S.sort = b.dataset.v; closeOverlay(); rerender(); });
}

function openFilterSheet() {
  let g = S.group, d = S.due, so = S.sort;
  const groups = [...new Set(S.servers.map(s => s.group))];
  const render = () => {
    const count = (() => { const save = [S.group, S.due]; S.group = g; S.due = d; const n = visibleServers().length; [S.group, S.due] = save; return n; })();
    return `<div class="section-h small" style="padding-top:4px">分组</div>
      <div class="chips" style="flex-wrap:wrap;padding-top:0"><button class="chip${!g ? ' on' : ''}" data-g="">全部分组</button>${groups.map(x => `<button class="chip${g === x ? ' on' : ''}" data-g="${x}">${x}</button>`).join('')}</div>
      <div class="section-h small">到期状态</div>
      <div class="chips" style="flex-wrap:wrap;padding-top:0">${[['all', '全部'], ['overdue', '已过期'], ['next30', '30 天内'], ['unknown', '费用未填']].map(([k, t]) => `<button class="chip${d === k ? ' on' : ''}" data-d="${k}">${t}</button>`).join('')}</div>
      <div class="section-h small">排序</div>
      <div class="group">${SORTS.map(x => `<div class="row" data-s="${x.v}"><div class="label"><div class="t">${x.t}</div></div>${so === x.v ? ic('check', 'class="check"') : ''}</div>`).join('')}</div>
      <div style="display:flex;gap:10px;padding:18px 16px 0"><button class="btn tonal" data-reset style="flex:1">重置</button><button class="btn primary" data-apply style="flex:2">显示 ${count} 台</button></div>`;
  };
  const o = sheet('筛选与排序', `<div id="fs">${render()}</div>`);
  const bind = () => {
    const box = o.querySelector('#fs');
    box.querySelectorAll('[data-g]').forEach(b => b.onclick = () => { g = b.dataset.g || null; box.innerHTML = render(); bind(); });
    box.querySelectorAll('[data-d]').forEach(b => b.onclick = () => { d = b.dataset.d; box.innerHTML = render(); bind(); });
    box.querySelectorAll('[data-s]').forEach(b => b.onclick = () => { so = b.dataset.s; box.innerHTML = render(); bind(); });
    box.querySelector('[data-reset]').onclick = () => { g = null; d = 'all'; so = 'due'; box.innerHTML = render(); bind(); };
    box.querySelector('[data-apply]').onclick = () => { S.group = g; S.due = d; S.sort = so; S.filter = 'all'; closeOverlay(); rerender(); };
  };
  bind();
}

function confirmArchive(s, fromDetail) {
  const msg = `仅在本地列表中隐藏，不会取消服务、停止扣费或删除云资源。可在「设置 › 已归档记录」中恢复。`;
  const doIt = () => {
    const idx = S.servers.indexOf(s); S.servers.splice(idx, 1);
    const undo = () => { S.servers.splice(idx, 0, s); rerenderAll(); toast('已撤销归档'); };
    if (fromDetail) pop(() => toast(`已归档 ${s.name}`, '撤销', undo)); else { rerender(); toast(`已归档 ${s.name}`, '撤销', undo); }
  };
  if (ios()) {
    const o = openOverlay(`<div class="actionsheet"><div class="as-group"><div class="as-title"><b style="color:var(--text)">归档 ${s.name}？</b><br>${msg}</div>
      <button class="red" data-ok>归档</button></div><button class="cancel" data-close>取消</button></div>`);
    o.querySelector('[data-ok]').onclick = () => { closeOverlay(); setTimeout(doIt, 200); };
  } else alertBox(`归档 ${s.name}？`, msg, [{ t: '取消' }, { t: '归档', cls: 'red', fn: doIt }]);
}

// ---------- add sheet ----------
let addProvider = null;
function openAddSheet() {
  const p = addProvider;
  const o = sheet('添加服务器', `
    <div class="section-h small" style="padding-top:0">归属提供商</div>
    <div class="group"><div class="row has-icon" data-pickprov>${p ? avatarMini(p) : `<div class="icon-sq" style="background:#8E96A6">${ic('building')}</div>`}
      <div class="label"><div class="t">${p || '未指定提供商'}</div><div class="s">${p ? '已确认的业务归属' : '仅可手动添加，稍后可在详情中指定'}</div></div>${chev}</div></div>
    <div class="section-h small">添加方式</div>
    <div class="method" data-m="manual"><div class="icon-sq" style="background:var(--primary)">${ic('pencil')}</div><div><div class="t">手动填写</div><div class="s">名称必填；硬件和费用不清楚可以先留空</div></div></div>
    <div class="method${p ? '' : ' disabled'}" data-m="auto"><div class="icon-sq" style="background:#6D5AE6">${ic('cloud')}</div><div><div class="t">从面板读取</div><div class="s">${p ? 'SolusVM 1 / 2、RackNerd ctrl，只读导入，逐台确认' : '请先选择提供商'}</div></div></div>
    <div class="footnote" style="padding-bottom:6px">面板密钥只存入设备安全存储，读取不会修改远端。</div>`);
  o.querySelector('[data-pickprov]').onclick = () => picker('选择提供商', [{ v: null, t: '未指定提供商', s: '仅手动添加' }, ...PROVIDERS.map(x => ({ v: x.name, t: x.name }))], addProvider, v => { addProvider = v; setTimeout(openAddSheet, 250); });
  o.querySelector('[data-m="manual"]').onclick = () => { closeOverlay(); setTimeout(() => push('form', [null], { modal: true }), 200); };
  o.querySelector('[data-m="auto"]').onclick = () => { if (!p) return toast('先选择提供商，再选择适配器实例'); closeOverlay(); setTimeout(() => toast('进入：选择适配器实例 → 读取预览 → 逐台导入'), 200); };
}
const avatarMini = name => { const p = prov(name); return `<div class="icon-sq" style="background:${p.color};font-size:11px;font-weight:700">${p.mark}</div>`; };

// ---------- detail ----------
PAGES.detail = id => {
  const s = byId(id) || S.servers[0];
  const d = dueInfo(s), p = prov(s.provider);
  return {
    title: s.name, backLabel: '服务器', heroThreshold: 70,
    actions: () => `<button class="nbtn" data-a="fav">${s.fav ? `<span style="color:var(--amber-solid);display:flex">${icFill('star')}</span>` : ic('star')}</button>`
      + (ios() ? `<button class="nbtn" data-a="edit">编辑</button>` : `<button class="nbtn" data-a="edit">${ic('pencil')}</button>`)
      + `<button class="nbtn" data-a="more">${ios() ? ic('more') : ic('moreV')}</button>`,
    body() {
      const elapsed = s.billing === 'prepaid' ? Math.max(0, Math.min(1, 1 - s.days / (s.cycle * 30.4))) : 0;
      const remain = s.billing === 'prepaid' ? Math.max(0, s.days) / (s.cycle * 30.4) * s.amount : 0;
      const hwCell = (k, icon, v) => `<div><div class="k">${ic(icon)}${k}</div><div class="v${v ? '' : ' unk'}">${v || '未填写'}</div></div>`;
      const billing = s.billing === 'prepaid' ? `
        <div class="card bill">
          <div class="top"><div><div class="k">续费金额 · 每${cyc(s.cycle)}</div><div class="amt">${money(s.amount, s.cur)}<small>${s.cur}</small></div></div><span class="pill ${d.cls}">${d.cls ? '<span class="dot"></span>' : ''}${d.text}</span></div>
          <div class="progress"><i style="width:${(elapsed * 100).toFixed(0)}%;${d.cls === 'red' ? 'background:var(--red)' : d.cls ? '' : 'background:var(--primary)'}"></i></div>
          <div class="prog-l"><span>${s.start}</span><span>到期 ${s.due}</span></div>
          <div class="kv3"><div>剩余价值<b>${money(remain, s.cur)}</b></div><div>折合<b>¥${cny(remain, s.cur).toFixed(2)}</b></div><div>日均<b>${money(s.amount / (s.cycle * 30.4), s.cur, 3)}</b></div></div>
          <div class="card-actions"><button class="btn tonal" data-a="payments">${ic('receipt')}付款记录 · 1</button><button class="btn tonal" data-a="calc">${ic('calc')}价值试算</button></div>
        </div>` : s.billing === 'metered' ? `
        <div class="card bill"><div class="top"><div><div class="k">按量计费 · 月估算</div><div class="amt">${money(s.amount, s.cur)}<small>${s.cur}</small></div></div><span class="pill">按量计费</span></div>
          <div class="footnote" style="padding:8px 0 0">按量服务没有到期日，不计算剩余价值。</div></div>` : `
        <div class="card" style="display:flex;gap:12px;align-items:center"><div class="icon-sq" style="background:var(--amber-solid)">${ic('alert')}</div><div style="flex:1"><b>费用资料未填写</b><div class="muted" style="font-size:13px">补充后才会计入费用合计与到期提醒</div></div><button class="btn tonal" data-a="edit" style="height:34px;font-size:13px;padding:0 12px">补填</button></div>`;
      return `
        <div class="hero">${avatar(s, true)}<div style="min-width:0"><h1>${s.name}</h1><div class="sub">${[s.purpose, p ? p.name : '未指定提供商', s.region].filter(Boolean).join(' · ')}</div></div></div>
        <div class="hostbar"><span class="k">地址</span><span class="mono">${s.host}</span><button data-a="copy">${ic('copy')}复制</button></div>
        <div class="qa">
          <button data-a="ssh" class="${s.ssh ? '' : 'off'}"><span class="ic">${ic('terminal')}</span>SSH 连接</button>
          <button data-a="tcp"><span class="ic">${ic('pulse')}</span>TCP 测试</button>
          <button data-a="pay" class="${s.billing === 'prepaid' ? '' : 'off'}"><span class="ic">${ic('card')}</span>记录付款</button>
          <button data-a="power" class="${s.ssh ? 'danger' : 'off'}"><span class="ic">${ic('power')}</span>电源</button>
        </div>
        <div class="section-h small">费用与到期</div>
        ${billing}
        ${s.billing === 'prepaid' ? `<div class="group" style="margin-top:10px"><div class="row has-icon" data-a="reminder"><div class="icon-sq" style="background:#EF4444">${ic('bell')}</div><div class="label"><div class="t">到期提醒</div></div><span class="value">提前 7/3/1 天 · 09:00</span>${chev}</div></div>` : ''}
        <div class="section-h small"><span>硬件信息</span><button class="link" data-a="edit">编辑</button></div>
        <div class="hw">${hwCell('vCPU', 'cpu', s.hw.cpu)}${hwCell('内存', 'mem', s.hw.ram)}${hwCell('磁盘', 'disk', s.hw.disk)}${hwCell('流量', 'traffic', s.hw.traffic)}${hwCell('IP', 'globe', s.hw.ip)}${hwCell('主机名', 'tag', s.hw.hostname)}</div>
        <div class="section-h small">基本信息</div>
        <div class="group">
          ${[['操作系统', s.os], ['分组', s.group], ['用途', s.purpose], ['地区', s.region], ['规格补充', s.spec]].map(([k, v]) => `<div class="row" style="cursor:default"><div class="label"><div class="t">${k}</div></div><span class="value" style="${v ? '' : 'color:var(--text3)'}">${v || '未填写'}</span></div>`).join('')}
        </div>
        <div class="section-h small">提供商与面板</div>
        <div class="group">
          <div class="row has-icon" data-a="provider">${p ? avatarMini(p.name) : `<div class="icon-sq" style="background:#8E96A6">${ic('building')}</div>`}<div class="label"><div class="t">${p ? p.name : '未指定提供商'}</div><div class="s">${p ? '查看提供商与适配器实例' : '指定后可关联只读面板'}</div></div>${chev}</div>
          <div class="row has-icon" data-a="panel"><div class="icon-sq" style="background:#6D5AE6">${ic('link')}</div><div class="label"><div class="t">面板关联</div></div><span class="value">${s.panel || '未关联'}</span>${chev}</div>
        </div>
        <div class="footnote">面板刷新只更新 API 观测，不会覆盖你手动填写的资料。</div>
        <div class="section-h small">连接</div>
        <div class="group">
          <div class="row has-icon" data-a="sshcfg"><div class="icon-sq" style="background:#334155">${ic('terminal')}</div><div class="label"><div class="t">SSH 配置</div>${s.ssh ? `<div class="s" style="font-family:ui-monospace,Menlo,monospace">${s.ssh}</div>` : ''}</div><span class="value">${s.ssh ? '' : '未配置'}</span>${chev}</div>
          <div class="row has-icon" data-a="trust"><div class="icon-sq" style="background:#0EA5E9">${ic('shield')}</div><div class="label"><div class="t">主机公钥</div></div><span class="value">${s.trust ? '已核验' : '首次连接时核验'}</span>${chev}</div>
        </div>
        ${s.notes ? `<div class="section-h small">备注</div><div class="card" style="font-size:15px;line-height:1.55">${s.notes}</div>` : ''}
        <div class="meta-foot">本地保存于 2026-10-09 20:16<br>服务器 ID 5a509ebd…c6f8</div>`;
    },
    mount(el) {
      el.querySelectorAll('[data-a]').forEach(b => b.onclick = () => {
        const a = b.dataset.a;
        if (a === 'fav') { s.fav = !s.fav; rerender(); toast(s.fav ? '已设为常用' : '已取消常用'); }
        if (a === 'edit') push('form', [s.id], { modal: true });
        if (a === 'more') actionMenu(`${s.name} · ${s.host}`, [
          { t: '复制主机地址', icon: 'copy', fn: () => toast(`已复制 ${s.host}`) },
          { t: '用于剩余价值试算', icon: 'calc', fn: () => toast('打开计算器（引用本服务器）') },
          { t: '更改提供商', icon: 'building', fn: () => toast('更改提供商：有关联时先确认解除') },
          { t: '归档', icon: 'archive', cls: 'red', fn: () => confirmArchive(s, true) },
        ]);
        if (a === 'copy') toast(`已复制 ${s.host}`);
        if (a === 'ssh') s.ssh ? openSshSheet(s) : needSsh(s);
        if (a === 'tcp') openTcpSheet(s);
        if (a === 'pay') s.billing === 'prepaid' ? openPaySheet(s) : toast('只有预付服务器可以记录续费付款');
        if (a === 'power') s.ssh ? openPower(s) : needSsh(s);
        if (a === 'reminder') push('reminder', [s.id]);
        if (a === 'calc') toast('打开计算器（引用本服务器已知服务期）');
        if (a === 'payments') toast('付款记录页（沿用现有逻辑，列表样式统一）');
        if (a === 'provider') push('providers');
        if (a === 'panel') toast('面板关联页：选择同提供商、授权范围内的设备');
        if (a === 'sshcfg') toast('SSH 配置页：地址 / 端口 / 用户名 / 凭据');
        if (a === 'trust') toast('主机信任：查看完整公钥与指纹，可重新核实');
      });
    },
  };
};
function needSsh(s) {
  alertBox('尚未配置 SSH', `为 ${s.name} 设置地址、端口、用户名和登录凭据后，才能连接或执行电源操作。`, [{ t: '以后再说' }, { t: '去配置', cls: 'bold', fn: () => toast('打开 SSH 配置页') }]);
}

// ---------- quick sheets ----------
function openSshSheet(s) {
  if (!s.ssh) return needSsh(s);
  const o = sheet(`连接 ${s.name}`, `
    <div class="group">
      <div class="row" style="cursor:default"><div class="label"><div class="t">目标</div></div><span class="value mono">${s.ssh}</span></div>
      <div class="row" data-cred><div class="label"><div class="t">凭据</div></div><span class="value">hk-key · Ed25519</span>${chev}</div>
      <div class="row" style="cursor:default"><div class="label"><div class="t">主机公钥</div></div>${s.trust ? '<span class="pill green"><span class="dot"></span>已核验</span>' : '<span class="pill amber"><span class="dot"></span>首次连接需核验</span>'}</div>
    </div>
    <div class="footnote">私钥口令未保存时，会在连接前单独询问；不会自动重连。</div>
    <div style="padding:16px"><button class="btn primary block" data-go>${ic('terminal')}连接</button></div>`);
  o.querySelector('[data-cred]').onclick = () => toast('选择凭据（密码 / 私钥）');
  o.querySelector('[data-go]').onclick = () => { closeOverlay(); setTimeout(() => s.trust ? openTerminal(s) : hostKeySheet(s), 250); };
}
function hostKeySheet(s) {
  const o = sheet('核验主机公钥', `
    <div class="footnote" style="padding:0 32px 10px">首次连接 ${s.host}:22。请与服务商控制台或 <code>ssh-keygen -lf</code> 的结果逐字比对。</div>
    <div class="fingerprint">ED25519 · SHA256:<br><b>q4Lw9mO1Vj0yZp7cN2sXkR8tH3uE6fGdA5bW1iYcK0M</b></div>
    <div style="padding:16px;display:flex;flex-direction:column;gap:8px">
      <button class="btn primary block" data-ok>信任并连接</button><button class="btn plain block" data-close>拒绝</button></div>`);
  o.querySelector('[data-ok]').onclick = () => { s.trust = true; closeOverlay(); setTimeout(() => openTerminal(s), 250); };
}
function openTerminal(s) {
  const t = document.createElement('div');
  t.className = 'term anim-modal-in';
  t.innerHTML = `<div class="term-top"><button class="nbtn" data-x>${ic('x')}</button><div class="tt"><b>${s.name}</b><span>${s.ssh}</span></div><span class="pill"><span class="dot"></span>已连接</span><button class="nbtn">${ic('code')}</button></div>
    <div class="term-body">Linux ${s.name.toLowerCase()} 6.1.0-26-amd64 x86_64
Last login: Thu Oct  8 21:04:11 2026

<span class="g">root@${s.name.toLowerCase()}</span>:<span class="b">~</span># uptime
 21:16:02 up 38 days,  2:11,  1 user,  load average: 0.08, 0.05, 0.01
<span class="g">root@${s.name.toLowerCase()}</span>:<span class="b">~</span># <span class="cur"> </span></div>
    <div class="term-keys"><button>Esc</button><button>Tab</button><button>Ctrl</button><button>↑</button><button>↓</button><button>←</button><button>→</button><button>|</button><button>~</button><button class="acc">命令</button></div>
    <div class="term-kb">（系统键盘）</div>`;
  $('#screen').appendChild(t);
  chrome();
  t.querySelector('[data-x]').onclick = () => alertBox('断开连接？', '远端仍在运行的命令可能被中断；长任务建议使用 tmux / screen。', [{ t: '取消' }, { t: '断开', cls: 'red', fn: () => { t.classList.add('anim-modal-out'); setTimeout(() => { t.remove(); chrome(); }, 300); } }]);
}
function openTcpSheet(s) {
  const o = sheet('TCP 连接测试', `
    <div class="group"><div class="row" style="cursor:default"><div class="label"><div class="t">目标</div></div><span class="value mono">${s.host}:22</span></div>
    <div class="row" style="cursor:default" id="tcpres"><div class="label"><div class="t">结果</div></div><span class="value"><span class="spinner" style="width:16px;height:16px;margin:0;display:inline-block;vertical-align:middle"></span> 测试中…</span></div></div>
    <div class="footnote">从本机发起单次连接；端口可连通不代表服务健康。</div>
    <div style="padding:16px"><button class="btn tonal block" data-again>${ic('refresh')}再测一次</button></div>`);
  const run = () => { const r = o.querySelector('#tcpres .value'); r.innerHTML = '<span class="spinner" style="width:16px;height:16px;margin:0;display:inline-block;vertical-align:middle"></span> 测试中…'; setTimeout(() => r.innerHTML = '<span class="pill green"><span class="dot"></span>可连接 · 38 ms</span>', 900); };
  o.querySelector('[data-again]').onclick = run; run();
}
function openPaySheet(s) {
  let n = 1;
  const nextDue = k => { const [y, m, d] = s.due.split('-').map(Number); const t = new Date(y, m - 1 + s.cycle * k, d); return `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, '0')}-${String(t.getDate()).padStart(2, '0')}`; };
  const render = () => `
    <div class="group">
      <div class="row" style="cursor:default"><div class="label"><div class="t">续费周期数</div></div><div class="mini-seg">${[1, 2, 3].map(k => `<button class="${n === k ? 'on' : ''}" data-n="${k}">${k}</button>`).join('')}</div></div>
      <div class="row" style="cursor:default"><div class="label"><div class="t">金额</div></div><span class="value num" style="color:var(--text);font-weight:600">${money(s.amount * n, s.cur)}</span></div>
      <div class="row" style="cursor:default"><div class="label"><div class="t">新到期日</div></div><span class="value num">${s.due} → <b style="color:var(--text)">${nextDue(n)}</b></span></div>
    </div>
    <div class="footnote">只记账，不会向厂商付款；记录后 8 秒内可撤销。</div>
    <div style="padding:16px"><button class="btn primary block" data-ok>记录已付款</button></div>`;
  const o = sheet(`记录付款 · ${s.name}`, `<div id="pay">${render()}</div>`);
  const bind = () => {
    o.querySelectorAll('[data-n]').forEach(b => b.onclick = () => { n = +b.dataset.n; o.querySelector('#pay').innerHTML = render(); bind(); });
    o.querySelector('[data-ok]').onclick = () => {
      const old = { due: s.due, days: s.days, start: s.start };
      s.start = s.due; s.due = nextDue(n); s.days += Math.round(s.cycle * n * 30.4);
      closeOverlay(); rerenderAll();
      toast(`已记录 · 新到期日 ${s.due}`, '撤销', () => { Object.assign(s, old); rerenderAll(); });
    };
  };
  bind();
}
function openPower(s) {
  const go = (kind) => alertBox(`确认${kind} ${s.name}？`, `将连接 <b>${s.ssh}</b> 并执行 <code>sudo -n shutdown ${kind === '重启' ? '-r' : '-h'} now</code>。${kind === '关机' ? '关机后无法在应用内开机。' : ''}结果不确定时不会自动重试。`,
    [{ t: '取消' }, { t: kind, cls: 'red', fn: () => toast(`已派发${kind}命令，请稍后核实`) }]);
  actionMenu(`电源操作 · ${s.name}<br>${s.ssh}`, [{ t: '重启', icon: 'refresh', fn: () => go('重启') }, { t: '关机', icon: 'power', cls: 'red', fn: () => go('关机') }]);
}

// ---------- costs ----------
PAGES.costs = () => ({
  title: '费用', large: true,
  actions: () => `<button class="nbtn" data-a="fx">${ic('currency')}</button><button class="nbtn" data-a="info">${ic('info')}</button>`,
  body() {
    if (S.data === 'empty') return `<div class="empty"><div class="art">${ic('chart')}</div><h2>还没有费用数据</h2><p>添加服务器并填写续费金额后，这里会汇总月费用、即将续费和费用分布。</p><button class="btn tonal" data-a="calc">${ic('calc')}独立试算剩余价值</button></div>`;
    const prepaid = S.servers.filter(s => s.billing !== 'unknown');
    const monthly = prepaid.reduce((a, s) => a + cny(s.amount / s.cycle, s.cur), 0);
    const remain = S.servers.filter(s => s.billing === 'prepaid').reduce((a, s) => a + cny(Math.max(0, s.days) / (s.cycle * 30.4) * s.amount, s.cur), 0);
    const upcoming = S.servers.filter(s => s.billing === 'prepaid' && s.days <= 30).sort((a, b) => a.days - b.days);
    const up30 = upcoming.reduce((a, s) => a + cny(s.amount, s.cur), 0);
    const unknown = S.servers.filter(s => s.billing === 'unknown');
    const keyOf = s => S.costSplit === 'provider' ? (s.provider || '未指定') : s.group;
    const dist = {};
    prepaid.forEach(s => { const k = keyOf(s); dist[k] = dist[k] || { v: 0, n: 0 }; dist[k].v += cny(s.amount / s.cycle, s.cur); dist[k].n++; });
    const distArr = Object.entries(dist).sort((a, b) => b[1].v - a[1].v);
    const palette = ['#2F5BEA', '#F07A2A', '#22A06B', '#6D5AE6', '#D6334A', '#0EA5E9'];
    const colorFor = (k, i) => S.costSplit === 'provider' && prov(k) ? prov(k).color : palette[i % palette.length];
    const months = [{ m: '10月', v: 676.3, n: 2 }, { m: '11月', v: 35.2, n: 1 }, { m: '12月', v: 35.2, n: 1 }, { m: '1月', v: 35.2, n: 1 }, { m: '2月', v: 113.4, n: 2 }, { m: '3月', v: 35.2, n: 1 }];
    const max = Math.max(...months.map(x => x.v)), sel = months[S.costMonth];
    return `
      <div class="scope"><button class="chip" data-a="scope">${ic('folder')}全部分组${ic('chevD')}</button><button class="chip" data-a="cur">显示 CNY${ic('chevD')}</button></div>
      <div class="hero-card">
        <div class="k">月费用参考</div>
        <div class="big"><small>¥</small>${monthly.toFixed(2)}</div>
        <div class="cov">已折算 ${prepaid.length}/${S.servers.length} 台 · 汇率 USD 7.12 · EUR 7.80（10/01 手动）</div>
        <div class="split"><div data-a="remain">剩余价值<b>¥${remain.toFixed(2)}</b></div><div data-a="up">30 天内续费<b>¥${up30.toFixed(2)}</b></div></div>
      </div>
      ${unknown.length ? `<div class="warnrow" data-a="unknown">${ic('alert')}<span>${unknown.length} 台费用未填写（${unknown.map(s => s.name).join('、')}），未计入合计</span>${chev}</div>` : ''}
      <div class="section-h small"><span>即将续费</span><span>30 天内</span></div>
      <div class="group timeline">${upcoming.map(s => { const d = dueInfo(s); const [, mm, dd] = s.due.split('-'); return `
        <div class="row" data-open="${s.id}"><div class="datebox ${d.cls}"><div class="d">${dd}</div><div class="m">${+mm} 月</div></div>
          <div class="label"><div class="t">${s.name}</div><div class="s" style="color:${d.cls === 'red' ? 'var(--red)' : d.cls === 'amber' ? 'var(--amber)' : 'var(--text2)'}">${d.text}</div></div>
          <div class="amt-col"><b>${money(s.amount, s.cur)}</b><div>≈ ¥${cny(s.amount, s.cur).toFixed(2)}</div></div>${chev}</div>`; }).join('')}
      </div>
      <div class="section-h small">月费用分布</div>
      <div class="seg" style="margin-bottom:10px"><button class="${S.costSplit === 'provider' ? 'on' : ''}" data-split="provider">按提供商</button><button class="${S.costSplit === 'group' ? 'on' : ''}" data-split="group">按分组</button></div>
      <div class="card" style="padding-bottom:6px">
        <div class="stackbar">${distArr.map(([k, o], i) => `<i style="flex:${o.v};background:${colorFor(k, i)}"></i>`).join('')}</div>
        ${distArr.map(([k, o], i) => `<div style="display:flex;align-items:center;gap:10px;padding:10px 0;${i ? 'border-top:.5px solid var(--sep)' : ''}">
          <span class="legend-dot" style="background:${colorFor(k, i)}"></span><span style="flex:1">${k} <span class="muted" style="font-size:13px">· ${o.n} 台</span></span>
          <span class="num" style="font-weight:600">¥${o.v.toFixed(2)}</span><span class="muted num" style="width:40px;text-align:right;font-size:13px">${(o.v / monthly * 100).toFixed(0)}%</span></div>`).join('')}
      </div>
      <div class="section-h small"><span>未来六个月 · 预付续费</span></div>
      <div class="card">
        <div style="display:flex;justify-content:space-between;align-items:baseline"><div><div class="muted" style="font-size:13px">${sel.m} · ${sel.n} 笔</div><div style="font-size:24px;font-weight:700" class="num">¥${sel.v.toFixed(2)}</div></div><span class="pill">${S.costMonth === 0 ? '含已过期 1 笔' : '按当前续费价'}</span></div>
        <div class="bars" style="margin-top:12px">${months.map((x, i) => `<div class="b${i === S.costMonth ? ' on' : ''}" data-m="${i}"><em>${x.v >= 100 ? Math.round(x.v) : x.v.toFixed(0)}</em><i style="height:${Math.max(4, x.v / max * 90)}%"></i><span>${x.m}</span></div>`).join('')}</div>
      </div>
      <div class="section-h small">记录与工具</div>
      <div class="group">
        <div class="row has-icon" data-a="paid"><div class="icon-sq" style="background:#10B981">${ic('receipt')}</div><div class="label"><div class="t">近 30 天已记录实付</div></div><span class="value num">$49.99</span>${chev}</div>
        <div class="row has-icon" data-a="calc"><div class="icon-sq" style="background:var(--primary)">${ic('calc')}</div><div class="label"><div class="t">剩余价值计算器</div><div class="s">独立试算或引用服务器 · 可导出图片</div></div>${chev}</div>
      </div>
      <div class="footnote">金额按当前续费价和手动参考汇率折算，仅供参考，不代表厂商实际账单。</div>`;
  },
  mount(el) {
    el.querySelectorAll('[data-split]').forEach(b => b.onclick = () => { S.costSplit = b.dataset.split; rerender(); });
    el.querySelectorAll('[data-m]').forEach(b => b.onclick = () => { S.costMonth = +b.dataset.m; rerender(); });
    el.querySelectorAll('[data-open]').forEach(b => b.onclick = () => push('detail', [b.dataset.open]));
    el.querySelectorAll('[data-a]').forEach(b => b.onclick = () => ({
      fx: () => toast('币种与参考汇率'), info: () => sheet('费用口径说明', `<div class="card" style="font-size:14px;line-height:1.65">
          <p style="margin:0 0 10px"><b>月费用参考</b>：预付续费价按周期均摊到每月，加上按量服务的月估算；不等于本月实际支出。</p>
          <p style="margin:0 0 10px"><b>剩余价值</b>：按当前续费价折算已知服务期的剩余天数，不是退款承诺。</p>
          <p style="margin:0"><b>汇率</b>：使用带日期的手动参考汇率；缺少汇率的金额不计入合计，并显示覆盖率。</p></div><div style="height:8px"></div>`),
      scope: () => picker('统计范围', ['全部分组', '生产', '开发', '未分组'], '全部分组', () => {}),
      cur: () => picker('显示币种', ['CNY', 'USD', 'EUR'], 'CNY', () => {}, '只换算显示，不改变原币记录。'),
      unknown: () => push('detail', ['sg']), remain: () => toast('剩余价值明细'), up: () => el.querySelector('.timeline').scrollIntoView({ behavior: 'smooth', block: 'center' }),
      paid: () => toast('付款记录'), calc: () => toast('打开剩余价值计算器'),
    }[b.dataset.a] || (() => {}))());
  },
});

// ---------- tools ----------
PAGES.tools = () => ({
  title: '工具', large: true,
  body: () => `
    <div class="tools-grid">
      <button class="tool wide" data-t="calc"><div class="icon-sq" style="background:var(--primary)">${ic('calc')}</div><div style="flex:1"><div class="t">剩余价值计算器</div><div class="s">独立试算或引用服务器，可导出不含隐私的图片</div></div>${chev}</button>
      <button class="tool" data-t="ssh"><div class="icon-sq" style="background:#334155">${ic('terminal')}</div><div class="t">SSH 快速连接</div><div class="s">选择已配置的服务器</div></button>
      <button class="tool" data-t="tcp"><div class="icon-sq" style="background:#10B981">${ic('pulse')}</div><div class="t">TCP 连接测试</div><div class="s">单目标端口探测</div></button>
      <button class="tool" data-t="snip"><div class="icon-sq" style="background:#7C4DDB">${ic('code')}</div><div class="t">命令片段</div><div class="s">常用命令，插入草稿后发送</div></button>
      <button class="tool" data-t="power"><div class="icon-sq" style="background:#EF4444">${ic('power')}</div><div class="t">电源控制</div><div class="s">经 SSH 重启或关机</div></button>
    </div>
    <div class="footnote">电源操作需逐台核对目标并二次确认，结果不确定时不会自动重试。</div>`,
  mount(el) {
    el.querySelectorAll('[data-t]').forEach(b => b.onclick = () => {
      const t = b.dataset.t;
      const ready = S.servers.filter(s => s.ssh);
      if (t === 'ssh' || t === 'power') picker(t === 'ssh' ? '选择服务器' : '电源控制 · 选择服务器', ready.map(s => ({ v: s.id, t: s.name, s: s.ssh })), null, id => setTimeout(() => t === 'ssh' ? openSshSheet(byId(id)) : openPower(byId(id)), 250), '只列出已配置 SSH 的服务器。');
      if (t === 'tcp') openTcpSheet(S.servers[0]);
      if (t === 'calc') toast('打开剩余价值计算器');
      if (t === 'snip') toast('命令片段列表');
    });
  },
});

// ---------- settings ----------
const prefs = { appearance: '跟随系统', lang: '简体中文' };
PAGES.settings = () => ({
  title: '设置', large: true,
  body: () => {
    const r = (k, icon, color, t, v, s) => `<div class="row has-icon" data-s="${k}"><div class="icon-sq" style="background:${color}">${ic(icon)}</div><div class="label"><div class="t">${t}</div>${s ? `<div class="s">${s}</div>` : ''}</div><span class="value">${v}</span>${chev}</div>`;
    return `
    <div class="group"><div class="profile"><div class="app-icon">${ic('server')}</div><div><div style="font-size:19px;font-weight:700">vps tell you</div><div class="muted" style="font-size:13px">本地优先的 VPS 台账 · 0.1.0 开发测试版</div></div></div></div>
    <div class="section-h small">台账</div>
    <div class="group">${r('groups', 'folder', '#F59E0B', '分组管理', '3')}${r('archived', 'archive', '#8B5CF6', '已归档记录', '0')}${r('providers', 'building', '#2F5BEA', '提供商与适配器', '5')}</div>
    <div class="section-h small">安全</div>
    <div class="group">${r('security', 'shield', '#10B981', '密钥与安全', '2 个凭据')}${r('hosts', 'key', '#0EA5E9', '已信任主机', '3')}</div>
    <div class="section-h small">偏好</div>
    <div class="group">${r('fx', 'currency', '#14B8A6', '币种与参考汇率', 'CNY')}${r('notify', 'bell', '#EF4444', '到期通知', '已允许')}${r('appearance', 'moon', '#6366F1', '外观', prefs.appearance)}${r('lang', 'globe', '#3B82F6', '语言', prefs.lang)}</div>
    <div class="section-h small">数据</div>
    <div class="group">${r('backup', 'download', '#64748B', '台账备份与恢复', '', '未加密 JSON · 不含凭据与主机信任')}</div>
    <div class="footnote">数据只保存在本机，没有账号、遥测或云同步。归档记录不会取消服务或停止扣费。</div>`;
  },
  mount(el) {
    el.querySelectorAll('[data-s]').forEach(b => b.onclick = () => {
      const k = b.dataset.s;
      if (k === 'appearance') return picker('外观', ['跟随系统', '浅色', '深色'], prefs.appearance, v => { prefs.appearance = v; if (v !== '跟随系统') setTheme(v === '深色' ? 'dark' : 'light'); else rerender(); });
      if (k === 'lang') return picker('语言', ['简体中文', 'English', '跟随系统'], prefs.lang, v => { prefs.lang = v; rerender(); }, '切换语言不会丢失草稿或断开连接。');
      if (k === 'providers') return push('providers');
      if (k === 'notify') return alertBox('到期通知', '系统通知已允许。可在每台服务器的「到期提醒」中设置提前天数与时间。', [{ t: '好', cls: 'bold' }]);
      toast(b.querySelector('.t').textContent);
    });
  },
});

// ---------- providers ----------
PAGES.providers = () => ({
  title: '提供商', backLabel: '返回',
  actions: () => ios() ? `<button class="nbtn" data-a="add">${ic('plus')}</button>` : `<button class="nbtn" data-a="add">${ic('plus')}</button>`,
  body: () => `<div style="height:8px"></div>
    <div class="group">${PROVIDERS.map(p => { const n = S.servers.filter(s => s.provider === p.name).length; const inst = p.name === 'RackNerd' ? 1 : 0;
      return `<div class="row has-icon" data-p="${p.name}">${avatarMini(p.name)}<div class="label"><div class="t">${p.name}</div><div class="s">${n} 台服务器 · ${inst ? inst + ' 个适配器实例' : '无适配器'}</div></div>${chev}</div>`; }).join('')}</div>
    <div class="footnote">提供商是服务器的业务归属；适配器实例保存一份独立的只读授权。</div>
    <div class="section-h small">未指定</div>
    <div class="group"><div class="row has-icon"><div class="icon-sq" style="background:#8E96A6">${ic('building')}</div><div class="label"><div class="t">未指定提供商</div><div class="s">1 台服务器</div></div>${chev}</div></div>`,
  mount(el) {
    el.querySelector('[data-a="add"]').onclick = () => toast('新增提供商');
    el.querySelectorAll('[data-p]').forEach(b => b.onclick = () => toast(`${b.dataset.p}：实例与名下服务器`));
  },
});

// ---------- reminder ----------
const rem = { on: true, days: [7, 3, 1], time: '09:00', plan: 'keep' };
PAGES.reminder = id => {
  const s = byId(id);
  return {
    title: '到期提醒', backLabel: s.name,
    actions: () => `<button class="nbtn bold${ios() ? '' : ' text'}" data-a="save">保存</button>`,
    body: () => `<div style="height:8px"></div>
      <div class="group"><div class="row" style="cursor:default"><div class="label"><div class="t">启用提醒</div></div><button class="switch${rem.on ? ' on' : ''}" data-a="toggle"></button></div></div>
      <div class="footnote">${s.name} 将于 ${s.due} 到期。</div>
      <div class="${rem.on ? '' : 'row disabled'}" style="${rem.on ? '' : 'display:block;background:none;pointer-events:none'}">
      <div class="section-h small">提前提醒</div>
      <div class="group"><div class="daychips">${[30, 14, 7, 3, 1, 0].map(d => `<button class="chip${rem.days.includes(d) ? ' on' : ''}" data-d="${d}">${d ? d + ' 天' : '当天'}</button>`).join('')}</div>
        <div class="row" data-a="time"><div class="label"><div class="t">提醒时间</div></div><span class="value num">${rem.time}</span>${chev}</div></div>
      <div class="section-h small">到期后的打算</div>
      <div class="group">${[['keep', '继续使用', '到期前提醒续费'], ['undecided', '待决定', '提醒你做出决定'], ['drop', '到期不再使用', '仍提醒核对并取消自动续费']].map(([k, t, d]) => `<div class="row" data-p="${k}"><div class="label"><div class="t">${t}</div><div class="s">${d}</div></div>${rem.plan === k ? ic('check', 'class="check"') : ''}</div>`).join('')}</div>
      <div class="footnote">将在 ${rem.days.slice().sort((a, b) => b - a).map(d => { const t = new Date(2026, 9, 16 - d); return `${t.getMonth() + 1}/${t.getDate()}`; }).join('、') || '—'} ${rem.time} 提醒（设备时区）。通知不包含名称、IP 或金额。</div>
      </div>`,
    mount(el) {
      el.querySelectorAll('[data-d]').forEach(b => b.onclick = () => { const d = +b.dataset.d; rem.days = rem.days.includes(d) ? rem.days.filter(x => x !== d) : [...rem.days, d]; rerender(); });
      el.querySelectorAll('[data-p]').forEach(b => b.onclick = () => { rem.plan = b.dataset.p; rerender(); });
      el.querySelector('[data-a="toggle"]').onclick = () => { rem.on = !rem.on; rerender(); };
      const tm = el.querySelector('[data-a="time"]'); if (tm) tm.onclick = () => picker('提醒时间', ['08:00', '09:00', '12:00', '20:00', '21:30'], rem.time, v => { rem.time = v; rerender(); }, '实际应用中为系统时间选择器。');
      el.querySelector('[data-a="save"]').onclick = () => pop(() => toast('提醒规则已保存'));
    },
  };
};

// ---------- form (add / edit) ----------
PAGES.form = id => {
  const s = id ? byId(id) : null;
  const f = s ? { ...s, hw: { ...s.hw } } : { name: '', provider: addProvider, group: '未分组', cur: 'USD', cycle: 12, billing: 'prepaid' };
  const kind = () => S.billingKind;
  if (s) S.billingKind = s.billing;
  const val = v => v == null ? '' : String(v).replace(/[^\d.]/g, '');
  return {
    title: s ? `编辑 ${s.name}` : '手动添加',
    actions: () => `<button class="nbtn bold${ios() ? '' : ' text'}" data-a="save" ${s ? '' : 'disabled'}>保存</button>`,
    body: () => `<div style="height:6px"></div>
      <div class="section-h small" style="padding-top:6px">基本资料</div>
      <div class="group form-group">
        <div class="frow"><label>名称 <span class="req">*</span></label><input id="fname" placeholder="例如 HK-01" value="${f.name || ''}"></div>
        <div class="frow" data-pick="provider"><label>提供商</label><span class="pick"><b>${f.provider || '未指定'}</b>${chev}</span></div>
        <div class="frow"><label>主机地址</label><input placeholder="IP 或域名" value="${s ? s.host : ''}" style="font-family:ui-monospace,Menlo,monospace;font-size:15px"></div>
        <div class="frow" data-pick="group"><label>分组</label><span class="pick"><b>${f.group}</b>${chev}</span></div>
        <div class="frow"><label>用途</label><input placeholder="选填" value="${s ? s.purpose : ''}"></div>
        <div class="frow"><label>地区</label><input placeholder="选填" value="${s ? s.region : ''}"></div>
        <div class="frow"><label>操作系统</label><input placeholder="选填" value="${s ? s.os : ''}"></div>
      </div>
      <div class="footnote">只有名称必填，其余可稍后补充。只保存在本机，不会修改远端。</div>
      <div class="section-h small collapser${S.hwOpen ? ' open' : ''}" data-a="hw"><span>硬件信息 · 可留空</span>${ic('chevD')}</div>
      ${S.hwOpen ? `<div class="group form-group">
        <div class="frow segrow"><label>vCPU</label><span style="margin-left:auto"></span><div class="stepper"><button data-step="-1">−</button><span id="cpu">${val(f.hw?.cpu) || '—'}</span><button data-step="1">+</button></div></div>
        <div class="frow"><label>内存</label><input inputmode="decimal" placeholder="未知" value="${val(f.hw?.ram)}"><div class="mini-seg unit"><button>MiB</button><button class="on">GiB</button></div></div>
        <div class="frow"><label>磁盘</label><input inputmode="decimal" placeholder="未知" value="${val(f.hw?.disk)}"><div class="mini-seg unit"><button class="on">GiB</button><button>TiB</button></div></div>
        <div class="frow"><label>流量</label><input inputmode="decimal" placeholder="未知" value="${val(f.hw?.traffic)}"><div class="mini-seg unit"><button>GiB</button><button class="on">TiB</button></div></div>
        <div class="frow" data-pick="tcycle"><label>流量周期</label><span class="pick"><b>每月</b>${chev}</span></div>
        <div class="frow switchrow"><label>不限流量</label><span style="margin-left:auto"></span><button class="switch" data-sw></button></div>
        <div class="frow"><label>IP</label><input placeholder="未知" value="${f.hw?.ip || ''}"></div>
        <div class="frow"><label>主机名</label><input placeholder="未知" value="${f.hw?.hostname || ''}"></div>
      </div>
      <div class="footnote">容量按 1024 进制。面板刷新不会覆盖这里的手动资料。</div>` : ''}
      <div class="section-h small">费用</div>
      <div class="group form-group">
        <div class="frow segrow"><label>计费方式</label><span style="margin-left:auto"></span><div class="mini-seg">${[['prepaid', '预付'], ['metered', '按量'], ['unknown', '未知']].map(([k, t]) => `<button class="${kind() === k ? 'on' : ''}" data-bk="${k}">${t}</button>`).join('')}</div></div>
        ${kind() !== 'unknown' ? `
        <div class="frow"><label>${kind() === 'metered' ? '月估算' : '续费金额'}</label><input inputmode="decimal" placeholder="0.00" value="${s && s.amount != null ? s.amount.toFixed(2) : ''}"><span class="pick" data-pick="cur" style="margin-left:0"><b>${f.cur}</b>${ic('chevD', 'width="14"')}</span></div>` : ''}
        ${kind() === 'prepaid' ? `
        <div class="frow" data-pick="cycle"><label>续费周期</label><span class="pick"><b>${f.cycle} 个月</b>${chev}</span></div>
        <div class="frow" data-pick="date"><label>服务开始</label><span class="pick"><b class="num">${s ? s.start || '未知' : '未知'}</b>${ic('calendar', 'width="18"')}</span></div>
        <div class="frow" data-pick="date"><label>到期日</label><span class="pick"><b class="num">${s ? s.due || '未知' : '按周期自动计算'}</b>${ic('calendar', 'width="18"')}</span></div>` : ''}
      </div>
      ${kind() === 'unknown' ? '<div class="footnote">费用未知的服务器不会计入合计，也不会安排到期提醒。</div>' : ''}
      <div class="section-h small">备注</div>
      <div class="group form-group"><div class="frow"><textarea placeholder="选填">${s ? s.notes : ''}</textarea></div></div>
      <div class="footnote">请勿在备注中保存密码、私钥或令牌；登录凭据请在「密钥与安全」中管理。</div>`,
    mount(el) {
      const save = el.querySelector('[data-a="save"]'), name = el.querySelector('#fname');
      name.oninput = () => { f.name = name.value; save.disabled = !name.value.trim(); };
      save.onclick = () => {
        if (s) { s.name = f.name || s.name; S.billingKind = 'prepaid'; pop(() => toast('已保存')); return; }
        const n = { ...seed()[5], id: 'n' + Date.now(), name: f.name, provider: f.provider, purpose: '', region: '', host: '—', billing: 'unknown', updated: 0 };
        S.servers.unshift(n); S.billingKind = 'prepaid';
        pop(() => { rerender(stack[0]); push('detail', [n.id]); });
      };
      el.querySelector('[data-a="hw"]').onclick = () => { S.hwOpen = !S.hwOpen; rerender(); };
      el.querySelectorAll('[data-bk]').forEach(b => b.onclick = () => { S.billingKind = b.dataset.bk; rerender(); });
      el.querySelectorAll('.mini-seg.unit').forEach(seg => seg.querySelectorAll('button').forEach(b => b.onclick = () => { seg.querySelectorAll('button').forEach(x => x.classList.remove('on')); b.classList.add('on'); }));
      const sw = el.querySelector('[data-sw]'); if (sw) sw.onclick = () => sw.classList.toggle('on');
      el.querySelectorAll('[data-step]').forEach(b => b.onclick = () => { const c = el.querySelector('#cpu'); const v = Math.max(1, (parseInt(c.textContent) || 0) + +b.dataset.step); c.textContent = v; });
      el.querySelectorAll('[data-pick]').forEach(b => b.onclick = e => {
        e.stopPropagation();
        const k = b.dataset.pick;
        if (k === 'provider') picker('提供商', [{ v: null, t: '未指定' }, ...PROVIDERS.map(p => ({ v: p.name, t: p.name }))], f.provider, v => { f.provider = v; rerender(); });
        if (k === 'group') picker('分组', ['未分组', '生产', '开发', { v: '__new', t: '＋ 新建分组…' }], f.group, v => { if (v !== '__new') { f.group = v; rerender(); } });
        if (k === 'cur') picker('币种', ['USD', 'CNY', 'EUR'], f.cur, v => { f.cur = v; rerender(); });
        if (k === 'cycle') picker('续费周期', [1, 3, 6, 12, 24, 36].map(m => ({ v: m, t: `${m} 个月`, s: m === 12 ? '年付' : m === 1 ? '月付' : '' })), f.cycle, v => { f.cycle = v; rerender(); });
        if (k === 'tcycle') picker('流量周期', ['每月', '每季', '每年', '未设置'], '每月', () => {});
        if (k === 'date') dateSheet();
      });
    },
  };
};
function dateSheet() {
  const days = Array.from({ length: 31 }, (_, i) => i + 1), offset = 4;
  sheet('选择日期', `<div class="card" style="padding:12px">
    <div style="display:flex;justify-content:space-between;align-items:center;padding:0 4px 10px"><b>2026 年 10 月</b><span class="muted">${ic('chevL', 'width="18"')} ${ic('chevR', 'width="18"')}</span></div>
    <div style="display:grid;grid-template-columns:repeat(7,1fr);text-align:center;gap:4px;font-size:14px">
      ${['日', '一', '二', '三', '四', '五', '六'].map(d => `<span class="muted" style="font-size:12px">${d}</span>`).join('')}
      ${Array(offset).fill('<span></span>').join('')}
      ${days.map(d => `<span data-close style="height:36px;line-height:36px;border-radius:18px;cursor:pointer;${d === 16 ? 'background:var(--primary);color:#fff;font-weight:600' : d === 9 ? 'color:var(--primary);font-weight:600' : ''}">${d}</span>`).join('')}
    </div></div>
    <div class="footnote">实际应用两端统一使用同一个日期选择器（Cupertino 滚轮或日历，评审时再定）。</div>
    <div style="padding:12px 16px 0;display:flex;gap:10px"><button class="btn tonal" data-close style="flex:1">设为未知</button><button class="btn primary" data-close style="flex:1">完成</button></div>`);
}

// ---------- notes panel ----------
const NOTES = {
  servers: { t: '服务器列表', img: 'servers_light_viewport.png', items: [
    '大标题随滚动收起为毛玻璃导航栏标题，去掉页内 28px 标题和刷新按钮。',
    '刷新改为<b>下拉刷新</b>；「提供商管理」从整宽描边按钮收进导航栏图标。',
    '添加入口统一放在导航栏「+」（两端相同，不用悬浮按钮），打开「添加服务器」底部弹层：先选提供商，再选手动填写或从面板读取。',
    '搜索改为系统风格填充搜索框；筛选改为可横滑的胶囊（全部 / 常用 / 待续费 / 各分组），更多条件在底部弹层里。',
    '黄色「到期待核对」大横幅改成三格统计（已过期 / 30 天内 / 月费用），点击即可筛选或跳转。',
    '列表行从 4 行压缩到 2 行：提供商色块头像 + 名称/用途 + 提供商·地区；右侧显示价格和到期胶囊。一屏可显示 6 台以上（原来约 2.5 台）。',
    '左滑：SSH / 常用 / 归档；长按：预览加快捷菜单。归档后可以撤销。',
  ] },
  detail: { t: '服务器详情', img: 'detail_light.png', items: [
    '头部：大头像、名称和副标题；地址条加复制按钮；名称滚出屏幕后显示在导航栏。',
    '<b>四个快捷操作</b>（SSH / TCP / 记录付款 / 电源），不可用时置灰；点击后说明原因并给出去配置的入口，不再直接 disabled 无反馈。',
    '费用卡：续费金额、服务期进度条、剩余价值、折合金额、付款笔数集中展示；提醒和付款记录做成列表行。',
    '硬件 6 项从竖排键值对改为 3×2 网格，未填写项用浅色显示。',
    '基本信息改为「标签左、值右」的设置式列表，高度减半。',
    '编辑放在导航栏；归档放进「更多」，用 Action Sheet 二次确认，确认文案不变。',
    '大段说明只保留一句，放在分组底部的脚注里。',
  ] },
  costs: { t: '费用', img: 'costs_light.png', items: [
    '一张主卡：月费用参考大数字、折算覆盖率、剩余价值和 30 天续费两个次级指标。',
    '「缺汇率 / 费用未填」等提示只在一处出现（琥珀色提示行），不再每张卡重复三行灰字。',
    '「即将续费」改成日期块时间线，过期红色、7 天内琥珀色，点击进入详情。',
    '分布改为分段控件 + 堆叠条 + 图例列表；六个月预测改为柱状图，点击柱子查看当月金额。',
    '统计范围、显示币种改为顶部胶囊，点击后在底部弹层中选择；口径说明收进 ⓘ。',
  ] },
  tools: { t: '工具', img: 'tools_light.png', items: [
    '列表改为类似「快捷指令」的 2 列磁贴，图标用不同颜色区分功能。',
    'SSH / 电源：先在底部弹层选择已配置 SSH 的服务器，再进入连接或确认流程，少跳一层页面。',
    'TCP 测试改为弹层就地出结果。',
  ] },
  settings: { t: '设置', img: 'settings_light_viewport.png', items: [
    '采用「设置」式彩色图标，当前值显示在行右侧（外观：跟随系统；语言：简体中文）。',
    '外观、语言用选择弹层直接切换，不再进二级页。',
    '分组：台账 / 安全 / 偏好 / 数据；「关于」卡合并进顶部 App 信息和底部脚注。',
  ] },
  form: { t: '添加 / 编辑', img: 'form_add_light.png', items: [
    '以 page sheet 模态打开（底下的页面会缩小），左上「取消」，右上「保存」；名称为空时「保存」不可点。',
    '使用分组表单：标签在左，输入在右。',
    '单位改为紧凑的分段选择（MiB/GiB），vCPU 用步进器，计费方式用三段分段控件，切换后只显示相关字段。',
    '提供商、分组、币种、周期、日期都在底部弹层中选择（实际应用里日期用平台原生选择器）。',
    '硬件分组可折叠；说明文字只保留一句，放在分组脚注里。',
  ] },
  reminder: { t: '到期提醒', img: 'reminder_light.png', items: [
    '开关、提前天数、提醒时间、使用计划分成四个分组；保存放在导航栏。',
    '使用计划改为单选列表（打勾），每项附一句说明。',
    '底部实时预览具体的提醒日期和时间。',
  ] },
  ssh: { t: 'SSH 连接面板', img: 'ssh_light.png', items: [
    '从详情页或工具页打开<b>底部弹层</b>，确认目标、凭据和主机公钥状态后一键连接。完整的 SSH 配置仍在独立页面编辑。',
    '首次连接时弹出主机公钥核验（显示完整指纹），流程与安全边界不变。',
    '终端保持现有全屏深色设计，只统一顶栏和快捷键栏的样式；断开连接前需要确认。',
  ] },
  providers: { t: '提供商', img: 'providers_light.png', items: ['列表头像沿用提供商色块，副标题显示名下服务器数和适配器实例数。', '新增入口放在导航栏「+」。'] },
};
const IMG_BASE = 'current/';
function notes() {
  const k = top()?.key || S.tab;
  const n = NOTES[k] || NOTES[S.tab];
  $('#noteTitle').textContent = `本页改进 · ${n.t}`;
  $('#notes').innerHTML = `<ul>${n.items.map(i => `<li>${i}</li>`).join('')}</ul>`;
  $('#cmpImg').innerHTML = `<img src="${IMG_BASE}${n.img}" onerror="this.replaceWith(Object.assign(document.createElement('div'),{textContent:'（无截图）',style:'padding:20px;color:#999'}))">`;
}

// ---------- controls ----------
function setTheme(t) { S.theme = t; device.classList.toggle('dark', t === 'dark'); device.classList.toggle('light', t === 'light'); syncCtl(); chrome(); }
function syncCtl() {
  document.querySelectorAll('.seg-ctl').forEach(seg => seg.querySelectorAll('button').forEach(b => b.classList.toggle('on', S[seg.dataset.key] === b.dataset.v)));
}
document.querySelectorAll('.seg-ctl').forEach(seg => seg.querySelectorAll('button').forEach(b => b.onclick = () => {
  const k = seg.dataset.key, v = b.dataset.v;
  if (k === 'theme') return setTheme(v);
  S[k] = v;
  if (k === 'platform') { device.classList.toggle('ios', v === 'ios'); device.classList.toggle('android', v === 'android'); }
  if (k === 'data') { S.servers = v === 'empty' ? [] : seed(); }
  syncCtl(); closeOverlay();
  const keys = stack.map(e => ({ key: e.key, args: e.args, modal: e.modal }));
  if (k === 'data') return resetTo(S.tab);
  pagesEl.innerHTML = ''; stack.length = 0;
  keys.forEach((e, i) => { stack.push(e); const el = buildPage(e); if (i < keys.length - 1 && !keys[i + 1].modal) el.style.visibility = 'hidden'; if (i < keys.length - 1 && keys[i + 1].modal && ios()) el.classList.add('under-modal'); pagesEl.appendChild(el); });
  chrome(); notes();
}));

window.App = {
  openAddSheet,
  jump(k) {
    closeOverlay(); document.querySelector('.term')?.remove();
    if (S.data === 'empty' && ['detail', 'reminder', 'ssh'].includes(k)) { S.data = 'demo'; S.servers = seed(); syncCtl(); }
    if (['servers', 'costs', 'tools', 'settings'].includes(k)) return resetTo(k);
    resetTo('servers');
    if (k === 'detail') push('detail', ['hk']);
    if (k === 'form') push('form', [null], { modal: true });
    if (k === 'reminder') { push('detail', ['hk']); setTimeout(() => push('reminder', ['hk']), 450); }
    if (k === 'ssh') { push('detail', ['hk']); setTimeout(() => openSshSheet(byId('hk')), 450); }
  },
  toggleCmp() { const c = document.querySelector('.cmp'); c.classList.toggle('big'); $('#cmpBtn').textContent = c.classList.contains('big') ? '收起' : '放大'; },
};
resetTo('servers');
})();
