// Trang quản trị nền tảng Quán Nhỏ (/admin).
// Chốt an toàn: mọi dữ liệu văn bản chỉ gán qua textContent / createTextNode; vé quản trị chỉ giữ ở sessionStorage.
'use strict';

const CFG = window.QN_ADMIN_CONFIG || {};
const API = CFG.supabaseUrl || '/supabase';
const KEY = 'qn_admin_jwt';
const THEME_KEY = 'qn_admin_theme';
const TAB_KEY = 'qn_admin_tab';
const SVG_NS = 'http://www.w3.org/2000/svg';
const $ = (id) => document.getElementById(id);

// ── Tiện ích DOM an toàn ──────────────────────────────────────────────────────
function el(tag, attrs, ...kids) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false || k === 'style') continue;
    if (k === 'class') node.className = v;
    else if (k === 'text') node.textContent = String(v);
    else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2), v);
    else node.setAttribute(k, v === true ? '' : String(v));
  }
  for (const c of kids.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    node.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return node;
}

function svgEl(tag, attrs, ...kids) {
  const node = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v === undefined || v === null || v === false || k === 'style') continue;
    if (k === 'text') node.textContent = String(v);
    else if (k.startsWith('on') && typeof v === 'function') node.addEventListener(k.slice(2), v);
    else node.setAttribute(k, String(v));
  }
  for (const c of kids.flat(Infinity)) {
    if (c === null || c === undefined || c === false) continue;
    node.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return node;
}

const clear = (node) => {
  if (!node) return node;
  while (node.firstChild) node.removeChild(node.firstChild);
  return node;
};

// ── Định dạng số & ngày giờ Việt Nam ──────────────────────────────────────────
const pad2 = (n) => String(n).padStart(2, '0');
const fmtN = (n) => Number(n || 0).toLocaleString('vi-VN');
const fmtPct = (num, den) => {
  if (!den || den <= 0) return '0%';
  return `${((Number(num || 0) / Number(den)) * 100).toLocaleString('vi-VN', { maximumFractionDigits: 1 })}%`;
};

function fmtShortDay(s) {
  if (!s) return '—';
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s));
  if (m && String(s).length <= 10) return `${m[3]}/${m[2]}`;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return '—';
  return `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}`;
}

function fmtDay(s) {
  if (!s) return '—';
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s));
  if (m && String(s).length <= 10) return `${m[3]}/${m[2]}/${m[1]}`;
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return '—';
  return `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)}/${d.getFullYear()}`;
}

function fmtD(s) {
  if (!s) return '—';
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return '—';
  return `${pad2(d.getDate())}/${pad2(d.getMonth() + 1)} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function ago(s) {
  if (!s) return 'Chưa có';
  const diffDays = (Date.now() - new Date(s).getTime()) / 86400000;
  if (diffDays < 0.04) return 'Vừa xong';
  if (diffDays < 1) return 'Hôm nay';
  if (diffDays < 2) return 'Hôm qua';
  return `${Math.floor(diffDays)} ngày trước`;
}

function toast(msg) {
  const t = $('toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { t.hidden = true; }, 2600);
}

// ── Giao diện Sáng / Tối ──────────────────────────────────────────────────────
function initTheme() {
  try {
    const saved = localStorage.getItem(THEME_KEY);
    if (saved === 'light' || saved === 'dark') {
      document.documentElement.dataset.theme = saved;
    }
  } catch { /* bỏ qua */ }
}

function currentTheme() {
  const explicit = document.documentElement.dataset.theme;
  if (explicit === 'light' || explicit === 'dark') return explicit;
  return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function toggleTheme() {
  const next = currentTheme() === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  try { localStorage.setItem(THEME_KEY, next); } catch { /* bỏ qua */ }
  toast(next === 'dark' ? 'Đã chuyển sang nền tối' : 'Đã chuyển sang nền sáng');
}

initTheme();
$('theme-toggle').addEventListener('click', toggleTheme);
$('login-theme-toggle').addEventListener('click', toggleTheme);

// ── Trạng thái rỗng, lỗi & khung xương ────────────────────────────────────────
function emptyBox(title, subtitle) {
  const ico = svgEl('svg', { viewBox: '0 0 24 24', 'aria-hidden': 'true' },
    svgEl('rect', { x: 3, y: 4, width: 18, height: 16, rx: 3 }),
    svgEl('path', { d: 'M8 10h8M8 14h5' }),
  );
  return el('div', { class: 'empty-state' },
    el('div', { class: 'empty-ico' }, ico),
    el('strong', { text: title }),
    subtitle ? el('p', { class: 'muted small', text: subtitle }) : null,
  );
}

function errorBox(msg, onRetry) {
  return el('div', { class: 'error-state' },
    el('strong', { text: msg || 'Không tải được dữ liệu từ máy chủ.' }),
    el('button', { type: 'button', class: 'btn small', text: 'Thử lại', onclick: onRetry }),
  );
}

function showSkeletons(container, count, cls = 'h-row') {
  clear(container);
  for (let i = 0; i < count; i++) container.append(el('div', { class: `skel ${cls}` }));
}

// ── Quản lý vé đăng nhập & Thoát sạch DOM ─────────────────────────────────────
function token() {
  try {
    const raw = sessionStorage.getItem(KEY);
    if (!raw) return null;
    const { jwt, exp } = JSON.parse(raw);
    if (!jwt || !exp || Date.now() > exp - 60000) {
      sessionStorage.removeItem(KEY);
      return null;
    }
    return jwt;
  } catch {
    return null;
  }
}

function resetPromptBox() {
  const box = clear($('kn-prompt'));
  const btn = el('button', {
    type: 'button',
    class: 'btn primary',
    id: 'kn-load-prompt',
    text: 'Xem nguyên văn lời dặn',
    onclick: loadAdminPrompt,
  });
  box.append(btn);
}

// Biến trạng thái bộ nhớ trong phiên (xoá sạch khi thoát)
const st = { filter: 'all', search: '', offset: 0, limit: 30, sort: 'default', rows: [], total: 0 };
const bm = { filter: 'all', search: '', offset: 0, limit: 30, store: null, rows: [], total: 0 };
let activeTurnShortcut = null;
let lastFocusEl = null;

function closeDrawer() {
  $('drawer').hidden = true;
  document.body.classList.remove('drawer-open');
  clear($('drawer-body'));
  clear($('drawer-nav'));
  $('drawer-nav').hidden = true;
  clear($('drawer-head-left')).append(el('h2', { id: 'drawer-title', text: 'Chi tiết' }));
  activeTurnShortcut = null;
  if (lastFocusEl && typeof lastFocusEl.focus === 'function') {
    try { lastFocusEl.focus(); } catch { /* bỏ qua */ }
    lastFocusEl = null;
  }
}

function closeConfirm() {
  $('confirm-modal').hidden = true;
  confirmAction = null;
}

// Tăng mỗi lần Thoát: kết quả RPC gửi trước khi Thoát về muộn sẽ bị bỏ, không vẽ lại lên trang (QC 27/10)
let sessionGen = 0;

function logout(msg) {
  sessionGen += 1;
  try { sessionStorage.removeItem(KEY); } catch { /* bỏ qua */ }
  closeDrawer();
  closeConfirm();
  closeForm();
  profileStoreId = null;
  st.rows = []; st.total = 0; st.offset = 0;
  pl.rows = []; pl.total = 0; pl.offset = 0;
  plContactDirty = false;
  bl.filter = 'pending'; bl.search = '';
  sp.status = 'open'; sp.kind = 'all'; sp.q = ''; accountOpenId = null;
  $('sp-search').value = '';
  bm.rows = []; bm.total = 0; bm.offset = 0; bm.store = null;

  const idsToClear = [
    'ov-error', 'ov-todo', 'ov-k-rev', 'ov-k-ord', 'ov-k-act', 'ov-k-new', 'ov-rev-meta', 'ov-rev-chart',
    'ov-top', 'ov-funnel', 'ov-drop', 'ov-suggest', 'ov-new-meta', 'ov-new-chart', 'ov-week-meta', 'ov-week-chart',
    'st-list', 'bm-stats', 'bm-list', 'bm-store-filter',
    'kn-error', 'kn-changelog', 'kn-packs', 'kn-modules', 'kn-cache', 'kn-caps',
    'pl-error', 'pl-kpis', 'pl-list', 'bl-section', 'sp-list', 'sp-filters', 'sp-accounts',
  ];
  for (const id of idsToClear) clear($(id));
  $('ov-error').hidden = true;
  $('ov-suggest-card').hidden = true;
  $('ov-drop-count').textContent = '';
  $('ov-suggest-count').textContent = '';
  $('ov-updated').textContent = 'Đang tải số liệu…';
  $('ov-suggest-card').open = false;
  $('ov-rev-sum').textContent = '';
  ovRevPts = []; ovSuggest = [];
  $('pl-error').hidden = true;
  $('kn-error').hidden = true;
  $('bm-store-filter').hidden = true;
  resetPromptBox();

  $('who-name').textContent = '';
  $('who-avatar').textContent = 'Q';
  $('st-total').textContent = '';
  $('st-page').textContent = '';
  $('bm-total').textContent = '';
  $('bm-page').textContent = '';
  $('pl-total').textContent = '';
  $('pl-page').textContent = '';
  $('pl-contact').value = '';

  $('password').value = '';
  $('password').type = 'password';
  $('pw-toggle').classList.remove('showing');
  $('pw-toggle').setAttribute('aria-pressed', 'false');
  $('pw-toggle').setAttribute('aria-label', 'Hiện mật khẩu');

  $('app').hidden = true;
  $('login').hidden = false;
  const errEl = $('login-error');
  errEl.textContent = msg || '';
  errEl.hidden = !msg;
}

async function rpc(name, params) {
  const jwt = token();
  if (!jwt) {
    logout('Phiên làm việc đã hết hạn, vui lòng đăng nhập lại.');
    throw new Error('NO_TOKEN');
  }
  const gen = sessionGen;
  const r = await fetch(`${API}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: CFG.anonKey || '',
      Authorization: `Bearer ${jwt}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params || {}),
  });
  if (gen !== sessionGen) throw new Error('NO_TOKEN');
  if (r.status === 401) {
    logout('Phiên làm việc đã hết hạn, vui lòng đăng nhập lại.');
    throw new Error('UNAUTHORIZED');
  }
  const data = await r.json().catch(() => null);
  if (gen !== sessionGen) throw new Error('NO_TOKEN');
  if (!r.ok || !data) throw new Error(`HTTP_${r.status}`);
  if (data.ok === false) {
    if (data.error === 'FORBIDDEN') logout('Tài khoản không có quyền quản trị.');
    throw new Error(data.error || 'ERROR');
  }
  return data;
}

// ── Màn đăng nhập ─────────────────────────────────────────────────────────────
$('pw-toggle').addEventListener('click', () => {
  const pw = $('password');
  const btn = $('pw-toggle');
  const showing = pw.type === 'password';
  pw.type = showing ? 'text' : 'password';
  btn.classList.toggle('showing', showing);
  btn.setAttribute('aria-pressed', String(showing));
  btn.setAttribute('aria-label', showing ? 'Ẩn mật khẩu' : 'Hiện mật khẩu');
});

$('login-form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  const username = $('username').value.trim();
  const password = $('password').value;
  const errEl = $('login-error');
  if (!username || !password) {
    errEl.textContent = 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.';
    errEl.hidden = false;
    return;
  }
  const btn = $('login-btn');
  const btnTxt = $('login-btn-text');
  btn.disabled = true;
  btn.classList.add('loading');
  btnTxt.textContent = 'Đang đăng nhập…';
  errEl.textContent = '';
  errEl.hidden = true;

  try {
    const r = await fetch('/api/auth/admin-jwt', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok || !d.admin_jwt) {
      errEl.textContent = r.status === 401
        ? 'Tên đăng nhập hoặc mật khẩu không đúng.'
        : (d.message || 'Tên đăng nhập hoặc mật khẩu không đúng.');
      errEl.hidden = false;
      return;
    }
    sessionStorage.setItem(KEY, JSON.stringify({
      jwt: d.admin_jwt,
      exp: Date.now() + (d.expires_in || 3600) * 1000,
    }));
    $('password').value = '';
    $('password').type = 'password';
    $('pw-toggle').classList.remove('showing');
    await start();
  } catch {
    errEl.textContent = 'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.';
    errEl.hidden = false;
  } finally {
    btn.disabled = false;
    btn.classList.remove('loading');
    btnTxt.textContent = 'Đăng nhập';
  }
});

$('logout').addEventListener('click', () => logout(''));

async function start() {
  if (!token()) { logout(''); return; }
  try {
    const me = await rpc('admin_whoami_v1');
    const name = me.name || 'Quản trị';
    $('who-name').textContent = name;
    $('who-avatar').textContent = name.trim().charAt(0).toUpperCase() || 'Q';
  } catch {
    return;
  }
  $('login').hidden = true;
  $('app').hidden = false;
  let initialTab = location.hash.slice(1);
  if (!initialTab) {
    try { initialTab = localStorage.getItem(TAB_KEY) || 'overview'; } catch { initialTab = 'overview'; }
  }
  showTab(initialTab);
}

// ── Điều hướng 4 Tab ──────────────────────────────────────────────────────────
const loaders = {};
const TAB_ORDER = ['overview', 'stores', 'plans', 'support', 'boom', 'knowledge'];

function showTab(name) {
  if (!loaders[name]) name = 'overview';
  for (const b of document.querySelectorAll('.tab')) {
    const active = b.dataset.tab === name;
    b.classList.toggle('on', active);
    b.setAttribute('aria-selected', String(active));
  }
  for (const s of document.querySelectorAll('.page')) {
    s.hidden = s.id !== `tab-${name}`;
  }
  if (location.hash !== `#${name}`) history.replaceState(null, '', `#${name}`);
  try { localStorage.setItem(TAB_KEY, name); } catch { /* bỏ qua */ }
  loaders[name]();
}

for (const b of document.querySelectorAll('.tab')) {
  b.addEventListener('click', () => showTab(b.dataset.tab));
  b.addEventListener('keydown', (e) => {
    const idx = TAB_ORDER.indexOf(b.dataset.tab);
    if (idx < 0) return;
    let nextIdx = -1;
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') nextIdx = (idx + 1) % TAB_ORDER.length;
    else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') nextIdx = (idx - 1 + TAB_ORDER.length) % TAB_ORDER.length;
    if (nextIdx >= 0) {
      e.preventDefault();
      const targetTab = TAB_ORDER[nextIdx];
      showTab(targetTab);
      const nextBtn = $(`tabbtn-${targetTab}`);
      if (nextBtn) nextBtn.focus();
    }
  });
}

// ── Biểu đồ cột SVG tương tác (có trục, lưới, nhãn thưa, tooltip chạm/rê) ─────
function niceCeiling(maxVal) {
  if (maxVal <= 4) return 4;
  const step = Math.ceil(maxVal / 4);
  if (step <= 5) return step * 4;
  const mag = Math.pow(10, Math.floor(Math.log10(step)));
  const norm = step / mag;
  const niceStep = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5 : 10) * mag;
  return Math.ceil(niceStep * 4);
}

function renderChart(container, metaBox, points, opts) {
  clear(container);
  clear(metaBox);
  metaBox.classList.remove('active');

  if (!points || !points.length) {
    container.append(emptyBox('Chưa có dữ liệu biểu đồ', 'Số liệu sẽ hiển thị khi có quán phát sinh hoạt động.'));
    return;
  }

  const totalSum = points.reduce((acc, p) => acc + Number(p.n || 0), 0);
  const maxRaw = Math.max(0, ...points.map((p) => Number(p.n || 0)));
  const lastPt = points[points.length - 1];
  const defaultMeta = opts.summaryText(totalSum, lastPt ? lastPt.n : 0, points.length);
  metaBox.textContent = defaultMeta;

  if (maxRaw === 0) {
    container.append(opts.emptyNode ? opts.emptyNode() : emptyBox('0 quán trong giai đoạn này', 'Chưa ghi nhận quán nào trong khung thời gian đã chọn.'));
    return;
  }

  const W = 640, H = 220;
  const padR = 16, padT = 30, padB = 28;
  const plotH = H - padT - padB;
  // Một ngày đột biến (vd ngày ra mắt) gấp > 3 lần ngày cao thứ nhì → cắt trục theo ngày thứ nhì, cột đột biến ghi số
  const sortedVals = points.map((p) => Number(p.n || 0)).sort((a, b) => b - a);
  const capped = !!opts.capOutlier && sortedVals[1] > 0 && sortedVals[0] > sortedVals[1] * 3;
  const yMax = niceCeiling(capped ? sortedVals[1] * 1.25 : maxRaw);
  const axisFmt = opts.axisFmt || fmtN;
  const padL = Math.max(36, axisFmt(yMax).length * 6.5 + 12);  // nhãn dài ("7,5 tỷ") không bị cắt mép
  const plotW = W - padL - padR;

  const svg = svgEl('svg', { viewBox: `0 0 ${W} ${H}`, role: 'img', 'aria-label': opts.ariaLabel });

  // Lưới ngang & nhãn trục Y
  for (let s = 0; s <= 4; s++) {
    const val = Math.round((yMax * s) / 4);
    const y = padT + plotH - (plotH * s) / 4;
    svg.append(
      svgEl('line', { x1: padL, y1: y, x2: W - padR, y2: y, class: s === 0 ? 'axis-line' : 'grid-line' }),
      svgEl('text', { x: padL - 7, y: y + 4, 'text-anchor': 'end', class: 'axis-lbl', text: axisFmt(val) }),
    );
  }

  // Nhãn trục X thưa, không bao giờ chồng chữ hoặc cắt mép
  const count = points.length;
  const xIndices = [];
  if (count <= 14) {
    for (let i = 0; i < count; i += 2) xIndices.push(i);
    if (xIndices[xIndices.length - 1] !== count - 1) {
      if (count - 1 - xIndices[xIndices.length - 1] < 2) xIndices.pop();
      xIndices.push(count - 1);
    }
  } else {
    const steps = 5;
    for (let k = 0; k <= steps; k++) {
      xIndices.push(Math.round((k * (count - 1)) / steps));
    }
  }

  const slotW = plotW / count;
  for (const idx of xIndices) {
    const cx = padL + idx * slotW + slotW / 2;
    const anchor = idx === 0 ? 'start' : idx === count - 1 ? 'end' : 'middle';
    const xPos = idx === 0 ? padL : idx === count - 1 ? W - padR : cx;
    svg.append(svgEl('text', {
      x: xPos.toFixed(1),
      y: H - 7,
      'text-anchor': anchor,
      class: 'axis-lbl',
      text: opts.xAxisLabel(points[idx], idx === count - 1),
    }));
  }

  const guide = svgEl('line', { x1: 0, y1: padT, x2: 0, y2: padT + plotH, class: 'hover-guide' });
  svg.append(guide);

  const barsGroup = svgEl('g', {});
  const hitsGroup = svgEl('g', {});
  const tipGroup = svgEl('g', { hidden: '' });
  const tipRect = svgEl('rect', { rx: 6, ry: 6, height: 22, class: 'tip-bg' });
  const tipText = svgEl('text', { y: 19, 'text-anchor': 'middle', class: 'tip-txt' });
  tipGroup.append(tipRect, tipText);

  const barEls = [];
  const gap = count > 30 ? 2 : 5;
  const barW = Math.max(2.5, slotW - gap);

  function activateBar(idx) {
    barEls.forEach((b, j) => b.classList.toggle('hovered', j === idx));
    const p = points[idx];
    const cx = padL + idx * slotW + slotW / 2;
    guide.setAttribute('x1', cx.toFixed(1));
    guide.setAttribute('x2', cx.toFixed(1));
    guide.classList.add('on');

    const labelStr = `${opts.tooltipLabel(p, idx === count - 1)}: ${opts.valueText ? opts.valueText(p) : `${fmtN(p.n)} quán`}`;
    metaBox.textContent = labelStr;
    metaBox.classList.add('active');

    tipText.textContent = labelStr;
    const estWidth = Math.max(96, labelStr.length * 6.8 + 18);
    const clampedX = Math.min(W - padR - estWidth / 2, Math.max(padL + estWidth / 2, cx));
    tipRect.setAttribute('x', (clampedX - estWidth / 2).toFixed(1));
    tipRect.setAttribute('y', '4');
    tipRect.setAttribute('width', estWidth.toFixed(1));
    tipText.setAttribute('x', clampedX.toFixed(1));
    tipGroup.removeAttribute('hidden');
  }

  function resetHover() {
    barEls.forEach((b) => b.classList.remove('hovered'));
    guide.classList.remove('on');
    tipGroup.setAttribute('hidden', '');
    metaBox.textContent = defaultMeta;
    metaBox.classList.remove('active');
  }

  points.forEach((p, i) => {
    const val = Number(p.n || 0);
    const isLast = i === count - 1;
    const over = val > yMax;
    const rawH = (plotH * Math.min(val, yMax)) / yMax;
    const h = val === 0 ? 2 : Math.max(3, rawH);
    const x = padL + i * slotW + (slotW - barW) / 2;
    const y = padT + plotH - h;
    const cls = `bar${val === 0 ? ' zero' : ''}${isLast ? ` ${opts.lastCls || 'current'}` : ''}`;
    const rect = svgEl('rect', {
      x: x.toFixed(1),
      y: y.toFixed(1),
      width: barW.toFixed(1),
      height: h.toFixed(1),
      rx: Math.min(4, barW / 2).toFixed(1),
      class: cls,
    });
    barEls.push(rect);
    barsGroup.append(rect);
    if (over) {
      barsGroup.append(svgEl('text', { x: (x + barW / 2).toFixed(1), y: (padT - 6).toFixed(1), 'text-anchor': 'middle',
                                       class: 'axis-lbl', text: `↑${axisFmt(val)}` }));
    }

    const hit = svgEl('rect', {
      x: (padL + i * slotW).toFixed(1),
      y: padT,
      width: slotW.toFixed(1),
      height: plotH,
      class: 'hit',
    });
    hit.addEventListener('pointerenter', () => activateBar(i));
    hit.addEventListener('pointerdown', () => activateBar(i));
    hitsGroup.append(hit);
  });

  svg.addEventListener('pointerleave', resetHover);
  svg.append(barsGroup, tipGroup, hitsGroup);
  container.append(svg);
}

// ── Tab 1: Tổng quan ──────────────────────────────────────────────────────────
// Một ngày đột biến (> 3 lần ngày cao thứ nhì) → trần theo ngày thứ nhì, để các ngày khác không bị bẹp
function softMax(vals) {
  const s = vals.slice().sort((a, b) => b - a);
  return s[1] > 0 && s[0] > s[1] * 3 ? s[1] * 1.25 : Math.max(1, s[0] || 0);
}

function sparkline(values, label) {
  const vals = values.map((v) => Number(v || 0));
  if (vals.length < 2) return null;
  const W = 120, H = 32;
  const max = softMax(vals);
  const step = vals.length > 1 ? W / (vals.length - 1) : W;
  const pts = vals.map((v, i) => `${(i * step).toFixed(1)},${(H - 2 - (Math.min(v, max) / max) * (H - 4)).toFixed(1)}`);
  return svgEl('svg', { viewBox: `0 0 ${W} ${H}`, preserveAspectRatio: 'none', class: 'ov-spark', role: 'img', 'aria-label': label },
    svgEl('path', { d: `M0,${H} L${pts.join(' L')} L${W},${H} Z`, class: 'ov-spark-area' }),
    svgEl('polyline', { points: pts.join(' '), class: 'ov-spark-line', 'vector-effect': 'non-scaling-stroke' }),
  );
}

// "▲ 18% so với 7 ngày trước" — xanh tăng, đỏ giảm
function kpiDelta(cur, prev, vsText) {
  cur = Number(cur || 0); prev = Number(prev || 0);
  if (prev <= 0) return el('span', { class: 'muted', text: cur > 0 ? 'Kỳ trước 0' : 'Chưa có đơn' });
  if (cur === prev) return el('span', { class: 'muted', text: `Bằng ${vsText.replace(/^so với /, '')}` });
  const raw = ((cur - prev) / prev) * 100;
  const pct = Math.round(Math.abs(raw));
  return el('span', {},
    el('span', { class: `ov-delta ${raw > 0 ? 'up' : 'down'}`, text: `${raw > 0 ? '▲' : '▼'} ${pct < 1 ? '<1' : fmtN(pct)}%` }),
    el('span', { class: 'muted', text: ` ${vsText}` }),
  );
}

function fillKpi(id, label, value, foot, spark) {
  clear($(id)).append(...[
    el('div', { class: 'ov-kpi-label', text: label }),
    el('div', { class: 'ov-kpi-val', text: value }),
    el('div', { class: 'ov-kpi-foot small' }, foot),
    spark,
  ].filter(Boolean));
}

function hBar(ratio, cls) {
  const w = Math.round(Math.max(0, Math.min(1, ratio)) * 1000);
  return svgEl('svg', { viewBox: '0 0 1000 6', preserveAspectRatio: 'none', class: 'ov-hbar', 'aria-hidden': 'true' },
    svgEl('rect', { x: 0, y: 0, width: 1000, height: 6, rx: 3, class: 'ov-hbar-track' }),
    w > 0 ? svgEl('rect', { x: 0, y: 0, width: Math.max(12, w), height: 6, rx: 3, class: cls || 'ov-hbar-fill' }) : null,
  );
}

function renderFunnel(d) {
  const total = Number(d.total || 0);
  const never = Number(d.never_sold || 0);
  const everSold = Math.max(0, total - never);
  const act30 = Number(d.active_30d || 0);
  const act7 = Number(d.active_7d || 0);
  const steps = [
    { name: 'Đã tạo quán', count: total, note: `${fmtN(d.new_30d)} quán mới trong 30 ngày` },
    { name: 'Đã từng bán', count: everSold, prev: total, note: `${fmtN(never)} quán chưa bán đơn nào`, filter: 'never', link: 'Xem quán chưa bán' },
    { name: 'Còn bán trong 30 ngày', count: act30, prev: everSold, note: `${fmtN(d.sleeping)} quán đang ngủ`, filter: 'sleeping', link: 'Xem quán ngủ' },
    { name: 'Tích cực 7 ngày', count: act7, prev: act30, note: `${fmtPct(act7, total)} tổng số quán`, filter: 'active', link: 'Xem quán tích cực' },
  ];
  clear($('ov-funnel')).append(...steps.map((s) => el('div', { class: 'ov-step' },
    el('div', { class: 'ov-step-name small', text: s.name }),
    el('div', { class: 'ov-step-val' },
      el('span', { text: fmtN(s.count) }),
      s.prev !== undefined ? el('span', { class: 'ov-step-pct', text: fmtPct(s.count, s.prev) }) : null,
    ),
    hBar(total > 0 ? s.count / total : 0),
    el('div', { class: 'ov-step-note small muted', text: s.note }),
    s.filter ? el('button', {
      type: 'button',
      class: 'link small ov-step-link',
      text: `${s.link}\u00a0›`,
      onclick: () => {
        st.filter = s.filter;
        st.offset = 0;
        showTab('stores');
      },
    }) : null,
  )));
}

loaders.overview = async () => {
  const errBox = $('ov-error');
  errBox.hidden = true;
  clear(errBox);
  for (const id of ['ov-k-act', 'ov-k-new']) if (!$(id).children.length) showSkeletons($(id), 1, 'h-kpi');
  try {
    const includeTest = $('ov-include-test').checked;
    loadOverviewExtra(includeTest);  // khối doanh số chạy song song; lỗi riêng không làm hỏng khối này
    const d = await rpc('admin_store_overview_v1', { p_include_test: includeTest });

    const now = new Date();
    $('ov-updated').textContent = `Cập nhật lúc ${pad2(now.getHours())}:${pad2(now.getMinutes())} · `
      + (includeTest ? `Đang tính cả ${fmtN(d.test_stores)} quán thử` : `Đã loại ${fmtN(d.test_stores)} quán thử khỏi số liệu`);

    const weeks = d.active_by_week || [];
    fillKpi('ov-k-act', 'Quán đang dùng tích cực', fmtN(d.active_7d),
      el('span', { class: 'muted', text: `${fmtPct(d.active_7d, d.total)} trên ${fmtN(d.total)} quán · 7 ngày qua` }),
      sparkline(weeks.slice(0, -1).map((w) => w.n), 'Xu hướng số quán có đơn theo tuần (các tuần đã trọn)'));
    fillKpi('ov-k-new', 'Quán mới 7 ngày', fmtN(d.new_7d),
      el('span', { class: 'muted', text: `+${fmtN(d.new_today)} hôm nay · ${fmtN(d.new_30d)} trong 30 ngày` }),
      sparkline((d.new_by_day || []).slice(-30).map((p) => p.n), 'Xu hướng quán mới theo ngày, 30 ngày qua'));

    renderFunnel(d);

    renderChart($('ov-new-chart'), $('ov-new-meta'), d.new_by_day || [], {
      capOutlier: true,
      ariaLabel: 'Biểu đồ số quán mới theo ngày trong 60 ngày qua',
      xAxisLabel: (p, isLast) => (isLast ? 'Hôm nay' : fmtShortDay(p.day)),
      tooltipLabel: (p, isLast) => (isLast ? `Hôm nay ${fmtShortDay(p.day)}` : `Ngày ${fmtShortDay(p.day)}`),
      summaryText: (sum, last) => `Tổng ${fmtN(sum)} quán · hôm nay +${fmtN(last)}`,
    });

    renderChart($('ov-week-chart'), $('ov-week-meta'), weeks, {
      lastCls: 'partial',
      ariaLabel: 'Biểu đồ số quán có đơn theo tuần trong 12 tuần qua',
      xAxisLabel: (p, isLast) => (isLast ? 'Tuần này' : fmtShortDay(p.week_start)),
      tooltipLabel: (p, isLast) => (isLast ? `Tuần này (mới ${weekDaysSoFar(p.week_start)} ngày)` : `Tuần ${fmtShortDay(p.week_start)}`),
      // tuần này chưa hết → không đưa vào trung bình
      summaryText: (sum, last, len) => `Trung bình ${fmtN(Math.round((sum - last) / Math.max(1, len - 1)))} quán/tuần · tuần này ${fmtN(last)}`,
    });
  } catch (err) {
    if (err && (err.message === 'NO_TOKEN' || err.message === 'UNAUTHORIZED' || err.message === 'FORBIDDEN')) return;
    clear($('ov-k-act')); clear($('ov-k-new'));
    errBox.hidden = false;
    errBox.append(errorBox('Không tải được tổng quan các quán.', () => loaders.overview()));
  }
};

// Số ngày đã qua của tuần (tính cả hôm nay, giờ máy) — tuần bắt đầu thứ Hai
function weekDaysSoFar(weekStart) {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(weekStart || ''));
  if (!m) return 1;
  const start = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  return Math.min(7, Math.max(1, Math.floor((Date.now() - start.getTime()) / 86400000) + 1));
}

function goPlans(filter, scrollToBilling) {
  pl.filter = filter;
  pl.offset = 0;
  pl.search = '';
  $('pl-search').value = '';
  $('pl-include-test').checked = $('ov-include-test').checked;  // cùng cách đếm với ô vừa bấm
  showTab('plans');
  if (scrollToBilling) setTimeout(() => $('bl-section').scrollIntoView({ behavior: 'smooth', block: 'start' }), 300);
}

// Biểu đồ doanh số: chuyển Doanh thu / Số đơn không gọi lại máy chủ
let ovRevPts = [];
let ovRevMode = 'rev';
function drawRevChart() {
  const byRev = ovRevMode === 'rev';
  renderChart($('ov-rev-chart'), $('ov-rev-meta'), ovRevPts.map((p) => ({ ...p, n: byRev ? p.revenue : p.orders })), {
    capOutlier: true,
    axisFmt: byRev ? fmtMoneyShort : fmtN,
    ariaLabel: `Biểu đồ ${byRev ? 'doanh thu' : 'số đơn'} toàn hệ thống theo ngày trong 30 ngày qua`,
    xAxisLabel: (p, isLast) => (isLast ? 'Hôm nay' : fmtShortDay(p.day)),
    tooltipLabel: (p, isLast) => (isLast ? 'Hôm nay' : `Ngày ${fmtShortDay(p.day)}`),
    valueText: (p) => `${fmtMoney(p.revenue)} · ${fmtN(p.orders)} đơn`,
    summaryText: (sum, last) => (byRev ? `Tổng ${fmtMoneyShort(sum)} · hôm nay ${fmtMoneyShort(last)}` : `Tổng ${fmtN(sum)} đơn · hôm nay ${fmtN(last)}`),
    emptyNode: () => emptyBox('Chưa có doanh thu', 'Chưa quán nào bán trong 30 ngày qua.'),
  });
}
for (const [id, mode] of [['ov-rev-mode-rev', 'rev'], ['ov-rev-mode-ord', 'ord']]) {
  $(id).addEventListener('click', () => {
    ovRevMode = mode;
    for (const b of [$('ov-rev-mode-rev'), $('ov-rev-mode-ord')]) {
      const on = b.id === id;
      b.classList.toggle('on', on);
      b.setAttribute('aria-pressed', String(on));
    }
    if (ovRevPts.length) drawRevChart();
  });
}

function todoItem(value, label, cls, onClick) {
  return el('button', { type: 'button', class: `ov-todo-item ${cls}`, onclick: onClick },
    el('span', { class: 'ov-todo-v', text: fmtN(value) }),
    el('span', { class: 'ov-todo-k', text: label }),
  );
}

let ovSuggest = [];
let ovExtraGen = 0;
async function loadOverviewExtra(includeTest) {
  const gen = ++ovExtraGen;
  if (!$('ov-todo').children.length) {
    showSkeletons($('ov-todo'), 1, 'h-row');
    for (const id of ['ov-k-rev', 'ov-k-ord']) showSkeletons($(id), 1, 'h-kpi');
    for (const id of ['ov-top', 'ov-drop']) showSkeletons($(id), 3, 'h-row');
    showSkeletons($('ov-rev-chart'), 1, 'h-chart');
  }
  let x;
  try {
    x = await rpc('admin_overview_extra_v1', { p_include_test: includeTest });
    if (gen !== ovExtraGen) return;  // đã có lượt tải mới hơn
    if (!x || x.ok === false) throw new Error((x && x.error) || 'ERR');
  } catch (err) {
    if (isAuthErr(err) || gen !== ovExtraGen) return;
    for (const id of ['ov-todo', 'ov-top', 'ov-drop', 'ov-rev-chart', 'ov-rev-meta', 'ov-rev-sum']) clear($(id));
    fillKpi('ov-k-rev', 'Doanh thu 7 ngày', '—', el('span', { class: 'muted', text: 'Không tải được' }));
    fillKpi('ov-k-ord', 'Đơn hoàn thành 7 ngày', '—', el('span', { class: 'muted', text: 'Không tải được' }));
    $('ov-rev-chart').append(emptyBox('Không tải được doanh số', 'Bấm "Thử lại" ở dải việc cần làm.'));
    $('ov-drop-count').textContent = '';
    ovRevPts = [];
    $('ov-todo').append(errorBox('Không tải được doanh số / việc hôm nay.', () => loadOverviewExtra(includeTest)));
    $('ov-suggest-card').hidden = true;
    return;
  }

  const t = x.todo || {};
  const drop = x.dropping || { total: 0, rows: [] };
  const items = [
    [t.trial_ending, 'Sắp hết dùng thử', 'warn', () => goPlans('trial_ending')],
    [t.trial_expired, 'Đã hết dùng thử', 'bad', () => goPlans('trial_expired')],
    [Number(t.pro_ending || 0) + Number(t.pro_expired || 0), 'Gói Pro sắp hết / hết hạn', 'warn', () => goPlans('pro_due')],
    [t.follow_ups_due, 'Ghi chú cần gọi lại', 'warn', () => goPlans('follow_up')],
    [Number(t.support_open || 0) || Number(t.support_in_progress || 0),
      Number(t.support_open || 0) ? `Hỗ trợ mới${Number(t.support_in_progress || 0) ? ` (+${fmtN(t.support_in_progress)} đang xử lý)` : ''}` : 'Hỗ trợ đang xử lý',
      Number(t.support_open || 0) ? 'bad' : 'warn', () => {
        sp.status = Number(t.support_open || 0) > 0 ? 'open' : 'in_progress';
        sp.kind = 'all';
        showTab('support');
      }],
    [t.billing_pending, 'Đơn thu phí chờ xác nhận', 'warn', () => { bl.filter = 'pending'; goPlans('all', true); }],
    [drop.total, 'Quán đang bỏ dùng', 'warn', () => $('ov-drop-panel').scrollIntoView({ behavior: 'smooth', block: 'start' })],
  ].filter((it) => Number(it[0] || 0) > 0);
  clear($('ov-todo')).append(...(items.length
    ? items.map((it) => todoItem(...it))
    : [el('p', { class: 'ov-todo-none muted', text: 'Hôm nay không có việc nào cần xử lý.' })]));

  const sa = x.sales || {};
  const byDay = sa.by_day || [];
  fillKpi('ov-k-rev', 'Doanh thu 7 ngày', fmtMoneyShort(sa.revenue_7d),
    kpiDelta(sa.revenue_7d, sa.revenue_prev7, 'so với kỳ trước'),
    sparkline(byDay.map((p) => p.revenue), 'Xu hướng doanh thu theo ngày, 30 ngày qua'));
  fillKpi('ov-k-ord', 'Đơn hoàn thành 7 ngày', fmtN(sa.orders_7d),
    kpiDelta(sa.orders_7d, sa.orders_prev7, 'so với kỳ trước'),
    sparkline(byDay.map((p) => p.n), 'Xu hướng số đơn theo ngày, 30 ngày qua'));

  clear($('ov-rev-sum')).append(
    `30 ngày: ${fmtMoneyShort(sa.revenue_30d)} · ${fmtN(sa.orders_30d)} đơn · ${fmtN(sa.stores_selling_7d)} quán có bán 7 ngày qua · `,
    kpiDelta(sa.revenue_30d, sa.revenue_prev30, 'so với 30 ngày trước'),
  );
  ovRevPts = byDay.map((p) => ({ day: p.day, revenue: Number(p.revenue || 0), orders: Number(p.n || 0) }));
  drawRevChart();

  const top = sa.top || [];
  const topMax = Math.max(1, ...top.map((r) => Number(r.revenue || 0)));
  clear($('ov-top')).append(...(top.length ? top.map((r, i) => el('li', { class: 'ov-top-row' },
    el('span', { class: 'ov-rank', text: String(i + 1) }),
    el('div', { class: 'ov-top-main' },
      el('div', { class: 'ov-top-line' },
        el('button', { type: 'button', class: 'ov-link', text: r.name || r.code || 'Quán', onclick: (ev) => openStoreDetail(r, ev.currentTarget) }),
        el('span', { class: 'ov-top-val', text: fmtMoneyShort(r.revenue) }),
      ),
      hBar(Number(r.revenue || 0) / topMax),
      el('span', { class: 'small muted', text: `${fmtN(r.orders)} đơn · ${fmtN(r.orders_7d)} đơn trong 7 ngày` }),
    ),
  )) : [el('li', {}, emptyBox('Chưa có quán bán', 'Chưa quán nào có đơn trong 30 ngày qua.'))]));

  $('ov-drop-count').textContent = drop.total ? fmtN(drop.total) : '';
  const dropBox = clear($('ov-drop'));
  if (!drop.rows || !drop.rows.length) {
    dropBox.append(emptyBox('Không có quán nào đang bỏ dùng', 'Mọi quán có bán trong 30 ngày đều còn bán tuần này.'));
  } else {
    const DROP_FIRST = 6;
    const td = (label, cls, ...kids) => el('td', { 'data-label': label, class: cls }, ...kids);
    const tbody = el('tbody', {}, ...drop.rows.map((r, i) => el('tr', { hidden: i >= DROP_FIRST },
      td('Quán', 'ov-td-name',
        el('b', { text: r.name || r.code || 'Quán' }),
        r.locked ? el('span', { class: 'ov-tag bad', text: 'Đang khoá' }) : null),
      td('Chủ quán', '',
        el('div', { text: r.owner_name || '—' }),
        r.owner_phone ? el('div', { class: 'small muted num', text: r.owner_phone }) : null),
      td('Đơn cuối', '',
        el('div', { text: ago(r.last_order_at) }),
        el('div', { class: 'small muted num', text: fmtDay(r.last_order_at) })),
      td('30 ngày', 'num-col',
        el('div', { class: 'num', text: fmtMoneyShort(r.revenue_30d) }),
        el('div', { class: 'small muted num', text: `${fmtN(r.orders_30d)} đơn` })),
      td('', 'ov-td-act',
        r.owner_phone ? el('a', { class: 'btn small', href: `tel:${String(r.owner_phone).replace(/[^+\d]/g, '')}`, text: 'Gọi' }) : null,
        el('button', { type: 'button', class: 'btn small', text: 'Hồ sơ', onclick: (ev) => openStoreDetail(r, ev.currentTarget) })),
    )));
    dropBox.append(el('table', { class: 'ov-table' },
      el('thead', {}, el('tr', {},
        el('th', { scope: 'col', text: 'Quán' }),
        el('th', { scope: 'col', text: 'Chủ quán' }),
        el('th', { scope: 'col', text: 'Đơn cuối' }),
        el('th', { scope: 'col', class: 'num-col', text: '30 ngày' }),
        el('th', { scope: 'col' }, el('span', { class: 'ov-sr', text: 'Thao tác' })),
      )),
      tbody,
    ));
    const foot = el('div', { class: 'ov-table-foot small muted' });
    if (drop.rows.length > DROP_FIRST) {
      const more = el('button', { type: 'button', class: 'btn small', text: `Xem thêm ${fmtN(drop.rows.length - DROP_FIRST)} quán`, onclick: () => {
        for (const n of tbody.querySelectorAll('tr[hidden]')) n.hidden = false;
        more.remove();
        const next = tbody.rows[DROP_FIRST] && tbody.rows[DROP_FIRST].querySelector('.ov-td-act .btn');
        if (next) next.focus();  // giữ chỗ đang xem, không nhảy về đầu trang
      } });
      foot.append(more);
    }
    if (Number(drop.total) > drop.rows.length) {
      foot.append(el('span', { text: `Hiện ${fmtN(drop.rows.length)} / ${fmtN(drop.total)} quán bán nhiều nhất.` }));
    }
    if (foot.childNodes.length) dropBox.append(foot);
  }

  ovSuggest = x.test_suggest || [];
  $('ov-suggest-card').hidden = !ovSuggest.length;
  $('ov-suggest-count').textContent = ovSuggest.length >= 100 ? '100+' : fmtN(ovSuggest.length);
  clear($('ov-suggest')).append(...ovSuggest.map((r) => {
    const cb = el('input', { type: 'checkbox', 'data-id': r.id });
    cb.checked = Number(r.orders_total || 0) === 0;
    return el('div', { class: 'ov-list-row' },
      el('label', { class: 'ov-check' }, cb,
        el('div', { class: 'ov-row-main' },
          el('b', { text: r.name || '(chưa đặt tên)' }),
          el('span', { class: 'small muted', text: `${r.reason === 'name_test' ? 'Tên có test / demo / thử' : 'Tên vô nghĩa, chưa bán đơn nào'} · tạo ${fmtDay(r.created_at)} · ${fmtN(r.orders_total)} đơn` }),
        ),
      ),
      el('button', { type: 'button', class: 'btn small', text: 'Hồ sơ', onclick: (ev) => openStoreDetail(r, ev.currentTarget) }),
    );
  }));
}

$('ov-suggest-mark').addEventListener('click', () => {
  const picked = [...$('ov-suggest').querySelectorAll('input[type=checkbox]:checked')].map((c) => c.getAttribute('data-id'));
  if (!picked.length) { toast('Chưa chọn quán nào'); return; }
  const names = ovSuggest.filter((r) => picked.includes(r.id)).map((r) => r.name || '(chưa đặt tên)');
  askConfirm(
    `Đánh dấu ${fmtN(picked.length)} quán là quán thử?`,
    `${names.slice(0, 8).join(', ')}${names.length > 8 ? ` và ${fmtN(names.length - 8)} quán khác` : ''}. `
      + 'Các quán này bị loại khỏi số liệu mặc định; vẫn bán hàng bình thường. Bỏ đánh dấu được ở tab Quán → bộ lọc "Quán thử".',
    'Đánh dấu quán thử',
    async () => {
      const btn = $('ov-suggest-mark');
      btn.disabled = true;
      let ok = 0;
      try {
      for (const id of picked) {
        try { await rpc('admin_set_test_store_v1', { p_store: id, p_is_test: true }); ok += 1; } catch (err) { if (isAuthErr(err)) return; }
      }
      } finally { btn.disabled = false; }
      toast(ok === picked.length ? `Đã đánh dấu ${fmtN(ok)} quán thử` : `Đánh dấu được ${fmtN(ok)} / ${fmtN(picked.length)} quán`);
      loaders.overview();
    },
  );
});

$('ov-include-test').addEventListener('change', () => loaders.overview());
$('ov-refresh').addEventListener('click', () => loaders.overview());

// ── Tab 2: Danh sách Quán ─────────────────────────────────────────────────────
function chipGroup(id, state, reload) {
  const box = $(id);
  for (const c of box.querySelectorAll('.chip')) {
    c.addEventListener('click', () => {
      state.filter = c.dataset.f;
      state.offset = 0;
      reload();
    });
  }
  return () => {
    for (const c of box.querySelectorAll('.chip')) {
      const on = c.dataset.f === state.filter;
      c.classList.toggle('on', on);
      c.setAttribute('aria-pressed', String(on));
    }
  };
}

const stMark = chipGroup('st-filters', st, () => loaders.stores());
let stTimer;
$('st-search').addEventListener('input', () => {
  clearTimeout(stTimer);
  stTimer = setTimeout(() => {
    st.search = $('st-search').value.trim();
    st.offset = 0;
    loaders.stores();
  }, 350);
});
$('st-include-test').addEventListener('change', () => { st.offset = 0; loaders.stores(); });
$('st-refresh').addEventListener('click', () => loaders.stores());
$('st-prev').addEventListener('click', () => { st.offset = Math.max(0, st.offset - st.limit); loaders.stores(); });
$('st-next').addEventListener('click', () => { st.offset += st.limit; loaders.stores(); });
$('st-sort').addEventListener('change', () => {
  st.sort = $('st-sort').value;
  renderStoresList();
});

function storeStatusBadge(s) {
  if (s.orders_7d > 0) return el('span', { class: 'badge good', text: 'Tích cực' });
  if (s.last_order_at) return el('span', { class: 'badge warn', text: 'Ngủ' });
  return el('span', { class: 'badge', text: 'Chưa bán' });
}

// Danh sách quán: chỉ hiện nhãn khi đáng chú ý (khoá / Pro)
function storePlanMini(s) {
  if (s.status === 'locked') return el('span', { class: 'badge bad', text: '🔒 Khoá' });
  if (s.plan === 'pro') return el('span', { class: 'badge info', text: 'Pro' });
  return null;
}

function sortedStores(rows) {
  if (!st.sort || st.sort === 'default') return rows.slice();
  const [field, dir] = st.sort.split(':');
  const mul = dir === 'asc' ? 1 : -1;
  return rows.slice().sort((a, b) => {
    let va, vb;
    if (field === 'created_at' || field === 'last_order_at') {
      va = a[field] ? new Date(a[field]).getTime() : 0;
      vb = b[field] ? new Date(b[field]).getTime() : 0;
    } else {
      va = Number(a[field] || 0);
      vb = Number(b[field] || 0);
    }
    return (va - vb) * mul;
  });
}

function toggleStoreSort(field) {
  const cur = st.sort || 'default';
  const next = cur === `${field}:desc` ? `${field}:asc` : `${field}:desc`;
  st.sort = next;
  if ([...$('st-sort').options].some((o) => o.value === next)) {
    $('st-sort').value = next;
  }
  renderStoresList();
}

let confirmAction = null;
function askConfirm(title, desc, okLabel, onConfirm) {
  lastFocusEl = document.activeElement;
  $('confirm-title').textContent = title;
  $('confirm-desc').textContent = desc;
  $('confirm-ok').textContent = okLabel || 'Xác nhận';
  confirmAction = onConfirm;
  $('confirm-modal').hidden = false;
  $('confirm-ok').focus();
}
$('confirm-cancel').addEventListener('click', () => {
  closeConfirm();
  if (lastFocusEl) try { lastFocusEl.focus(); } catch { /* bỏ qua */ }
});
$('confirm-modal').addEventListener('click', (e) => {
  if (e.target === $('confirm-modal')) closeConfirm();
});
$('confirm-ok').addEventListener('click', async () => {
  const fn = confirmAction;
  closeConfirm();
  if (fn) await fn();
});

function promptToggleTestStore(s, triggerEl) {
  const nextTest = !s.is_test;
  const storeName = s.name || '(chưa đặt tên)';
  askConfirm(
    nextTest ? 'Đánh dấu quán thử?' : 'Bỏ đánh dấu quán thử?',
    nextTest
      ? `Quán "${storeName}" sẽ được xếp vào nhóm quán thử và loại khỏi các thống kê mặc định.`
      : `Quán "${storeName}" sẽ trở lại danh sách quán thật trong báo cáo tổng quan.`,
    nextTest ? 'Đánh dấu quán thử' : 'Bỏ đánh dấu',
    async () => {
      try {
        await rpc('admin_set_test_store_v1', { p_store: s.id, p_is_test: nextTest });
        toast(nextTest ? 'Đã đánh dấu quán thử' : 'Đã bỏ đánh dấu quán thử');
        if ( !$('drawer').hidden ) closeDrawer();
        loaders.stores();
      } catch {
        toast('Không lưu được thay đổi');
      } finally {
        if (triggerEl && document.body.contains(triggerEl)) triggerEl.focus();
      }
    },
  );
}

function jumpToStoreBoom(s) {
  if (!$('drawer').hidden) closeDrawer();
  bm.store = { id: s.id, name: s.name || s.store_code || 'Quán' };
  bm.offset = 0;
  showTab('boom');
}

function openDrawerPanel(titleText, bodyNodes, triggerEl, opts = {}) {
  if (triggerEl) lastFocusEl = triggerEl;
  const left = clear($('drawer-head-left'));
  if (opts.onBack) {
    left.append(el('button', {
      type: 'button',
      class: 'btn small',
      text: '← Quay lại',
      onclick: opts.onBack,
    }));
  }
  left.append(el('h2', { id: 'drawer-title', text: titleText }));

  const nav = clear($('drawer-nav'));
  const navItems = (opts.navNodes || []).filter(Boolean);
  if (navItems.length) {
    nav.append(...navItems);
    nav.hidden = false;
  } else {
    nav.hidden = true;
  }

  clear($('drawer-body')).append(...bodyNodes.filter(Boolean));
  $('drawer').hidden = false;
  document.body.classList.add('drawer-open');
  if (!opts.keepFocus) $('drawer-close').focus();
}

// ── Hồ sơ quán chi tiết + thao tác quản trị (đợt 1, 27/10) ──────────────────
const fmtMoney = (n) => `${fmtN(Math.round(Number(n || 0)))}đ`;
// 714.484.380 → "714tr"; 1.250.000.000 → "1,3 tỷ"; dưới 1 triệu → "850k"
function fmtMoneyShort(n) {
  const v = Number(n || 0);
  const f = (x) => x.toLocaleString('vi-VN', { maximumFractionDigits: x < 10 ? 1 : 0 });
  if (Math.abs(v) >= 1e9) return `${f(v / 1e9)} tỷ`;
  if (Math.abs(v) >= 1e6) return `${f(v / 1e6)}tr`;
  if (Math.abs(v) >= 1e3) return `${f(v / 1e3)}k`;
  return fmtN(v);
}
const ADMIN_ERR = {
  BAD_DAYS: 'Số ngày phải từ 1 đến 365.',
  PLAN_NOT_TRIAL: 'Quán đang dùng gói Pro — đổi về Free trước khi gia hạn dùng thử.',
  BAD_ENDS_AT: 'Ngày hết hạn phải sau hôm nay (tối đa 10 năm).',
  BAD_AMOUNT: 'Số tiền không hợp lệ — chỉ gõ số, ví dụ 1500000.',
  BAD_PLAN: 'Gói không hợp lệ.',
  NOTE_TOO_LONG: 'Ghi chú tối đa 500 ký tự.',
  REASON_REQUIRED: 'Cần ghi lý do khoá (ít nhất 3 ký tự).',
  NO_CHANGE: 'Quán đã ở trạng thái này rồi.',
  NOT_FOUND: 'Không tìm thấy quán.',
  BAD_BODY: 'Ghi chú không được để trống (tối đa 2000 ký tự).',
  BAD_DATE: 'Ngày hẹn không hợp lệ.',
  TOO_LONG: 'Tối đa 300 ký tự.',
};
const adminErrText = (err) => ADMIN_ERR[err && err.message] || 'Không lưu được, vui lòng thử lại.';
const isAuthErr = (err) => err && ['NO_TOKEN', 'UNAUTHORIZED', 'FORBIDDEN'].includes(err.message);

const MODULE_NAMES = {
  pos: 'Bán hàng', table: 'Bàn', kitchen: 'Bếp', bill_printer: 'In hoá đơn', qr_order: 'QR gọi món',
  kho: 'Kho', kho_pro: 'Kho chuyên nghiệp', finance: 'Thu chi', report: 'Báo cáo', chain: 'Báo cáo chuỗi',
  loyalty: 'Khách hàng', staff: 'Nhân viên', chamcong: 'Chấm công', tinhluong: 'Lương', kay_ops: 'Vận hành',
  log_viewer: 'Nhật ký',
};
const ACTION_NAMES = { extend_trial: 'Gia hạn dùng thử', set_plan: 'Đổi gói', lock: 'Khoá quán', unlock: 'Mở khoá quán', self_extend: 'Chủ quán tự gia hạn 30 ngày', payment: 'Thu tiền gói Pro' };

function daysUntil(ts) {
  if (!ts) return null;
  return Math.ceil((new Date(ts).getTime() - Date.now()) / 86400000);
}

// Nhãn gói: Đang khoá / Pro (hạn) / Dùng thử (hạn) + cảnh báo hết hạn
function planBadges(s) {
  const out = [];
  if (s.status === 'locked') out.push(el('span', { class: 'badge bad', text: '🔒 Đang khoá' }));
  if (s.plan === 'pro') {
    out.push(el('span', { class: 'badge info', text: s.plan_ends_at ? `Pro đến ${fmtDay(s.plan_ends_at)}` : 'Pro không thời hạn' }));
  } else {
    out.push(el('span', { class: 'badge', text: s.trial_ends_at ? `Dùng thử đến ${fmtDay(s.trial_ends_at)}` : 'Dùng thử' }));
  }
  const left = daysUntil(s.plan === 'pro' ? s.plan_ends_at : s.trial_ends_at);
  if (s.notice === 'trial_expired') out.push(el('span', { class: 'badge bad', text: -left >= 1 ? `Hết thử ${fmtN(-left)} ngày` : 'Vừa hết thử' }));
  else if (s.notice === 'trial_ending') out.push(el('span', { class: 'badge warn', text: `Còn ${fmtN(Math.max(left, 0))} ngày thử` }));
  else if (s.notice === 'pro_expired') out.push(el('span', { class: 'badge bad', text: 'Pro đã hết hạn' }));
  else if (s.notice === 'pro_ending') out.push(el('span', { class: 'badge warn', text: `Pro còn ${fmtN(Math.max(left, 0))} ngày` }));
  return out;
}

function telLink(phone) {
  const digits = String(phone || '').replace(/[^\d+]/g, '');
  if (digits.length < 8) return el('b', { text: phone || '—' });
  return el('a', { class: 'link', href: `tel:${digits}`, text: phone });
}

function kv(label, value, sub) {
  return el('div', { class: 'kv-box' },
    el('span', { text: label }),
    el('b', { text: value }),
    sub ? el('small', { class: 'muted', text: sub }) : null,
  );
}

function section(title, open, ...kids) {
  return el('details', { class: 'card prof-section', open: open || undefined },
    el('summary', { class: 'prof-summary', text: title }),
    el('div', { class: 'prof-body' }, ...kids),
  );
}

function snapshotText(x) {
  if (!x) return '—';
  const STATUS_VI = { locked: 'đang khoá', trial: 'dùng thử', active: 'đang dùng' };
  const parts = [x.plan === 'pro' ? 'Pro' : 'Free', STATUS_VI[x.status] || x.status];
  if (x.plan === 'pro') parts.push(x.plan_ends_at ? `đến ${fmtDay(x.plan_ends_at)}` : 'không thời hạn');
  else if (x.trial_ends_at) parts.push(`thử đến ${fmtDay(x.trial_ends_at)}`);
  return parts.join(' · ');
}

// ── Hộp thoại nhập liệu dùng chung ──
let formSubmit = null;
let formGen = 0; // tăng mỗi lần mở / đóng: kết quả lưu của hộp cũ về muộn không đụng hộp mới (QC 27/10)
let formReturnFocus = null;
let formReturnStore = null; // quán của nút đã mở hộp — nút bị vẽ lại thì tìm lại theo quán
let lastReload = Promise.resolve();
function closeForm() {
  formGen += 1;
  formSticky = false;
  $('form-modal').hidden = true;
  clear($('form-body'));
  $('form-error').hidden = true;
  formSubmit = null;
}

// fields: [{ name, label, type: text|number|date|textarea|select, value, options:[[v, label]], min, max, maxlength, hint }]
// fields: … type checkbox → giá trị '1' khi tick, '' khi không; extra: nút / khối hiện thêm dưới các ô
// sticky: không có nút Huỷ, không đóng khi bấm nền / Esc (vd hộp hiện mật khẩu tạm 1 lần)
let formSticky = false;
function openForm({ title, desc, fields, okLabel, danger, onSubmit, extra, sticky }) {
  formSticky = !!sticky;
  $('form-cancel').hidden = formSticky;
  formGen += 1;
  formReturnFocus = document.activeElement;
  const card = formReturnFocus && formReturnFocus.closest ? formReturnFocus.closest('[data-store-id]') : null;
  formReturnStore = card ? card.getAttribute('data-store-id') : null;
  $('form-title').textContent = title;
  $('form-desc').textContent = desc || '';
  $('form-desc').hidden = !desc;
  $('form-error').hidden = true;
  const ok = $('form-ok');
  ok.textContent = okLabel || 'Lưu';
  ok.disabled = false;
  ok.className = `btn ${danger ? 'danger' : 'primary'}`;
  const body = clear($('form-body'));
  for (const f of fields) {
    const id = `ff-${f.name}`;
    let input;
    if (f.type === 'checkbox') {
      input = el('input', { id, name: f.name, type: 'checkbox' });
      input.checked = !!f.value;
      body.append(el('label', { class: 'check-field', for: id, 'data-field': f.name }, input, el('span', { text: f.label })));
      continue;
    }
    if (f.type === 'textarea') {
      input = el('textarea', { id, name: f.name, maxlength: f.maxlength, rows: 3 });
      input.value = f.value || '';
    } else if (f.type === 'select') {
      input = el('select', { id, name: f.name }, ...f.options.map(([v, l]) => el('option', { value: v, text: l })));
      input.value = f.value || f.options[0][0];
    } else {
      input = el('input', { id, name: f.name, type: f.type || 'text', min: f.min, max: f.max, maxlength: f.maxlength,
                            inputmode: f.type === 'number' ? 'numeric' : undefined, autocomplete: 'off' });
      input.value = f.value == null ? '' : String(f.value);
    }
    if (f.onChange) input.addEventListener('change', () => f.onChange(input.value));
    body.append(el('div', { class: 'field', 'data-field': f.name },
      el('label', { for: id, text: f.label }),
      input,
      f.hint ? el('small', { class: 'muted', text: f.hint }) : null,
    ));
  }
  if (extra) body.append(...extra.filter(Boolean));
  formSubmit = onSubmit;
  $('form-modal').hidden = false;
  const first = body.querySelector('input, select, textarea');
  if (first) first.focus();
}

function formValues() {
  const out = {};
  for (const n of $('form-body').querySelectorAll('input, select, textarea')) {
    if (!n.name) continue;
    out[n.name] = n.type === 'checkbox' ? (n.checked ? '1' : '') : n.value.trim();
  }
  return out;
}

$('form-card').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  if (!formSubmit) return;
  const mine = formGen;
  const ok = $('form-ok');
  ok.disabled = true;
  $('form-error').hidden = true;
  try {
    const msg = await formSubmit(formValues());
    if (mine !== formGen) return; // hộp đã đóng / mở hộp khác trong lúc chờ
    if (msg) {
      $('form-error').textContent = msg;
      $('form-error').hidden = false;
      return;
    }
    closeForm();
    await lastReload.catch(() => {});
    if (mine + 1 === formGen) restoreFocusAfterForm(); // không mở hộp khác trong lúc chờ
  } finally {
    if (mine === formGen) ok.disabled = false;
  }
});
// Trả con trỏ: về nút đã mở hộp; nút đó bị vẽ lại thì về ngăn kéo / nút tên quán
function restoreFocusAfterForm() {
  let target = formReturnFocus && document.body.contains(formReturnFocus) ? formReturnFocus : null;
  if (!target && !$('drawer').hidden) target = $('drawer-close');
  if (!target && formReturnStore) {
    target = [...document.querySelectorAll('[data-store-id] .st-name-btn')]
      .find((b) => b.closest('[data-store-id]').getAttribute('data-store-id') === formReturnStore) || null;
  }
  formReturnFocus = null;
  formReturnStore = null;
  if (target) try { target.focus(); } catch { /* bỏ qua */ }
}
$('form-cancel').addEventListener('click', () => { closeForm(); restoreFocusAfterForm(); });
$('form-modal').addEventListener('click', (e) => { if (e.target === $('form-modal') && !formSticky) { closeForm(); restoreFocusAfterForm(); } });

// Ngày YYYY-MM-DD theo giờ Việt Nam (quản trị ở múi giờ khác vẫn đúng "hôm nay" của quán)
const VN_DAY = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Ho_Chi_Minh', year: 'numeric', month: '2-digit', day: '2-digit' });
const isoDay = (d) => VN_DAY.format(d);
const vnToday = () => isoDay(new Date());
const plusDays = (n) => isoDay(new Date(Date.now() + n * 86400000));
// Ngày nhập (YYYY-MM-DD) → cuối ngày giờ Việt Nam
const endOfVnDay = (v) => (/^\d{4}-\d{2}-\d{2}$/.test(v) ? `${v}T23:59:59+07:00` : null);

// Sau mỗi thao tác: tải lại hồ sơ đang mở + danh sách đang xem
let profileStoreId = null;
function afterAdminChange() {
  const jobs = [];
  if (profileStoreId && !$('drawer').hidden) jobs.push(loadStoreProfile(profileStoreId, null, true));
  const tab = location.hash.slice(1);
  if (tab === 'plans') jobs.push(loaders.plans());
  else if (tab === 'stores') jobs.push(loaders.stores());
  lastReload = Promise.all(jobs);
}

// p_note / p_reason chỉ gửi khi có chữ
const nn = (v) => (v ? v : null);

function actExtendTrial(s) {
  openForm({
    title: `Gia hạn dùng thử — ${s.name || 'quán'}`,
    desc: `Hiện tại: ${s.trial_ends_at ? `dùng thử đến ${fmtDay(s.trial_ends_at)}` : 'chưa có hạn'}. Số ngày cộng thêm tính từ hạn cũ (nếu đã hết hạn thì tính từ hôm nay).`,
    fields: [
      { name: 'days', label: 'Cộng thêm (ngày)', type: 'number', value: 14, min: 1, max: 365 },
      { name: 'note', label: 'Ghi chú (tuỳ chọn)', type: 'textarea', maxlength: 500 },
    ],
    okLabel: 'Gia hạn',
    onSubmit: async (v) => {
      const days = Number(v.days);
      if (!Number.isInteger(days) || days < 1 || days > 365) return ADMIN_ERR.BAD_DAYS;
      try {
        await rpc('admin_store_extend_trial_v1', { p_store: s.id, p_days: days, p_note: nn(v.note) });
      } catch (err) { return isAuthErr(err) ? null : adminErrText(err); }
      toast(`Đã gia hạn thêm ${days} ngày`);
      afterAdminChange();
      return null;
    },
  });
}

function actSetPlan(s) {
  const toPro = s.plan !== 'pro';
  openForm({
    title: `Đổi gói — ${s.name || 'quán'}`,
    desc: `Hiện tại: ${snapshotText(s)}.`,
    fields: [
      { name: 'plan', label: 'Gói mới', type: 'select', value: toPro ? 'pro' : 'free',
        options: [['pro', 'Pro (trả phí)'], ['free', 'Free (về dùng thử)']],
        onChange: (val) => {
          for (const n of ['ends', 'amount']) {
            const box = $('form-body').querySelector(`[data-field="${n}"]`);
            if (box) box.hidden = val !== 'pro';
          }
        } },
      { name: 'ends', label: 'Pro đến hết ngày (để trống = không thời hạn)', type: 'date',
        value: s.plan === 'pro' && s.plan_ends_at ? isoDay(new Date(s.plan_ends_at)) : plusDays(30), min: plusDays(1) },
      { name: 'amount', label: 'Số tiền đã thu (tuỳ chọn)', type: 'text', hint: 'Ví dụ 1.500.000 — chỉ cần gõ số' },
      { name: 'note', label: 'Ghi chú (tuỳ chọn)', type: 'textarea', maxlength: 500 },
    ],
    okLabel: 'Lưu gói',
    onSubmit: async (v) => {
      const pro = v.plan === 'pro';
      let ends = null;
      if (pro && v.ends) {
        ends = endOfVnDay(v.ends);
        if (!ends) return ADMIN_ERR.BAD_ENDS_AT;
      }
      let amount = null;
      if (pro && v.amount !== '') {
        const digits = v.amount.replace(/[.,\s]|đ$|vnd$/gi, '');
        amount = /^\d{1,11}$/.test(digits) ? Number(digits) : NaN;
        if (!Number.isInteger(amount)) return ADMIN_ERR.BAD_AMOUNT;
      }
      try {
        await rpc('admin_store_set_plan_v1', { p_store: s.id, p_plan: v.plan, p_ends_at: ends, p_amount_vnd: amount, p_note: nn(v.note) });
      } catch (err) { return isAuthErr(err) ? null : adminErrText(err); }
      toast(pro ? 'Đã chuyển sang gói Pro' : 'Đã chuyển về gói Free');
      afterAdminChange();
      return null;
    },
  });
  if (!toPro) {
    for (const n of ['ends', 'amount']) {
      const box = $('form-body').querySelector(`[data-field="${n}"]`);
      if (box) box.hidden = true;
    }
  }
}

function actToggleLock(s) {
  const locking = s.status !== 'locked';
  openForm({
    title: locking ? `Khoá quán — ${s.name || 'quán'}` : `Mở khoá quán — ${s.name || 'quán'}`,
    desc: locking
      ? 'Mọi máy của quán ngừng bán hàng, xem báo cáo và đọc / ghi dữ liệu ngay; app hiện màn "Quán đang tạm khoá". Mở khoá lại bất cứ lúc nào.'
      : 'Quán dùng lại bình thường ngay (máy đang mở app bấm "Kiểm tra lại").',
    fields: [
      { name: 'reason', label: locking ? 'Lý do khoá (bắt buộc, chỉ quản trị thấy)' : 'Ghi chú (tuỳ chọn)', type: 'textarea', maxlength: 500 },
    ],
    okLabel: locking ? 'Khoá quán' : 'Mở khoá',
    danger: locking,
    onSubmit: async (v) => {
      if (locking && v.reason.length < 3) return ADMIN_ERR.REASON_REQUIRED;
      try {
        await rpc('admin_store_set_locked_v1', { p_store: s.id, p_locked: locking, p_reason: nn(v.reason) });
      } catch (err) { return isAuthErr(err) ? null : adminErrText(err); }
      toast(locking ? 'Đã khoá quán' : 'Đã mở khoá quán');
      afterAdminChange();
      return null;
    },
  });
}

function actAddNote(s) {
  openForm({
    title: `Ghi chú chăm sóc — ${s.name || 'quán'}`,
    fields: [
      { name: 'body', label: 'Nội dung (đã gọi, khách cần gì…)', type: 'textarea', maxlength: 2000 },
      { name: 'follow', label: 'Hẹn gọi lại ngày (tuỳ chọn)', type: 'date', min: vnToday() },
    ],
    okLabel: 'Lưu ghi chú',
    onSubmit: async (v) => {
      if (!v.body) return ADMIN_ERR.BAD_BODY;
      try {
        await rpc('admin_store_note_add_v1', { p_store: s.id, p_body: v.body, p_follow_up_on: v.follow || null });
      } catch (err) { return isAuthErr(err) ? null : adminErrText(err); }
      toast('Đã lưu ghi chú');
      afterAdminChange();
      return null;
    },
  });
}

async function toggleNoteDone(note, done) {
  try {
    await rpc('admin_store_note_done_v1', { p_id: note.id, p_done: done });
    toast(done ? 'Đã đánh dấu xong' : 'Đã mở lại hẹn gọi');
    afterAdminChange();
  } catch (err) {
    if (!isAuthErr(err)) toast('Không lưu được thay đổi');
  }
}

function openStoreDetail(s, triggerEl) {
  loadStoreProfile(s.id, triggerEl, false, s);
}

async function loadStoreProfile(storeId, triggerEl, keep, row) {
  activeTurnShortcut = null;
  profileStoreId = storeId;
  if (!keep) {
    const sk = el('div', { class: 'kv-grid' });
    showSkeletons(sk, 6, 'h-row');
    openDrawerPanel((row && row.name) || 'Hồ sơ quán', [sk], triggerEl);
  }
  let d;
  try {
    d = await rpc('admin_store_detail_v1', { p_store: storeId });
  } catch (err) {
    if (isAuthErr(err) || profileStoreId !== storeId || $('drawer').hidden) return;
    clear($('drawer-body')).append(errorBox('Không tải được hồ sơ quán.', () => loadStoreProfile(storeId, null, true)));
    return;
  }
  if (profileStoreId !== storeId || $('drawer').hidden) return;
  renderStoreProfile(d);
}

function renderStoreProfile(d) {
  const s = d.store;
  const sales = d.sales || {};
  const boom = d.boom || {};
  const sess = d.sessions || {};
  $('drawer-title').textContent = s.name || '(chưa đặt tên)';
  const avg = Number(sales.orders_30d) ? Number(sales.revenue_30d) / Number(sales.orders_30d) : 0;

  const actions = el('div', { class: 'review-actions prof-actions' },
    s.plan !== 'pro' ? el('button', { type: 'button', class: 'btn primary', text: 'Gia hạn dùng thử', onclick: () => actExtendTrial(s) }) : null,
    el('button', { type: 'button', class: 'btn', text: 'Đổi gói', onclick: () => actSetPlan(s) }),
    el('button', { type: 'button', class: 'btn', text: 'Ghi chú', onclick: () => actAddNote(s) }),
    el('button', { type: 'button', class: 'btn', text: 'Hội thoại Boom', onclick: () => jumpToStoreBoom(s) }),
    el('button', { type: 'button', class: 'btn', text: s.is_test ? 'Bỏ quán thử' : 'Quán thử',
                   onclick: (ev) => promptToggleTestStore(s, ev.currentTarget) }),
    el('button', { type: 'button', class: `btn ${s.status === 'locked' ? '' : 'danger'}`,
                   text: s.status === 'locked' ? 'Mở khoá quán' : 'Khoá quán', onclick: () => actToggleLock(s) }),
  );

  const owner = d.owner;
  const ownerCard = el('div', { class: 'card prof-owner' },
    el('div', { class: 'prof-owner-row' },
      el('div', {},
        el('span', { class: 'muted small', text: 'Chủ quán' }),
        el('b', { class: 'prof-owner-name', text: (owner && owner.name) || '—' }),
      ),
      el('div', { class: 'prof-owner-phone' }, owner && owner.phone ? telLink(owner.phone) : el('span', { class: 'muted', text: 'Không có SĐT' })),
    ),
    el('div', { class: 'small muted', text: `Tạo quán ${fmtDay(s.created_at)} · Mã ${s.store_code || '—'}` }),
  );

  const kpis = el('div', { class: 'kv-grid' },
    kv('Doanh số 7 ngày', fmtMoney(sales.revenue_7d), `${fmtN(sales.orders_7d)} đơn`),
    kv('Doanh số 30 ngày', fmtMoney(sales.revenue_30d), `${fmtN(sales.orders_30d)} đơn · TB ${fmtMoney(avg)}/đơn`),
    kv('Đơn gần nhất', ago(sales.last_order_at), sales.last_order_at ? fmtD(sales.last_order_at) : ''),
    kv('Món trong thực đơn', `${fmtN(d.menu_items)} món`),
    kv('Nhân viên (PIN)', `${fmtN(d.pin_staff && d.pin_staff.active)} đang làm`, `tổng ${fmtN(d.pin_staff && d.pin_staff.total)}`),
    kv('Tài khoản đăng nhập', fmtN((d.accounts || []).length), `${fmtN(sess.active)} phiên đang sống`),
    kv('Thiết bị (30 ngày)', `${fmtN((d.devices || []).length)} máy`),
    kv('Lỗi app (14 ngày)', fmtN(d.errors_14d)),
    kv('Boom (30 ngày)', `${fmtN(boom.turns_30d)} lượt`, `$${Number(boom.cost_usd_30d || 0).toFixed(4)}`),
  );

  const chartBox = el('div', { class: 'chart chart-box' });
  const chartMeta = el('div', { class: 'chart-readout' });
  const salesCard = el('div', { class: 'card' },
    el('div', { class: 'card-head' }, el('h3', { text: 'Đơn & doanh số 30 ngày' }), chartMeta),
    chartBox,
  );
  renderChart(chartBox, chartMeta, (d.sales_by_day || []).map((p) => ({ ...p, n: Number(p.orders || 0) })), {
    ariaLabel: 'Biểu đồ số đơn hoàn thành theo ngày trong 30 ngày qua',
    xAxisLabel: (p, isLast) => (isLast ? 'Hôm nay' : fmtShortDay(p.day)),
    tooltipLabel: (p, isLast) => (isLast ? `Hôm nay ${fmtShortDay(p.day)}` : `Ngày ${fmtShortDay(p.day)}`),
    valueText: (p) => `${fmtN(p.n)} đơn · ${fmtMoney(p.revenue)}`,
    summaryText: (sum) => `${fmtN(sum)} đơn trong 30 ngày`,
    emptyNode: () => emptyBox('Chưa có đơn trong 30 ngày', 'Quán chưa phát sinh đơn hoàn thành nào.'),
  });

  const mods = (d.modules || []).filter((m) => typeof m === 'string');
  const modBox = el('div', { class: 'turn-badges' },
    mods.length ? mods.map((m) => el('span', { class: 'badge', text: MODULE_NAMES[m] || m })) : el('span', { class: 'muted small', text: 'Chưa lưu cấu hình module' }));

  const notes = d.notes || [];
  const notesBody = notes.length
    ? el('div', { class: 'timeline' }, notes.map((n) => {
      const due = n.follow_up_on && !n.done_at;
      const overdue = due && n.follow_up_on <= vnToday();
      return el('div', { class: 'tl-item' },
        el('div', { class: 'tl-meta' },
          el('span', { text: fmtD(n.created_at) }),
          el('span', { text: n.author || '' }),
          n.follow_up_on ? el('span', { class: `badge ${n.done_at ? 'good' : overdue ? 'bad' : 'warn'}`,
                                        text: n.done_at ? `Đã gọi (hẹn ${fmtDay(n.follow_up_on)})` : `Hẹn gọi ${fmtDay(n.follow_up_on)}` }) : null,
        ),
        el('div', { class: 'tl-detail prof-pre', text: n.body }),
        n.follow_up_on ? el('button', { type: 'button', class: 'btn small', text: n.done_at ? 'Mở lại hẹn' : 'Đánh dấu đã gọi',
                                        onclick: () => toggleNoteDone(n, !n.done_at) }) : null,
      );
    }))
    : el('p', { class: 'muted small', text: 'Chưa có ghi chú. Bấm "Ghi chú" để ghi lại cuộc gọi, nhu cầu của khách, ngày hẹn gọi lại.' });

  const acts = d.actions || [];
  const actsBody = acts.length
    ? el('div', { class: 'timeline' }, acts.map((a) => el('div', { class: 'tl-item' },
      el('div', { class: 'tl-meta' }, el('span', { text: fmtD(a.created_at) }), el('span', { text: a.author || '' }),
        a.amount_vnd != null ? el('span', { class: 'badge good', text: `Thu ${fmtMoney(a.amount_vnd)}` }) : null),
      el('div', { class: 'tl-title', text: ACTION_NAMES[a.action] || a.action }),
      el('div', { class: 'tl-detail', text: `${snapshotText(a.before)} → ${snapshotText(a.after)}` }),
      a.note ? el('div', { class: 'tl-detail prof-pre', text: `“${a.note}”` }) : null,
    )))
    : el('p', { class: 'muted small', text: 'Chưa có thao tác quản trị nào trên quán này.' });

  const accounts = d.accounts || [];
  const accBody = el('div', { class: 'prof-rows' }, accounts.length ? accounts.map((a) => el('div', { class: 'prof-row' },
    el('div', {}, el('b', { text: a.name || '(chưa đặt tên)' }),
      el('div', { class: 'small muted', text: `${a.is_owner ? 'Chủ quán' : (a.role || '—')} · vào ${fmtDay(a.joined)}` })),
    el('div', { class: 'prof-row-end' },
      a.phone ? telLink(a.phone) : null,
      a.phone ? el('button', { type: 'button', class: 'btn small', text: 'Hỗ trợ', onclick: (ev) => openAccountByPhone(a.phone, ev.currentTarget) }) : null),
  )) : el('p', { class: 'muted small', text: 'Chưa có tài khoản.' }));

  const devices = d.devices || [];
  const devBody = el('div', { class: 'prof-rows' }, devices.length ? devices.map((v) => el('div', { class: 'prof-row' },
    el('div', {}, el('b', { text: v.staff || 'Máy chưa rõ người dùng' }),
      el('div', { class: 'small muted code-text', text: `${String(v.device || '').slice(0, 8)}… · ${fmtN(v.logs)} nhật ký` })),
    el('div', { class: 'prof-row-end' },
      el('span', { class: 'small', text: ago(v.last_seen) }),
      Number(v.errors) ? el('span', { class: 'badge bad', text: `${fmtN(v.errors)} lỗi` }) : null),
  )) : el('p', { class: 'muted small', text: 'Không có máy nào ghi nhật ký trong 30 ngày.' }));

  const recent = sess.recent || [];
  const sessBody = el('div', { class: 'prof-rows' }, recent.length ? recent.map((r) => el('div', { class: 'prof-row' },
    el('div', {}, el('b', { text: r.user || '—' }),
      el('div', { class: 'small muted', text: `Đăng nhập ${fmtD(r.at)} · dùng gần nhất ${fmtD(r.last_used)}` })),
    el('span', { class: `badge ${r.live ? 'good' : ''}`, text: r.live ? 'Đang dùng' : 'Đã hết' }),
  )) : el('p', { class: 'muted small', text: 'Chưa có lần đăng nhập nào (máy cũ dùng vé không làm mới).' }));

  const errs = d.errors || [];
  const errBody = el('div', { class: 'prof-rows' }, errs.length ? errs.map((e) => el('div', { class: 'prof-err' },
    el('div', { class: 'tl-meta' }, el('span', { text: fmtD(e.at) }), el('span', { class: 'badge code', text: e.tag || '—' }),
      el('span', { text: e.staff || '' })),
    el('div', { class: 'prof-pre small', text: e.message || '' }),
  )) : el('p', { class: 'muted small', text: 'Không có lỗi trong 14 ngày. 👍' }));

  clear($('drawer-body')).append(
    el('div', { class: 'turn-badges' }, ...planBadges(s), s.is_test ? el('span', { class: 'badge bad', text: 'Quán thử' }) : null),
    actions,
    ownerCard,
    kpis,
    salesCard,
    section(`Ghi chú chăm sóc (${notes.length})`, true, notesBody),
    section(`Lịch sử thao tác quản trị (${acts.length})`, acts.length > 0, actsBody),
    section(`Module đang bật (${mods.length})`, false, modBox),
    section(`Tài khoản đăng nhập (${accounts.length})`, false, accBody),
    section(`Thiết bị 30 ngày (${devices.length})`, false, devBody),
    section('Lần đăng nhập gần đây', false, sessBody),
    section(`Lỗi app 14 ngày (${fmtN(d.errors_14d)})`, false, errBody),
  );
}

// ── Tab Gói & hạn dùng thử ────────────────────────────────────────────────────
const pl = { filter: 'all', search: '', offset: 0, limit: 30, rows: [], total: 0 };
const plMark = chipGroup('pl-filters', pl, () => loaders.plans());
let plTimer;
$('pl-search').addEventListener('input', () => {
  clearTimeout(plTimer);
  plTimer = setTimeout(() => {
    pl.search = $('pl-search').value.trim();
    pl.offset = 0;
    loaders.plans();
  }, 350);
});
$('pl-include-test').addEventListener('change', () => { pl.offset = 0; loaders.plans(); });
$('pl-refresh').addEventListener('click', () => loaders.plans());
$('pl-prev').addEventListener('click', () => { pl.offset = Math.max(0, pl.offset - pl.limit); loaders.plans(); });
$('pl-next').addEventListener('click', () => { pl.offset += pl.limit; loaders.plans(); });
let plContactDirty = false;
$('pl-contact').addEventListener('input', () => { plContactDirty = true; });
$('pl-contact-save').addEventListener('click', async () => {
  const btn = $('pl-contact-save');
  btn.disabled = true;
  try {
    await rpc('admin_platform_setting_set_v1', { p_key: 'plan_contact', p_value: $('pl-contact').value.trim() });
    plContactDirty = false;
    toast('Đã lưu câu liên hệ');
  } catch (err) {
    if (!isAuthErr(err)) toast(adminErrText(err));
  } finally {
    btn.disabled = false;
  }
});

function plKpi(value, label, filter, cls) {
  return el('button', {
    type: 'button',
    class: `kpi-sub-card pl-kpi ${cls || ''}${pl.filter === filter ? ' on' : ''}`,
    'aria-pressed': String(pl.filter === filter),
    onclick: () => { pl.filter = filter; pl.offset = 0; loaders.plans(); },
  }, el('div', { class: 'v', text: fmtN(value) }), el('div', { class: 'k', text: label }));
}

function renderPlanRow(s) {
  const nameBtn = el('button', { type: 'button', class: 'st-name-btn', text: s.name || '(chưa đặt tên)',
                                 onclick: (ev) => openStoreDetail(s, ev.currentTarget) });
  const follow = s.next_follow_up
    ? el('span', { class: `badge ${s.next_follow_up <= vnToday() ? 'bad' : 'warn'}`, text: `Hẹn gọi ${fmtDay(s.next_follow_up)}` })
    : null;
  return el('article', { class: 'turn-card pl-card', 'data-store-id': s.id },
    el('div', { class: 'turn-top' },
      el('div', { class: 'pl-head' },
        nameBtn,
        el('div', { class: 'st-cell-sub' },
          s.store_code ? el('span', { class: 'badge code', text: s.store_code }) : null,
          el('span', { text: `Chủ: ${s.owner_name || '—'}` }),
          s.owner_phone ? telLink(s.owner_phone) : null,
        ),
      ),
      el('div', { class: 'turn-badges' }, ...planBadges(s), follow, s.is_test ? el('span', { class: 'badge bad', text: 'Quán thử' }) : null),
    ),
    el('div', { class: 'small muted', text: `Đơn 7 ngày: ${fmtN(s.orders_7d)} · Đơn gần nhất: ${ago(s.last_order_at)} · Tạo ${fmtDay(s.created_at)}` }),
    s.last_note ? el('div', { class: 'small prof-pre pl-note', text: `📝 ${s.last_note}` }) : null,
    el('div', { class: 'st-row-actions pl-actions' },
      s.plan !== 'pro' ? el('button', { type: 'button', class: 'btn small', text: 'Gia hạn', onclick: () => actExtendTrial(s) }) : null,
      el('button', { type: 'button', class: 'btn small', text: 'Đổi gói', onclick: () => actSetPlan(s) }),
      el('button', { type: 'button', class: 'btn small', text: 'Ghi chú', onclick: () => actAddNote(s) }),
      el('button', { type: 'button', class: 'btn small', text: 'Hồ sơ', onclick: (ev) => openStoreDetail(s, ev.currentTarget) }),
    ),
  );
}

// ── Thu phí (cổng thu phí đợt A): đơn thanh toán, bảng giá, tài khoản nhận tiền ──
// Mã BIN Napas các ngân hàng phổ biến — kiểm lại trên app ngân hàng của công ty trước khi lưu.
const BANKS = [
  ['970436', 'Vietcombank'], ['970415', 'VietinBank'], ['970418', 'BIDV'], ['970405', 'Agribank'],
  ['970407', 'Techcombank'], ['970422', 'MB Bank'], ['970416', 'ACB'], ['970432', 'VPBank'],
  ['970423', 'TPBank'], ['970403', 'Sacombank'], ['970437', 'HDBank'], ['970441', 'VIB'],
  ['970443', 'SHB'], ['970426', 'MSB'], ['970448', 'OCB'], ['970440', 'SeABank'],
  ['970431', 'Eximbank'], ['970449', 'LPBank'],
];
const BILL_ERR = {
  BAD_BIN: 'Mã ngân hàng (BIN) phải đúng 6 chữ số.',
  BAD_ACCOUNT_NO: 'Số tài khoản chỉ gồm 4–19 chữ số.',
  BAD_ACCOUNT_NAME: 'Tên tài khoản: IN HOA KHÔNG DẤU, đúng như trên app ngân hàng (2–50 ký tự).',
  BAD_BANK_NAME: 'Thiếu tên ngân hàng.',
  BAD_PRICE: 'Giá phải từ 1.000đ đến 100.000.000đ.',
  BAD_AMOUNT: 'Số tiền không hợp lệ — chỉ gõ số, ví dụ 499000.',
  ALREADY_PAID: 'Đơn này đã xác nhận rồi.',
  AMOUNT_SHORT: 'Số tiền thiếu so với đơn — ghi lý do vào ô ghi chú (vd: đã thoả thuận giảm giá) rồi bấm lại.',
  NOT_PENDING: 'Đơn không còn ở trạng thái chờ.',
};
const billErr = (err) => BILL_ERR[err && err.message] || adminErrText(err);
const ORDER_STATUS = { pending: ['Đang chờ', 'warn'], paid: ['Đã trả', 'good'], cancelled: ['Đã huỷ', ''], expired: ['Quá 24 giờ', 'bad'] };
const bl = { filter: 'pending', search: '' };
let blTimer;

// "1.500.000" / "1,500,000 đ" → 1500000; sai → NaN
function parseVnd(v) {
  const digits = String(v || '').replace(/[.,\s]|đ$|vnd$/gi, '');
  return /^\d{1,11}$/.test(digits) ? Number(digits) : NaN;
}

function actMarkPaid(o) {
  openForm({
    title: `Xác nhận đã nhận tiền — ${o.code}`,
    desc: `${o.store_name || 'Quán'} · ${o.plan_name} · ${fmtMoney(o.amount_vnd)}${o.status === 'cancelled' ? ' (đơn đã huỷ — chỉ xác nhận nếu tiền thật sự đã vào)' : ''}. Chỉ bấm khi ĐÃ thấy tiền vào tài khoản công ty với nội dung ${o.code}. Gói Pro được cộng ${o.months} tháng ngay.`,
    fields: [
      { name: 'amount', label: 'Số tiền thực nhận', type: 'text', value: String(o.amount_vnd), hint: 'Ví dụ 499.000 — chỉ cần gõ số' },
      { name: 'note', label: 'Ghi chú (tuỳ chọn, vd mã giao dịch ngân hàng)', type: 'textarea', maxlength: 300 },
    ],
    okLabel: 'Xác nhận đã nhận tiền',
    onSubmit: async (v) => {
      const amount = parseVnd(v.amount);
      if (!Number.isInteger(amount) || amount <= 0) return BILL_ERR.BAD_AMOUNT;
      if (amount < o.amount_vnd && !v.note) return `Thiếu ${fmtMoney(o.amount_vnd - amount)} so với đơn. ${BILL_ERR.AMOUNT_SHORT}`;
      try {
        await rpc('admin_billing_mark_paid_v1', { p_order: o.id, p_amount_vnd: amount, p_note: nn(v.note) });
      } catch (err) { return isAuthErr(err) ? null : billErr(err); }
      toast(amount < o.amount_vnd ? `Đã xác nhận (thiếu ${fmtMoney(o.amount_vnd - amount)} so với đơn)` : 'Đã xác nhận, gói Pro đã gia hạn');
      afterAdminChange();
      return null;
    },
  });
}

function actCancelOrder(o) {
  askConfirm(`Huỷ đơn ${o.code}?`, 'Chủ quán sẽ cần tạo đơn mới nếu muốn thanh toán. Chỉ huỷ khi chắc chắn chưa có tiền vào cho mã này.',
    'Huỷ đơn', async () => {
      try {
        await rpc('admin_billing_cancel_order_v1', { p_order: o.id });
        toast('Đã huỷ đơn');
        afterAdminChange();
      } catch (err) {
        if (!isAuthErr(err)) toast(billErr(err));
      }
    });
}

function actSetBank(bank) {
  const known = bank && BANKS.some(([b]) => b === bank.bin);
  openForm({
    title: 'Tài khoản nhận tiền',
    desc: 'App vẽ mã VietQR theo tài khoản này. Tên tài khoản IN HOA KHÔNG DẤU, đúng như trên app ngân hàng.',
    fields: [
      { name: 'bank', label: 'Ngân hàng', type: 'select', value: bank ? (known ? bank.bin : 'other') : '970436',
        options: [...BANKS.map(([b, n]) => [b, `${n} (${b})`]), ['other', 'Ngân hàng khác…']],
        onChange: (val) => {
          for (const n of ['other_bin', 'other_name']) {
            const box = $('form-body').querySelector(`[data-field="${n}"]`);
            if (box) box.hidden = val !== 'other';
          }
        } },
      { name: 'other_bin', label: 'Mã BIN ngân hàng (6 số)', type: 'text', value: bank && !known ? bank.bin : '' },
      { name: 'other_name', label: 'Tên ngân hàng', type: 'text', value: bank && !known ? bank.bank_name : '' },
      { name: 'account_no', label: 'Số tài khoản', type: 'text', value: bank ? bank.account_no : '' },
      { name: 'account_name', label: 'Tên tài khoản', type: 'text', value: bank ? bank.account_name : '' },
    ],
    okLabel: 'Lưu tài khoản',
    onSubmit: async (v) => {
      const other = v.bank === 'other';
      const bin = other ? v.other_bin : v.bank;
      const name = other ? v.other_name : (BANKS.find(([b]) => b === v.bank) || [])[1];
      try {
        await rpc('admin_billing_set_bank_v1', { p_bin: bin, p_bank_name: name || '', p_account_no: v.account_no.replace(/\s/g, ''),
                                                  p_account_name: v.account_name });
      } catch (err) { return isAuthErr(err) ? null : billErr(err); }
      toast('Đã lưu tài khoản nhận tiền');
      afterAdminChange();
      return null;
    },
  });
  if (known || !bank) {
    for (const n of ['other_bin', 'other_name']) {
      const box = $('form-body').querySelector(`[data-field="${n}"]`);
      if (box) box.hidden = true;
    }
  }
}

function actSetPrice(p) {
  openForm({
    title: `Giá ${p.name}`,
    desc: 'Đơn đang chờ giữ giá lúc tạo; giá mới áp cho đơn tạo sau khi lưu.',
    fields: [
      { name: 'price', label: 'Giá (đồng)', type: 'text', value: String(p.price_vnd), hint: 'Ví dụ 499.000' },
      { name: 'active', label: 'Đang bán', type: 'select', value: p.active ? 'yes' : 'no', options: [['yes', 'Đang bán'], ['no', 'Ngưng bán']] },
    ],
    okLabel: 'Lưu giá',
    onSubmit: async (v) => {
      const price = parseVnd(v.price);
      if (!Number.isInteger(price)) return BILL_ERR.BAD_PRICE;
      try {
        await rpc('admin_billing_set_plan_v1', { p_code: p.code, p_price_vnd: price, p_active: v.active === 'yes' });
      } catch (err) { return isAuthErr(err) ? null : billErr(err); }
      toast('Đã lưu giá');
      afterAdminChange();
      return null;
    },
  });
}

function renderOrderRow(o) {
  const [label, cls] = ORDER_STATUS[o.status] || [o.status, ''];
  // đơn đã huỷ / quá hạn vẫn xác nhận được: khách có thể chuyển tiền rồi mới tạo đơn khác
  const canPay = o.status !== 'paid';
  return el('div', { class: 'prof-row bl-order', 'data-store-id': o.store_id },
    el('div', {},
      el('div', { class: 'turn-badges' },
        el('span', { class: 'badge code', text: o.code }),
        el('span', { class: `badge ${cls}`, text: label }),
        o.paid_source === 'admin' ? el('span', { class: 'badge', text: 'xác nhận tay' }) : null),
      el('b', { text: `${o.store_name || 'Quán'} · ${o.plan_name} · ${fmtMoney(o.amount_vnd)}` }),
      el('div', { class: 'small muted', text: o.status === 'paid'
        ? `Đã trả ${fmtD(o.paid_at)} · nhận ${fmtMoney(o.paid_amount_vnd)}${o.paid_note ? ` · ${o.paid_note}` : ''}`
        : `Tạo ${fmtD(o.created_at)} · hết hạn ${fmtD(o.expires_at)}` }),
    ),
    canPay ? el('div', { class: 'prof-row-end' },
      el('button', { type: 'button', class: 'btn small primary', text: 'Đã nhận tiền', onclick: () => actMarkPaid(o) }),
      o.status === 'pending' ? el('button', { type: 'button', class: 'btn small', text: 'Huỷ', onclick: () => actCancelOrder(o) }) : null,
    ) : null,
  );
}

async function loadBilling() {
  const box = $('bl-section');
  let d;
  try {
    d = await rpc('admin_billing_overview_v1', { p_filter: bl.filter, p_search: bl.search || null, p_limit: 200, p_offset: 0 });
  } catch (err) {
    if (isAuthErr(err)) return;
    clear(box).append(errorBox('Không tải được phần thu phí.', () => loadBilling()));
    return;
  }
  const chips = el('div', { class: 'chips', role: 'group', 'aria-label': 'Lọc đơn thanh toán' },
    ...[['pending', `Đang chờ (${fmtN(d.pending_count)})`], ['paid', 'Đã trả'], ['all', 'Tất cả']].map(([f, t]) =>
      el('button', { type: 'button', class: `chip${bl.filter === f ? ' on' : ''}`, 'aria-pressed': String(bl.filter === f), text: t,
                     onclick: () => { bl.filter = f; loadBilling(); } })));
  const search = el('input', { type: 'search', placeholder: 'Tìm mã đơn QN… hoặc tên quán', 'aria-label': 'Tìm đơn thanh toán' });
  search.value = bl.search;
  search.addEventListener('input', () => {
    clearTimeout(blTimer);
    blTimer = setTimeout(() => { bl.search = search.value.trim(); loadBilling().then(() => {
      const s2 = $('bl-section').querySelector('input[type="search"]');
      if (s2) { s2.focus(); s2.setSelectionRange(s2.value.length, s2.value.length); }
    }); }, 400);
  });
  const rows = d.rows || [];
  const bank = d.bank;
  clear(box).append(
    el('div', { class: 'card' },
      el('div', { class: 'card-head' },
        el('div', {},
          el('h3', { text: 'Thu phí — đơn thanh toán' }),
          el('p', { class: 'muted small', text: `30 ngày qua: ${fmtN(d.paid_30d_count)} đơn · ${fmtMoney(d.paid_30d_vnd)}. Thấy tiền vào với nội dung QN… thì bấm "Đã nhận tiền" (đợt sau SePay sẽ tự xác nhận).` }),
        ),
      ),
      el('div', { class: 'toolbar-inputs bl-toolbar' }, chips, el('div', { class: 'search-box' }, search)),
      rows.length ? el('div', { class: 'prof-rows' }, rows.map(renderOrderRow))
        : el('p', { class: 'muted small', text: bl.filter === 'pending' ? 'Không có đơn nào đang chờ.' : 'Chưa có đơn.' }),
    ),
    el('div', { class: 'grid2' },
      el('div', { class: 'card' },
        el('h3', { text: 'Bảng giá' }),
        el('div', { class: 'prof-rows' }, (d.plans || []).map((p) => el('div', { class: 'prof-row' },
          el('div', {}, el('b', { text: p.name }),
            el('div', { class: 'small muted', text: `${fmtMoney(p.price_vnd)}${p.active ? '' : ' · ngưng bán'}` })),
          el('button', { type: 'button', class: 'btn small', text: 'Sửa', onclick: () => actSetPrice(p) }),
        ))),
      ),
      el('div', { class: 'card' },
        el('h3', { text: 'Tài khoản nhận tiền' }),
        bank
          ? el('div', { class: 'prof-rows' },
              el('div', { class: 'prof-row' }, el('div', {},
                el('b', { text: `${bank.bank_name} · ${bank.account_no}` }),
                el('div', { class: 'small muted', text: bank.account_name }))))
          : el('p', { class: 'small', text: 'Chưa có — chủ quán chưa thanh toán được cho tới khi lưu tài khoản.' }),
        el('div', { class: 'review-actions' },
          el('button', { type: 'button', class: `btn ${bank ? '' : 'primary'}`, text: bank ? 'Sửa tài khoản' : 'Nhập tài khoản', onclick: () => actSetBank(bank) })),
      ),
    ),
  );
}

loaders.plans = async () => {
  plMark();
  const errBox = clear($('pl-error'));
  errBox.hidden = true;
  if (!pl.rows.length) showSkeletons($('pl-list'), 4, 'h-row');
  const inclTest = $('pl-include-test').checked;
  try {
    const [o, d] = await Promise.all([
      rpc('admin_plan_overview_v1', { p_include_test: inclTest }),
      rpc('admin_plan_list_v1', { p_filter: pl.filter, p_search: pl.search || null, p_include_test: inclTest,
                                  p_limit: pl.limit, p_offset: pl.offset }),
    ]);
    clear($('pl-kpis')).append(
      plKpi(o.follow_ups_due, 'Cần gọi hôm nay', 'follow_up', Number(o.follow_ups_due) ? 'bad' : ''),
      plKpi(o.trial_ending, 'Sắp hết thử (≤ 3 ngày)', 'trial_ending', 'warn'),
      plKpi(o.trial_expired, 'Đã hết dùng thử', 'trial_expired', 'bad'),
      plKpi(o.pro, 'Gói Pro', 'pro', 'info'),
      plKpi(Number(o.pro_ending) + Number(o.pro_expired), 'Pro sắp / đã hết', 'pro_due', 'warn'),
      plKpi(o.locked, 'Đang khoá', 'locked', ''),
    );
    if (!plContactDirty) $('pl-contact').value = o.contact || '';
    pl.rows = d.rows || [];
    pl.total = Number(d.total || 0);
    $('pl-total').textContent = `${fmtN(pl.total)} quán · thu 30 ngày ${fmtMoney(o.revenue_vnd_30d)}`;
    const list = clear($('pl-list'));
    if (!pl.rows.length) list.append(emptyBox('Không có quán nào', 'Thử đổi bộ lọc hoặc từ khoá tìm kiếm.'));
    else list.append(...pl.rows.map(renderPlanRow));
    $('pl-page').textContent = pl.total ? `${fmtN(pl.offset + 1)}–${fmtN(Math.min(pl.offset + pl.limit, pl.total))} / ${fmtN(pl.total)}` : '0 / 0';
    $('pl-prev').disabled = pl.offset === 0;
    $('pl-next').disabled = pl.offset + pl.limit >= pl.total;
    await loadBilling();
  } catch (err) {
    if (isAuthErr(err)) return;
    clear($('pl-list'));
    errBox.hidden = false;
    errBox.append(errorBox('Không tải được danh sách gói.', () => loaders.plans()));
  }
};

function sortableTh(label, field, numeric = false) {
  const [curField, curDir] = (st.sort || '').split(':');
  const isAct = curField === field;
  const arrow = isAct ? (curDir === 'asc' ? ' ↑' : ' ↓') : ' ↕';
  const ariaSort = isAct ? (curDir === 'asc' ? 'ascending' : 'descending') : 'none';
  return el('th', { scope: 'col', class: numeric ? 'num-col' : '', 'aria-sort': ariaSort },
    el('button', {
      type: 'button',
      class: `th-sort${isAct ? ' active' : ''}`,
      text: `${label}${arrow}`,
      onclick: () => toggleStoreSort(field),
    }),
  );
}

function renderStoresList() {
  const list = clear($('st-list'));
  const rows = sortedStores(st.rows);
  if (!rows.length) {
    list.append(emptyBox('Không tìm thấy quán nào', 'Thử đổi bộ lọc trạng thái hoặc từ khoá tìm kiếm.'));
    return;
  }

  // 1. Bảng dính tiêu đề cho máy tính (>= 1024px)
  const tbody = el('tbody', {});
  for (const s of rows) {
    const nameBtn = el('button', {
      type: 'button',
      class: 'st-name-btn',
      text: s.name || '(chưa đặt tên)',
      onclick: (ev) => openStoreDetail(s, ev.currentTarget),
    });
    tbody.append(el('tr', { 'data-store-id': s.id },
      el('td', {},
        nameBtn,
        el('div', { class: 'st-cell-sub' },
          s.store_code ? el('span', { class: 'badge code', text: s.store_code }) : null,
          el('span', { text: `Chủ: ${s.owner_name || '—'}` }),
          el('span', { text: `· Gói ${s.plan || '—'}` }),
        ),
      ),
      el('td', {},
        el('div', { class: 'turn-badges' },
          storeStatusBadge(s),
          storePlanMini(s),
          s.is_test ? el('span', { class: 'badge bad', text: 'Quán thử' }) : null,
        ),
      ),
      el('td', { class: 'num-col' },
        el('strong', { text: fmtN(s.orders_7d) }),
        el('div', { class: 'small muted', text: `30N: ${fmtN(s.orders_30d)}` }),
      ),
      el('td', {},
        el('span', { text: ago(s.last_order_at) }),
        s.last_order_at ? el('div', { class: 'small muted num', text: fmtDay(s.last_order_at) }) : null,
      ),
      el('td', { class: 'num-col' },
        el('strong', { text: `${fmtN(s.menu_items)} món` }),
        el('div', { class: 'small muted', text: `NV ${s.staff_owner}/${s.staff_manager}/${s.staff_other} · ${fmtN(s.devices)} máy` }),
      ),
      el('td', { class: 'num' }, fmtDay(s.created_at)),
      el('td', {},
        el('div', { class: 'st-row-actions' },
          el('button', { type: 'button', class: 'btn small', text: 'Boom', title: 'Xem hội thoại Boom của quán', onclick: () => jumpToStoreBoom(s) }),
          el('button', {
            type: 'button',
            class: 'btn small',
            text: s.is_test ? 'Bỏ thử' : 'Quán thử',
            onclick: (ev) => promptToggleTestStore(s, ev.currentTarget),
          }),
        ),
      ),
    ));
  }

  const tableWrap = el('div', { class: 'st-table-wrap' },
    el('table', { class: 'st-table' },
      el('thead', {},
        el('tr', {},
          el('th', { scope: 'col', text: 'Quán & Chủ quán' }),
          el('th', { scope: 'col', text: 'Trạng thái' }),
          sortableTh('Đơn 7 ngày', 'orders_7d', true),
          sortableTh('Đơn gần nhất', 'last_order_at', false),
          sortableTh('Thực đơn', 'menu_items', true),
          sortableTh('Ngày tạo', 'created_at', false),
          el('th', { scope: 'col', class: 'num-col', text: 'Thao tác' }),
        ),
      ),
      tbody,
    ),
  );

  // 2. Thẻ gọn 2 cột số cho điện thoại & máy tính bảng (< 1024px)
  const cardsWrap = el('div', { class: 'st-cards' });
  for (const s of rows) {
    cardsWrap.append(el('article', { class: 'st-card', 'data-store-id': s.id },
      el('div', { class: 'st-card-head' },
        el('div', {},
          el('button', {
            type: 'button',
            class: 'st-name-btn',
            text: s.name || '(chưa đặt tên)',
            onclick: (ev) => openStoreDetail(s, ev.currentTarget),
          }),
          el('div', { class: 'st-cell-sub' },
            s.store_code ? el('span', { class: 'badge code', text: s.store_code }) : null,
            el('span', { text: `Chủ: ${s.owner_name || '—'}` }),
            el('span', { text: `· Tạo ${fmtDay(s.created_at)}` }),
          ),
        ),
        el('div', { class: 'st-card-badges' },
          storeStatusBadge(s),
          storePlanMini(s),
          s.is_test ? el('span', { class: 'badge bad', text: 'Quán thử' }) : null,
        ),
      ),
      el('div', { class: 'st-card-metrics' },
        el('div', { class: 'st-metric' }, el('span', { text: 'Đơn 7N / 30N' }), el('b', { text: `${fmtN(s.orders_7d)} / ${fmtN(s.orders_30d)}` })),
        el('div', { class: 'st-metric' }, el('span', { text: 'Đơn gần nhất' }), el('b', { text: ago(s.last_order_at) })),
        el('div', { class: 'st-metric' }, el('span', { text: 'Món menu' }), el('b', { text: `${fmtN(s.menu_items)} món` })),
        el('div', { class: 'st-metric' }, el('span', { text: 'Nhân sự & Máy' }), el('b', { text: `${s.staff_owner}/${s.staff_manager}/${s.staff_other} · ${fmtN(s.devices)} máy` })),
      ),
      el('div', { class: 'st-card-actions' },
        el('button', { type: 'button', class: 'btn small', text: 'Xem Boom của quán', onclick: () => jumpToStoreBoom(s) }),
        el('button', {
          type: 'button',
          class: 'btn small',
          text: s.is_test ? 'Bỏ đánh dấu quán thử' : 'Đánh dấu quán thử',
          onclick: (ev) => promptToggleTestStore(s, ev.currentTarget),
        }),
      ),
    ));
  }

  list.append(tableWrap, cardsWrap);
}

loaders.stores = async () => {
  stMark();
  if (!st.rows.length) showSkeletons($('st-list'), 4, 'h-row');
  try {
    const d = await rpc('admin_store_list_v1', {
      p_filter: st.filter,
      p_search: st.search || null,
      p_include_test: $('st-include-test').checked,
      p_limit: st.limit,
      p_offset: st.offset,
    });
    st.rows = d.rows || [];
    st.total = Number(d.total || 0);
    $('st-total').textContent = `${fmtN(st.total)} quán`;
    renderStoresList();
    $('st-page').textContent = st.total ? `${fmtN(st.offset + 1)}–${fmtN(Math.min(st.offset + st.limit, st.total))} / ${fmtN(st.total)}` : '0 / 0';
    $('st-prev').disabled = st.offset === 0;
    $('st-next').disabled = st.offset + st.limit >= st.total;
  } catch (err) {
    if (err && (err.message === 'NO_TOKEN' || err.message === 'UNAUTHORIZED' || err.message === 'FORBIDDEN')) return;
    clear($('st-list')).append(errorBox('Không tải được danh sách quán.', () => loaders.stores()));
  }
};

// ── Tab Hỗ trợ chủ quán (H1 + H2): yêu cầu hỗ trợ từ app, tra tài khoản, mật khẩu tạm, xoá PIN nhanh ──
const sp = { status: 'open', kind: 'all', q: '' };
const SUPPORT_KIND = { bug: ['Báo lỗi', 'info'], forgot_password: ['Quên mật khẩu', 'warn'], other: ['Khác', ''] };
const SUPPORT_STATUS = { open: ['Mới', 'bad'], in_progress: ['Đang xử lý', 'warn'], done: ['Xong', 'good'] };
const SUPPORT_ERR = {
  CHECKS_REQUIRED: 'Phải làm và tick đủ 3 bước xác minh.',
  REASON_REQUIRED: 'Ghi lý do (5–500 ký tự).',
  QUERY_TOO_SHORT: 'Gõ ít nhất 3 ký tự (số điện thoại hoặc tên).',
  TOO_MANY: 'Đã cấp quá nhiều mật khẩu tạm trong 1 giờ — thử lại sau.',
  BAD_STATUS: 'Trạng thái không hợp lệ.',
};
const supportErr = (err) => SUPPORT_ERR[err && err.message] || adminErrText(err);
const SUPPORT_ACTION_NAMES = {
  temp_password: 'Cấp mật khẩu tạm', clear_quick_pin: 'Xoá PIN nhanh',
  owner_set_password: 'Chủ quán đặt mật khẩu mới', owner_set_name: 'Chủ quán đổi tên', self_set_name: 'Tự đổi tên',
};
const PW_KIND = { bcrypt: 'Mật khẩu an toàn (bcrypt)', legacy: 'Mật khẩu kiểu cũ', none: 'Chưa có mật khẩu' };

function supportChips(values, cur, onPick, label) {
  return el('div', { class: 'chips', role: 'group', 'aria-label': label },
    ...values.map(([v, t]) => el('button', { type: 'button', class: `chip${cur === v ? ' on' : ''}`, 'aria-pressed': String(cur === v),
                                              text: t, onclick: () => onPick(v) })));
}

function actSupportStatus(r, status) {
  openForm({
    title: status === 'done' ? 'Đánh dấu đã xử lý xong' : 'Chuyển sang đang xử lý',
    fields: [{ name: 'note', label: 'Ghi chú xử lý (tuỳ chọn)', type: 'textarea', maxlength: 1000, value: r.admin_note || '' }],
    okLabel: 'Lưu',
    onSubmit: async (v) => {
      try {
        await rpc('admin_support_update_v1', { p_id: r.id, p_status: status, p_note: nn(v.note) });
      } catch (err) { return isAuthErr(err) ? null : supportErr(err); }
      toast('Đã cập nhật yêu cầu');
      lastReload = loaders.support();
      return null;
    },
  });
}

function renderSupportRow(r) {
  const [kl, kc] = SUPPORT_KIND[r.kind] || [r.kind, ''];
  const [sl, sc] = SUPPORT_STATUS[r.status] || [r.status, ''];
  return el('article', { class: 'turn-card pl-card', 'data-report-id': r.id },
    el('div', { class: 'turn-badges' },
      el('span', { class: `badge ${kc}`, text: kl }),
      el('span', { class: `badge ${sc}`, text: sl }),
      el('span', { class: 'small muted', text: `${fmtD(r.created_at)}${r.app_version ? ` · app ${r.app_version}` : ''}${r.os ? ` · ${r.os}` : ''}` })),
    el('div', { class: 'st-cell-sub' },
      el('b', { text: r.user_name || '(không rõ người gửi)' }),
      r.user_phone ? telLink(r.user_phone) : null,
      r.store_name ? el('span', { text: `· ${r.store_name}${r.store_code ? ` (${r.store_code})` : ''}` }) : null),
    el('div', { class: 'prof-pre', text: r.description || '' }),
    r.admin_note ? el('div', { class: 'small muted prof-pre', text: `Ghi chú: ${r.admin_note}` }) : null,
    el('div', { class: 'st-row-actions pl-actions' },
      r.user_id ? el('button', { type: 'button', class: 'btn small primary', text: 'Mở tài khoản',
                                 onclick: (ev) => openAccount(r.user_id, ev.currentTarget, r.id) }) : null,
      r.status !== 'in_progress' && r.status !== 'done'
        ? el('button', { type: 'button', class: 'btn small', text: 'Đang xử lý', onclick: () => actSupportStatus(r, 'in_progress') }) : null,
      r.status !== 'done' ? el('button', { type: 'button', class: 'btn small', text: 'Xong', onclick: () => actSupportStatus(r, 'done') }) : null,
    ),
  );
}

function renderAccountRow(a, reportId) {
  return el('div', { class: 'prof-row' },
    el('div', {},
      el('b', { text: a.name || '(chưa đặt tên)' }),
      el('div', { class: 'small muted', text: `${a.phone || '—'} · ${(a.stores || []).map((s) => `${s.name}${s.is_owner ? ' (chủ)' : ''}`).join(', ') || 'chưa thuộc quán nào'}` })),
    el('button', { type: 'button', class: 'btn small', text: 'Hỗ trợ', onclick: (ev) => openAccount(a.id, ev.currentTarget, reportId) }),
  );
}

// Ngăn kéo tài khoản: thông tin, các quán, lịch sử hỗ trợ, nút cấp mật khẩu tạm / xoá PIN
let accountOpenId = null;
async function openAccount(userId, triggerEl, reportId, keep) {
  activeTurnShortcut = null;
  profileStoreId = null;
  accountOpenId = userId;
  if (!keep) {
    const sk = el('div', { class: 'kv-grid' });
    showSkeletons(sk, 4, 'h-row');
    openDrawerPanel('Tài khoản', [sk], triggerEl);
  }
  let d;
  try {
    d = await rpc('admin_account_detail_v1', { p_user: userId });
  } catch (err) {
    if (isAuthErr(err) || accountOpenId !== userId || $('drawer').hidden) return;
    clear($('drawer-body')).append(errorBox('Không tải được tài khoản.', () => openAccount(userId, null, reportId, true)));
    return;
  }
  if (accountOpenId !== userId || $('drawer').hidden) return;
  const a = d.account;
  $('drawer-title').textContent = a.name || 'Tài khoản';
  const support = a.support || [];
  clear($('drawer-body')).append(
    el('div', { class: 'card prof-owner' },
      el('div', { class: 'prof-owner-row' },
        el('div', {}, el('span', { class: 'muted small', text: 'Tài khoản' }), el('b', { class: 'prof-owner-name', text: a.name || '—' })),
        el('div', { class: 'prof-owner-phone' }, a.phone ? telLink(a.phone) : el('span', { class: 'muted', text: 'Không có SĐT' }))),
      el('div', { class: 'small muted', text: `Tạo ${fmtDay(a.created_at)} · đăng nhập gần nhất ${a.last_login ? fmtD(a.last_login) : 'chưa rõ'}` }),
      el('div', { class: 'turn-badges' },
        el('span', { class: `badge ${a.password_kind === 'bcrypt' ? 'good' : 'warn'}`, text: PW_KIND[a.password_kind] || a.password_kind }),
        el('span', { class: 'badge', text: a.has_quick_pin ? 'Có PIN nhanh' : 'Không có PIN nhanh' })),
    ),
    el('div', { class: 'review-actions prof-actions' },
      el('button', { type: 'button', class: 'btn danger', text: 'Cấp mật khẩu tạm', onclick: () => actTempPassword(a, reportId) }),
      a.has_quick_pin ? el('button', { type: 'button', class: 'btn', text: 'Xoá PIN nhanh', onclick: () => actClearPin(a) }) : null,
    ),
    section(`Các quán (${(a.stores || []).length})`, true,
      el('div', { class: 'prof-rows' }, (a.stores || []).length ? a.stores.map((s) => el('div', { class: 'prof-row', 'data-store-id': s.id },
        el('div', {}, el('b', { text: s.name || '—' }),
          el('div', { class: 'small muted', text: `${s.code || ''} · ${s.is_owner ? 'Chủ quán' : (s.role || '—')}${s.status === 'locked' ? ' · đang khoá' : ''}` })),
        el('button', { type: 'button', class: 'btn small', text: 'Hồ sơ quán', onclick: (ev) => openStoreDetail({ id: s.id, name: s.name }, ev.currentTarget) }),
      )) : el('p', { class: 'muted small', text: 'Không thuộc quán nào.' }))),
    section(`Lịch sử hỗ trợ (${support.length})`, support.length > 0,
      support.length ? el('div', { class: 'timeline' }, support.map((x) => el('div', { class: 'tl-item' },
        el('div', { class: 'tl-meta' }, el('span', { text: fmtD(x.created_at) }), el('span', { text: x.admin || '' })),
        el('div', { class: 'tl-title', text: SUPPORT_ACTION_NAMES[x.action] || x.action }),
        el('div', { class: 'tl-detail prof-pre', text: x.reason || '' }),
      ))) : el('p', { class: 'muted small', text: 'Chưa có.' })),
  );
}

function actTempPassword(a, reportId) {
  openForm({
    title: `Cấp mật khẩu tạm — ${a.name || 'tài khoản'}`,
    desc: 'Mật khẩu cũ hết dùng ngay; máy đang đăng nhập phải đăng nhập lại khi phiên hết hạn (tối đa 30 ngày). Máy tạo mật khẩu tạm, hiện MỘT LẦN để anh/chị đọc cho người dùng; họ đăng nhập rồi vào Cài đặt → Đổi mật khẩu. Chỉ làm sau khi xác minh đủ 3 bước:',
    fields: [
      { name: 'callback', type: 'checkbox', label: `Đã GỌI LẠI đúng số đăng ký ${a.phone || ''} (không gọi số khác người đó đưa)` },
      { name: 'store_info', type: 'checkbox', label: 'Người nghe nói đúng tên quán + mã quán' },
      { name: 'secret', type: 'checkbox', label: 'Trả lời đúng 1 câu chỉ chủ quán biết (món bán chạy, số nhân viên, đơn gần nhất… — xem ở Hồ sơ quán)' },
      { name: 'reason', label: 'Lý do (bắt buộc)', type: 'textarea', maxlength: 500 },
    ],
    okLabel: 'Tạo mật khẩu tạm',
    danger: true,
    onSubmit: async (v) => {
      if (!v.callback || !v.store_info || !v.secret) return SUPPORT_ERR.CHECKS_REQUIRED;
      if (v.reason.length < 5) return SUPPORT_ERR.REASON_REQUIRED;
      let r;
      try {
        r = await rpc('admin_account_reset_password_v1', { p_user: a.id, p_reason: v.reason,
          p_checks: { callback: true, store_info: true, secret: true }, p_report: reportId || null });
      } catch (err) { return isAuthErr(err) ? null : supportErr(err); }
      // hiện mật khẩu tạm 1 lần (hộp mới) — không lưu ở đâu trên trang
      setTimeout(() => showTempPassword(a, r.temp_password), 0);
      if (accountOpenId === a.id && !$('drawer').hidden) openAccount(a.id, null, reportId, true);
      if (location.hash.slice(1) === 'support') lastReload = loaders.support();
      return null;
    },
  });
}

function showTempPassword(a, pw) {
  const pwBox = el('div', { class: 'temp-pw', text: pw });
  const groups = el('div', { class: 'small muted', text: `Đọc theo nhóm: ${pw.slice(0, 5)} - ${pw.slice(5)} (chữ IN HOA, không có O / I / L / 0 / 1)` });
  openForm({
    title: 'Mật khẩu tạm — chỉ hiện một lần',
    desc: `Đọc cho ${a.name || 'người dùng'} (${a.phone || ''}). Nhắc họ đăng nhập ngay rồi vào Cài đặt → Đổi mật khẩu. Mật khẩu tạm KHÔNG tự hết hạn — gọi lại sau 24 giờ hỏi họ đã đổi chưa.`,
    fields: [],
    extra: [pwBox, groups],
    okLabel: 'Đã đọc xong',
    sticky: true,
    onSubmit: async () => null,
  });
}

function actClearPin(a) {
  openForm({
    title: `Xoá PIN nhanh — ${a.name || 'tài khoản'}`,
    desc: 'Người dùng sẽ tự đặt PIN nhanh mới trong app.',
    fields: [{ name: 'reason', label: 'Lý do (bắt buộc)', type: 'textarea', maxlength: 500 }],
    okLabel: 'Xoá PIN nhanh',
    onSubmit: async (v) => {
      if (v.reason.length < 5) return SUPPORT_ERR.REASON_REQUIRED;
      try {
        await rpc('admin_account_clear_pin_v1', { p_user: a.id, p_reason: v.reason });
      } catch (err) { return isAuthErr(err) ? null : supportErr(err); }
      toast('Đã xoá PIN nhanh');
      if (accountOpenId === a.id && !$('drawer').hidden) lastReload = openAccount(a.id, null, null, true);
      return null;
    },
  });
}

async function openAccountByPhone(phone, triggerEl) {
  try {
    const d = await rpc('admin_account_search_v1', { p_q: phone });
    const rows = (d.rows || []).filter((a) => String(a.phone || '').replace(/\D/g, '').slice(-9) === String(phone).replace(/\D/g, '').slice(-9));
    if (rows.length === 1) openAccount(rows[0].id, triggerEl, null);
    else toast('Không xác định được tài khoản — tra ở tab Hỗ trợ');
  } catch (err) {
    if (!isAuthErr(err)) toast(supportErr(err));
  }
}

async function searchAccounts() {
  const box = $('sp-accounts');
  const q = $('sp-search').value.trim();
  sp.q = q;
  if (q.length < 3) { clear(box).append(el('p', { class: 'muted small', text: SUPPORT_ERR.QUERY_TOO_SHORT })); return; }
  clear(box).append(el('p', { class: 'muted small', text: 'Đang tìm…' }));
  try {
    const d = await rpc('admin_account_search_v1', { p_q: q });
    const rows = d.rows || [];
    clear(box).append(rows.length ? el('div', { class: 'prof-rows' }, rows.map((a) => renderAccountRow(a, null)))
      : el('p', { class: 'muted small', text: 'Không tìm thấy tài khoản nào.' }));
  } catch (err) {
    if (!isAuthErr(err)) clear(box).append(el('p', { class: 'small', text: supportErr(err) }));
  }
}
$('sp-search-btn').addEventListener('click', searchAccounts);
$('sp-search').addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); searchAccounts(); } });
$('sp-refresh').addEventListener('click', () => loaders.support());

loaders.support = async () => {
  const list = $('sp-list');
  if (!list.childElementCount) showSkeletons(list, 3, 'h-row');
  let d;
  try {
    d = await rpc('admin_support_list_v1', { p_status: sp.status, p_kind: sp.kind, p_limit: 100, p_offset: 0 });
  } catch (err) {
    if (isAuthErr(err)) return;
    clear(list).append(errorBox('Không tải được yêu cầu hỗ trợ.', () => loaders.support()));
    return;
  }
  const c = d.counts || {};
  clear($('sp-filters')).append(
    supportChips([['open', `Mới (${fmtN(c.open || 0)})`], ['in_progress', `Đang xử lý (${fmtN(c.in_progress || 0)})`],
                  ['done', 'Xong'], ['all', 'Tất cả']], sp.status, (v) => { sp.status = v; loaders.support(); }, 'Lọc trạng thái yêu cầu'),
    supportChips([['all', 'Mọi loại'], ['forgot_password', 'Quên mật khẩu'], ['bug', 'Báo lỗi']], sp.kind,
                 (v) => { sp.kind = v; loaders.support(); }, 'Lọc loại yêu cầu'),
  );
  const rows = d.rows || [];
  clear(list).append(...(rows.length ? rows.map(renderSupportRow)
    : [emptyBox('Không có yêu cầu nào', sp.status === 'open' ? 'Chưa có phản hồi mới từ app.' : 'Thử đổi bộ lọc.')]));
};

// ── Tab 3: Boom — Hội thoại ───────────────────────────────────────────────────
const bmMark = chipGroup('bm-filters', bm, () => loaders.boom());
let bmTimer;
$('bm-search').addEventListener('input', () => {
  clearTimeout(bmTimer);
  bmTimer = setTimeout(() => {
    bm.search = $('bm-search').value.trim();
    bm.offset = 0;
    loaders.boom();
  }, 350);
});
$('bm-range').addEventListener('change', () => { bm.offset = 0; loaders.boom(); });
$('bm-refresh').addEventListener('click', () => loaders.boom());
$('bm-prev').addEventListener('click', () => { bm.offset = Math.max(0, bm.offset - bm.limit); loaders.boom(); });
$('bm-next').addEventListener('click', () => { bm.offset += bm.limit; loaders.boom(); });

const VERDICT = {
  dung: ['Đúng', 'good', '1'],
  chua_dung: ['Chưa đúng', 'warn', '2'],
  sai: ['Sai', 'bad', '3'],
};

function toolLabel(t) {
  let s = String(t || '');
  if (s.startsWith('app:')) s = s.slice(4);
  if (s.startsWith('boom_tu_choi') || s === 'boom_khong_quyen') return 'Từ chối';
  if (s.startsWith('cache')) return 'Bộ nhớ đã duyệt';
  if (s.startsWith('answer:')) return 'Hướng dẫn (GPT)';
  if (s.startsWith('advice:')) {
    return s.includes('chuoi') ? 'So sánh chi nhánh'
      : s.includes('module') ? 'Số các mục'
      : s.includes('so_lieu') ? 'Tư vấn + số liệu'
      : 'Tư vấn';
  }
  if (s.startsWith('huong_dan')) return 'Hướng dẫn nguyên văn';
  if (/summary|products|stock|shift|revenue|comparison/.test(s)) return 'Số liệu nhanh';
  return s || 'App tự trả';
}

function bmStatCard(val, label, sub) {
  return el('div', { class: 'bm-stat' },
    el('div', { class: 'v', text: val }),
    el('div', { class: 'k', text: label }),
    sub ? el('div', { class: 'sub', text: sub }) : null,
  );
}

loaders.boom = async () => {
  bmMark();
  const days = Number($('bm-range').value);
  const sf = $('bm-store-filter');
  clear(sf);
  if (bm.store) {
    sf.hidden = false;
    sf.append(
      el('span', { text: `Đang lọc hội thoại của quán: ${bm.store.name}` }),
      el('button', {
        type: 'button',
        class: 'btn small',
        text: 'Bỏ lọc quán ✕',
        onclick: () => { bm.store = null; bm.offset = 0; loaders.boom(); },
      }),
    );
  } else {
    sf.hidden = true;
  }

  if (!bm.rows.length) showSkeletons($('bm-list'), 4, 'h-row');

  try {
    const [stats, d] = await Promise.all([
      rpc('admin_boom_stats_v1', { p_days: days }),
      rpc('admin_boom_turns_v1', {
        p_store: bm.store ? bm.store.id : null,
        p_from: new Date(Date.now() - days * 86400000).toISOString(),
        p_to: null,
        p_filter: bm.filter,
        p_search: bm.search || null,
        p_limit: bm.limit,
        p_offset: bm.offset,
      }),
    ]);

    const rv = stats.reviewed || {};
    const reviewedSum = Number(rv.dung || 0) + Number(rv.chua_dung || 0) + Number(rv.sai || 0);
    clear($('bm-stats')).append(
      bmStatCard(fmtN(stats.turns), 'Lượt hỏi', `${fmtN(stats.gpt_turns || 0)} qua GPT`),
      bmStatCard(fmtN(stats.stores), 'Quán dùng Boom', `Trong ${days} ngày`),
      bmStatCard(`${fmtN(stats.up)} / ${fmtN(stats.down)}`, 'Đánh giá 👍 / 👎', stats.down > 0 ? 'Cần rà câu bị 👎' : 'Chưa có 👎'),
      bmStatCard(fmtN(stats.unanswered), 'Chưa trả lời được', `Từ chối: ${fmtN(stats.blocked)}`),
      bmStatCard(`$${Number(stats.cost_usd || 0).toFixed(3)}`, 'Chi phí OpenAI', stats.errors ? `Lỗi: ${fmtN(stats.errors)}` : '0 lỗi máy chủ'),
      bmStatCard(fmtN(reviewedSum), 'Đã chấm điểm', `✓${rv.dung || 0} · ~${rv.chua_dung || 0} · ✕${rv.sai || 0} · dạy ${rv.teach || 0}`),
    );

    bm.rows = d.rows || [];
    bm.total = Number(d.total || 0);
    $('bm-total').textContent = `${fmtN(bm.total)} lượt`;

    const list = clear($('bm-list'));
    if (!bm.rows.length) {
      list.append(emptyBox('Chưa có hội thoại phù hợp', 'Thử mở rộng khoảng thời gian hoặc đổi bộ lọc kiểm duyệt.'));
    }
    for (const t of bm.rows) {
      const v = VERDICT[t.verdict];
      const preview = String(t.answer_preview || '') + (t.answer_len > 400 ? '…' : '');
      list.append(el('button', {
        type: 'button',
        class: 'turn-card',
        onclick: (ev) => openTurn(t.id, ev.currentTarget),
      },
        el('div', { class: 'turn-top' },
          el('div', { class: 'turn-badges' },
            el('span', { class: 'badge info', text: toolLabel(t.tool) }),
            el('span', { class: 'badge', text: t.source === 'app' ? 'App tự trả' : 'Qua máy chủ' }),
            t.rating === 'down' ? el('span', { class: 'badge bad', text: '👎 Khách chê' })
              : t.rating === 'up' ? el('span', { class: 'badge good', text: '👍 Khách khen' }) : null,
            v ? el('span', { class: `badge ${v[1]}`, text: `Chấm: ${v[0]}` }) : null,
            t.needs_teaching ? el('span', { class: 'badge warn', text: 'Cần dạy lại' }) : null,
          ),
          el('span', { class: 'turn-meta', text: `${t.store_name || ''} · ${t.user_name || ''} · ${fmtD(t.created_at)}` }),
        ),
        el('div', { class: 'turn-q', text: t.question || '(trống)' }),
        el('div', { class: 'turn-a', text: preview || '(không có nội dung trả lời)' }),
      ));
    }

    $('bm-page').textContent = bm.total ? `${fmtN(bm.offset + 1)}–${fmtN(Math.min(bm.offset + bm.limit, bm.total))} / ${fmtN(bm.total)}` : '0 / 0';
    $('bm-prev').disabled = bm.offset === 0;
    $('bm-next').disabled = bm.offset + bm.limit >= bm.total;
  } catch (err) {
    if (err && (err.message === 'NO_TOKEN' || err.message === 'UNAUTHORIZED' || err.message === 'FORBIDDEN')) return;
    clear($('bm-list')).append(errorBox('Không tải được danh sách hội thoại Boom.', () => loaders.boom()));
  }
};

// ── Drawer chi tiết lượt hỏi + Phím tắt 1/2/3, J/K, S, Esc ───────────────────
$('drawer-close').addEventListener('click', closeDrawer);
$('drawer').addEventListener('click', (e) => { if (e.target === $('drawer')) closeDrawer(); });

document.addEventListener('keydown', (e) => {
  if (!$('form-modal').hidden) {
    if (e.key === 'Escape') { e.preventDefault(); if (!formSticky) { closeForm(); restoreFocusAfterForm(); } }
    else if (e.key === 'Tab') {
      const f = [...$('form-card').querySelectorAll('button:not(:disabled), input:not(:disabled), textarea:not(:disabled), select:not(:disabled)')]
        .filter((n) => n.offsetParent);
      if (f.length) {
        const first = f[0], last = f[f.length - 1];
        if (e.shiftKey && (document.activeElement === first || !$('form-card').contains(document.activeElement))) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && (document.activeElement === last || !$('form-card').contains(document.activeElement))) { e.preventDefault(); first.focus(); }
      }
    }
    return;
  }
  if (!$('confirm-modal').hidden) {
    if (e.key === 'Escape') { e.preventDefault(); closeConfirm(); }
    return;
  }
  if ($('drawer').hidden) return;
  if (e.key === 'Escape') {
    e.preventDefault();
    closeDrawer();
    return;
  }
  // Bẫy phím Tab trong Drawer để đảm bảo khả năng tiếp cận
  if (e.key === 'Tab') {
    const focusables = [...$('drawer').querySelectorAll('button:not(:disabled), input:not(:disabled), textarea:not(:disabled), select:not(:disabled), [tabindex]:not([tabindex="-1"])')];
    if (focusables.length) {
      const first = focusables[0];
      const last = focusables[focusables.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
    return;
  }
  if (!activeTurnShortcut) return;
  const tag = (document.activeElement && document.activeElement.tagName) || '';
  const inText = tag === 'TEXTAREA' || tag === 'INPUT';
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    activeTurnShortcut.save();
    return;
  }
  if (inText || e.metaKey || e.ctrlKey || e.altKey) return;
  const k = e.key.toLowerCase();
  if (k === '1') { e.preventDefault(); activeTurnShortcut.pick('dung'); }
  else if (k === '2') { e.preventDefault(); activeTurnShortcut.pick('chua_dung'); }
  else if (k === '3') { e.preventDefault(); activeTurnShortcut.pick('sai'); }
  else if (k === 's') { e.preventDefault(); activeTurnShortcut.save(); }
  else if (k === 'j') { e.preventDefault(); activeTurnShortcut.step(1); }
  else if (k === 'k') { e.preventDefault(); activeTurnShortcut.step(-1); }
});

async function openTurn(id, triggerEl, keepFocus = false) {
  let d;
  try {
    d = await rpc('admin_boom_turn_v1', { p_id: id });
  } catch {
    toast('Không mở được chi tiết lượt hỏi');
    return;
  }

  const t = d.turn || {};
  const l = d.log;
  const rv = d.review || {};
  let verdict = rv.verdict || null;

  const idx = bm.rows.findIndex((r) => r.id === id);
  const stepTurn = (delta) => {
    if (idx < 0) return;
    const nextRow = bm.rows[idx + delta];
    if (nextRow) openTurn(nextRow.id, null, true);
  };

  const prevBtn = el('button', {
    type: 'button',
    class: 'btn small',
    text: '↑ Trước (K)',
    disabled: idx <= 0,
    'aria-label': 'Lượt hỏi trước',
    onclick: () => stepTurn(-1),
  });
  const nextBtn = el('button', {
    type: 'button',
    class: 'btn small',
    text: '↓ Sau (J)',
    disabled: idx < 0 || idx >= bm.rows.length - 1,
    'aria-label': 'Lượt hỏi tiếp theo',
    onclick: () => stepTurn(1),
  });

  const note = el('textarea', {
    placeholder: 'Ghi chú kiểm duyệt (Boom sai ở đâu, thiếu ý gì, nên trả lời mẫu thế nào)…',
    'aria-label': 'Ghi chú chấm điểm',
  });
  note.value = rv.note || '';

  const teachInput = el('input', { type: 'checkbox', id: 'turn-teach-chk' });
  teachInput.checked = !!rv.needs_teaching;
  const teachSwitch = el('label', { class: 'switch', for: 'turn-teach-chk' },
    teachInput,
    el('span', { class: 'switch-track', 'aria-hidden': 'true' }, el('span', { class: 'switch-thumb' })),
    el('span', { class: 'switch-label', text: 'Cần dạy lại Boom câu này' }),
  );

  const vbox = el('div', { class: 'verdict-grid', role: 'group', 'aria-label': 'Chọn mức chấm điểm' });
  const paintVerdicts = () => {
    for (const b of vbox.children) {
      const on = b.dataset.v === verdict;
      b.classList.toggle('on', on);
      b.setAttribute('aria-pressed', String(on));
    }
  };

  const pickVerdict = (key) => {
    verdict = verdict === key ? null : key;
    paintVerdicts();
  };

  for (const [k, [label, cls, numKey]] of Object.entries(VERDICT)) {
    const b = el('button', {
      type: 'button',
      class: `verdict-btn ${cls}`,
      onclick: () => pickVerdict(k),
    },
      el('span', { class: 'kbd', text: numKey }),
      el('span', { text: label }),
    );
    b.dataset.v = k;
    vbox.append(b);
  }
  paintVerdicts();

  let saving = false;
  const saveBtn = el('button', {
    type: 'button',
    class: 'btn primary',
    text: 'Lưu chấm (S)',
    onclick: async () => {
      if (saving) return;
      saving = true;
      saveBtn.disabled = true;
      try {
        await rpc('admin_boom_review_v1', {
          p_id: id,
          p_verdict: verdict,
          p_note: note.value,
          p_needs_teaching: teachInput.checked,
        });
        toast('Đã lưu chấm điểm');
        loaders.boom();
      } catch {
        toast('Không lưu được chấm điểm');
      } finally {
        saving = false;
        saveBtn.disabled = false;
      }
    },
  });

  activeTurnShortcut = {
    pick: pickVerdict,
    save: () => saveBtn.click(),
    step: stepTurn,
  };

  const chatThread = el('div', { class: 'chat-thread' },
    el('div', { class: 'chat-msg user' },
      el('div', { class: 'chat-sender', text: `${t.user_name || 'Người hỏi'} · ${t.store_name || ''} · ${fmtD(t.created_at)}` }),
      el('div', { class: 'bubble', text: t.question || '(trống)' }),
    ),
    el('div', { class: 'chat-msg bot' },
      el('div', { class: 'chat-sender', text: `Bé Boom · ${toolLabel(t.tool)} · ${t.source === 'app' ? 'App tự trả' : 'Qua máy chủ'}` }),
      el('div', { class: 'bubble', text: t.answer || '(không có câu trả lời)' }),
      l && l.rating ? el('span', {
        class: `badge ${l.rating === 'up' ? 'good' : 'bad'}`,
        text: `Khách đánh giá ${l.rating === 'up' ? '👍' : '👎'}${l.rating_reason ? ` — ${l.rating_reason}` : ''}`,
      }) : null,
    ),
  );

  const chunksBox = d.chunks && d.chunks.length
    ? el('div', { class: 'card' },
      el('div', { class: 'small muted', text: 'Bài hướng dẫn Boom đã tham chiếu:' }),
      el('div', { class: 'turn-badges' },
        ...d.chunks.map((c) => el('button', {
          type: 'button',
          class: 'chip',
          text: `${c.module} › ${c.title}`,
          onclick: () => openChunk(c.id, null, id),
        })),
      ),
    )
    : null;

  const telemetryBox = l
    ? el('div', { class: 'kv-grid' },
      el('div', { class: 'kv-box' }, el('span', { text: 'Trạng thái' }), el('b', { text: l.status || '—' })),
      el('div', { class: 'kv-box' }, el('span', { text: 'Mô hình' }), el('b', { text: l.model || '—' })),
      el('div', { class: 'kv-box' }, el('span', { text: 'Token vào / ra' }), el('b', { text: `${fmtN(l.input_tokens)} / ${fmtN(l.output_tokens)}` })),
      el('div', { class: 'kv-box' }, el('span', { text: 'Chi phí' }), el('b', { text: `$${Number(l.cost_usd || 0).toFixed(5)}` })),
      el('div', { class: 'kv-box' }, el('span', { text: 'Thời gian phản hồi' }), el('b', { text: l.latency_ms ? `${(l.latency_ms / 1000).toFixed(1)} giây` : '—' })),
    )
    : el('p', { class: 'caps-note', text: 'Câu hỏi được ứng dụng tự trả lời trực tiếp trên thiết bị (không gọi GPT, tốn 0 token).' });

  const reviewCard = el('div', { class: 'card' },
    el('div', { class: 'card-head' }, el('h3', { text: 'Chấm điểm câu trả lời' })),
    vbox,
    note,
    el('div', { class: 'review-actions' }, teachSwitch, saveBtn),
    el('p', { class: 'kbd-hint', text: 'Phím tắt: 1 Đúng · 2 Chưa đúng · 3 Sai · S Lưu · J/K Lượt sau/trước · Esc Đóng' }),
  );

  openDrawerPanel('Chi tiết lượt hỏi', [chatThread, chunksBox, telemetryBox, reviewCard], triggerEl, {
    navNodes: [prevBtn, nextBtn],
    keepFocus,
  });
}

async function openChunk(chunkId, triggerEl, returnTurnId = null) {
  try {
    const d = await rpc('admin_boom_chunk_v1', { p_id: chunkId });
    const c = d.chunk || {};
    activeTurnShortcut = null;
    openDrawerPanel(c.title || 'Đoạn hướng dẫn', [
      el('div', { class: 'turn-badges' },
        el('span', { class: 'badge info', text: c.module_name || 'Hướng dẫn' }),
        el('span', { class: 'badge code', text: c.id || chunkId }),
      ),
      el('div', { class: 'card' },
        el('pre', { class: 'prompt', text: c.text || '(trống)' }),
      ),
    ], triggerEl, {
      onBack: returnTurnId ? () => openTurn(returnTurnId, null, true) : null,
    });
  } catch {
    toast('Không mở được đoạn hướng dẫn');
  }
}

// ── Tab 4: Boom — Những gì đã dạy ─────────────────────────────────────────────
loaders.knowledge = async () => {
  const errBox = $('kn-error');
  errBox.hidden = true;
  clear(errBox);

  try {
    const d = await rpc('admin_boom_knowledge_v1');

    // 1. Dòng thời gian nhật ký dạy Boom
    const cl = clear($('kn-changelog'));
    if (!d.changelog || !d.changelog.length) {
      cl.append(emptyBox('Chưa có nhật ký dạy Boom', 'Mỗi đợt cập nhật kiến thức sẽ hiển thị tại đây.'));
    } else {
      for (const c of d.changelog) {
        cl.append(el('div', { class: 'tl-item' },
          el('div', { class: 'tl-meta' },
            el('span', { text: fmtD(c.applied_at) }),
            c.version ? el('span', { class: 'badge code', text: c.version }) : null,
            c.checks ? el('span', { class: 'badge good', text: `✓ ${c.checks}` }) : null,
          ),
          el('div', { class: 'tl-title', text: c.title || '' }),
          c.detail ? el('div', { class: 'tl-detail', text: c.detail }) : null,
        ));
      }
    }

    // 2. Bộ hướng dẫn & thanh mức dùng từng module
    const packsBox = clear($('kn-packs'));
    const p = d.packs && d.packs[0];
    if (p) {
      packsBox.append(el('div', { class: 'pack-banner' },
        el('strong', { text: `Bản đang dùng: ${p.version} · ${fmtN(p.chunk_count)} đoạn hướng dẫn` }),
        el('span', {
          class: 'small muted',
          text: `Đăng lúc ${fmtD(p.created_at)}${p.note ? ` — ${p.note}` : ''} · Tổng cộng ${fmtN(d.packs.length)} phiên bản`,
        }),
      ));
    } else {
      packsBox.append(emptyBox('Chưa đăng bộ hướng dẫn nào', ''));
    }

    const byMod = new Map();
    for (const c of (d.chunks || [])) {
      if (!byMod.has(c.module)) byMod.set(c.module, []);
      byMod.get(c.module).push(c);
    }

    const modStats = [...byMod.entries()].map(([m, cs]) => ({
      m,
      cs,
      uses: cs.reduce((a, x) => a + Number(x.uses || 0), 0),
      ups: cs.reduce((a, x) => a + Number(x.ups || 0), 0),
      downs: cs.reduce((a, x) => a + Number(x.downs || 0), 0),
    }));
    const maxUses = Math.max(1, ...modStats.map((x) => x.uses));

    const mods = clear($('kn-modules'));
    for (const item of modStats) {
      const ratio = Math.round((item.uses / maxUses) * 100);
      const usageSvg = svgEl('svg', { viewBox: '0 0 100 6', preserveAspectRatio: 'none', class: 'mod-bar-svg', 'aria-hidden': 'true' },
        svgEl('rect', { x: 0, y: 0, width: 100, height: 6, rx: 3, class: 'mod-bar-track' }),
        item.uses > 0 ? svgEl('rect', { x: 0, y: 0, width: Math.max(3, ratio), height: 6, rx: 3, class: 'mod-bar-fill' }) : null,
      );

      const tbody = el('tbody', {});
      for (const c of item.cs) {
        tbody.append(el('tr', {},
          el('td', {}, el('button', {
            type: 'button',
            class: 'link',
            text: c.title,
            onclick: (ev) => openChunk(c.id, ev.currentTarget),
          })),
          el('td', { class: 'num', text: fmtN(c.uses) }),
          el('td', { class: 'num', text: `👍 ${fmtN(c.ups)} / 👎 ${fmtN(c.downs)}` }),
        ));
      }

      const tbl = el('table', { class: 'tbl' },
        el('thead', {},
          el('tr', {},
            el('th', { scope: 'col', text: 'Đoạn hướng dẫn' }),
            el('th', { scope: 'col', text: 'Lần dùng' }),
            el('th', { scope: 'col', text: 'Đánh giá' }),
          ),
        ),
        tbody,
      );

      mods.append(el('details', { class: 'mod-card' },
        el('summary', {},
          el('div', { class: 'mod-sum-top' },
            el('span', { class: 'mod-title', text: `${item.m} (${fmtN(item.cs.length)} đoạn)` }),
            el('span', { class: 'mod-stats', text: `Dùng ${fmtN(item.uses)} lần · 👍 ${fmtN(item.ups)} / 👎 ${fmtN(item.downs)}` }),
          ),
          usageSvg,
        ),
        el('div', { class: 'mod-body' }, tbl),
      ));
    }

    // 3. Bộ nhớ câu trả lời đã duyệt
    const cache = clear($('kn-cache'));
    if (!d.cache || !d.cache.length) {
      cache.append(emptyBox(
        'Bộ nhớ đang trống',
        'Chưa duyệt câu trả lời mẫu nào. Khi có câu mẫu được duyệt, Boom sẽ trả lời tức thì không tốn token.',
      ));
    } else {
      for (const c of d.cache) {
        cache.append(el('div', { class: 'turn-card' },
          el('div', { class: 'turn-top' },
            el('div', { class: 'turn-badges' },
              el('span', { class: 'badge info', text: c.kind || 'Mẫu' }),
              el('span', { class: `badge ${c.status === 'active' ? 'good' : ''}`, text: c.status || '' }),
            ),
            el('span', { class: 'turn-meta', text: `Dùng ${fmtN(c.hits)} · 👍 ${fmtN(c.ups)} / 👎 ${fmtN(c.downs)}` }),
          ),
          el('div', { class: 'turn-q', text: (c.questions || []).join(' | ') }),
          el('div', { class: 'turn-a', text: c.answer || '' }),
          c.note ? el('div', { class: 'small muted', text: c.note }) : null,
        ));
      }
    }

    // 4. Bảng năng lực đọc số
    renderCaps();
  } catch (err) {
    if (err && (err.message === 'NO_TOKEN' || err.message === 'UNAUTHORIZED' || err.message === 'FORBIDDEN')) return;
    errBox.hidden = false;
    errBox.append(errorBox('Không tải được dữ liệu đã dạy Boom.', () => loaders.knowledge()));
  }
};

$('kn-refresh').addEventListener('click', () => loaders.knowledge());

function renderCaps() {
  const rows = [
    ['Doanh thu, số đơn, so kỳ trước', 'Chủ, quản lý, người có mục Báo cáo'],
    ['Món bán chạy / bán chậm, theo giờ, thứ, nhóm món', 'Chủ, quản lý, người có mục Báo cáo'],
    ['So sánh chi nhánh trong chuỗi', 'Chỉ chủ chuỗi, đang mở quán trong chuỗi'],
    ['Thu Chi: thu, chi, khoản chi lớn, so kỳ trước', 'Chủ, người có mục Thu Chi'],
    ['Kho: sắp hết, nhập hàng, hao hụt', 'Người có mục Kho (nhân viên không thấy tiền)'],
    ['Chấm công / Lương: giờ làm, kỳ lương', 'Chủ, quản lý; nhân viên chỉ thấy giờ của mình'],
    ['Khách hàng: khách mới, quay lại, ví', 'Chủ, quản lý, người có mục Khách hàng'],
    ['Khuyến mãi: mã đang chạy, tổng giảm giá', 'Người có mục Khách hàng hoặc Báo cáo'],
    ['Hàng sắp hết (trả nhanh)', 'Người có mục Kho'],
    ['Ai đang trong ca', 'Chủ, quản lý'],
  ];
  const tbody = el('tbody', {});
  for (const [a, b] of rows) {
    tbody.append(el('tr', {}, el('td', { text: a }), el('td', { text: b })));
  }
  const tbl = el('table', { class: 'tbl' },
    el('thead', {},
      el('tr', {},
        el('th', { scope: 'col', text: 'Boom đọc được (CHỈ ĐỌC)' }),
        el('th', { scope: 'col', text: 'Ai được xem' }),
      ),
    ),
    tbody,
  );
  clear($('kn-caps')).append(
    tbl,
    el('p', {
      class: 'caps-note',
      text: 'Chưa đọc được: lượt dùng từng mã giảm giá ở bán tại quầy, doanh thu theo nhân viên, chi tiết từng hoá đơn, công nợ. Boom tuyệt đối không thêm, sửa hay xoá dữ liệu.',
    }),
  );
}

function promptBlock(title, content) {
  const textStr = String(content || '');
  return el('div', { class: 'prompt-block' },
    el('div', { class: 'prompt-head' },
      el('h4', { text: title }),
      el('button', {
        type: 'button',
        class: 'btn small',
        text: 'Sao chép',
        onclick: async () => {
          try {
            await navigator.clipboard.writeText(textStr);
            toast('Đã sao chép lời dặn');
          } catch {
            toast('Trình duyệt chặn sao chép tự động');
          }
        },
      }),
    ),
    el('pre', { class: 'prompt', text: textStr }),
  );
}

async function loadAdminPrompt() {
  const jwt = token();
  if (!jwt) { logout('Phiên làm việc đã hết hạn, vui lòng đăng nhập lại.'); return; }
  const btn = $('kn-load-prompt');
  if (btn) { btn.disabled = true; btn.textContent = 'Đang tải lời dặn…'; }
  const gen = sessionGen;
  try {
    const r = await fetch(`${API}/functions/v1/boom-chat`, {
      method: 'POST',
      headers: {
        apikey: CFG.anonKey || '',
        Authorization: `Bearer ${jwt}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ mode: 'admin_prompt' }),
    });
    if (gen !== sessionGen) return;
    if (r.status === 401) { logout('Phiên làm việc đã hết hạn, vui lòng đăng nhập lại.'); return; }
    if (!r.ok) throw new Error(String(r.status));
    const d = await r.json();
    if (gen !== sessionGen) return;
    clear($('kn-prompt')).append(
      el('div', { class: 'prompt-meta' },
        el('span', { class: 'badge info', text: `Mô hình: ${d.model || '—'}` }),
        el('span', { class: `badge ${d.enabled ? 'good' : 'bad'}`, text: d.enabled ? 'Boom đang bật' : 'Boom đang tắt' }),
        el('span', { class: `badge ${d.cache_on ? 'good' : ''}`, text: d.cache_on ? 'Bộ nhớ: Bật' : 'Bộ nhớ: Tắt' }),
        el('span', { class: 'badge code', text: `Phiên bản: ${d.logic_version || '—'}` }),
      ),
      promptBlock('Lời dặn khi tư vấn kinh doanh (gồm luật + kiến thức nền)', d.advice_prompt),
      promptBlock('Lời dặn khi trả lời theo hướng dẫn ứng dụng', d.guide_prompt),
      promptBlock('Mẫu câu từ chối chủ đề ngoài phạm vi', JSON.stringify(d.refusal || {}, null, 2)),
    );
  } catch {
    if (gen !== sessionGen) return;
    if (btn) { btn.disabled = false; btn.textContent = 'Xem nguyên văn lời dặn'; }
    toast('Không tải được lời dặn đang chạy');
  }
}

$('kn-load-prompt').addEventListener('click', loadAdminPrompt);

start();
