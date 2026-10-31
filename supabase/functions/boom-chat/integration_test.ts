// Test cả hàm boom-chat như chạy thật: một máy chủ giả đóng vai Supabase (REST, RPC) + OpenAI.
// deno test --allow-net --allow-env --allow-run --allow-read integration_test.ts
import { assert, assertEquals } from 'jsr:@std/assert@1';
import * as jose from 'jsr:@panva/jose@6';
import { fromFileUrl } from 'jsr:@std/path@1';
import { CHAIN_LOG_NOTE, chunkHash, MODULE_LOG_NOTE } from './logic.ts';

const SECRET = 'jwt-test-secret-0123456789-0123456789';
const FAKE_KEY = 'sk-test-KHONG-DUOC-LO-123456';
const S = '11111111-2222-3333-4444-555555555555';
const U = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const U2 = 'bbbbbbbb-bbbb-cccc-dddd-eeeeeeeeeeee';
const OUTSIDER = 'ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee';
const ID = 'quan-ly-ban#huy-mon';
const MOCK = 8787;
const FN = 'http://127.0.0.1:8000';

type Row = Record<string, unknown>;
const CHUNK = { id: ID, module_name: 'Quản lý Bàn', section: '', title: 'Huỷ món', text: 'Bấm "Huỷ món" → Quản lý duyệt.' };
const state = {
  cache: [] as Row[],
  cacheAnswers: {} as Record<string, string>,
  logs: [] as Row[],
  openaiCalls: [] as { auth: string | null; body: Row }[],
  openaiStatus: 200,
  openaiDelayMs: 0,
  openaiContent: '1. Bấm "Huỷ món".\n2. Nhờ Quản lý duyệt.',
  packQueries: [] as string[],
  memQueries: [] as string[],
  full: [] as Row[],
  admins: [] as string[],
};

function mock() {
  return Deno.serve({ port: MOCK, onListen() {} }, async (req) => {
    const u = new URL(req.url);
    if (u.pathname === '/v1/chat/completions') {
      const body = await req.json();
      state.openaiCalls.push({ auth: req.headers.get('authorization'), body });
      if (state.openaiDelayMs) await new Promise((r) => setTimeout(r, state.openaiDelayMs));
      if (state.openaiStatus !== 200) {
        return new Response(JSON.stringify({ error: { message: `bad key ${FAKE_KEY}` } }), { status: state.openaiStatus });
      }
      return Response.json({
        choices: [{ message: { content: state.openaiContent } }],
        usage: { prompt_tokens: 1200, completion_tokens: 80 },
      });
    }
    if (u.pathname === '/rest/v1/store_members') {
      const ok = u.searchParams.get('store_id') === `eq.${S}` &&
        [`eq.${U}`, `eq.${U2}`].includes(u.searchParams.get('user_id') ?? '');
      return Response.json(ok ? [{ user_id: U }] : []);
    }
    if (u.pathname === '/rest/v1/stores') return Response.json([]);
    if (u.pathname === '/rest/v1/rpc/boom_qa_full_write_v1') {
      state.full.push(await req.json());
      return Response.json({ ok: true, id: crypto.randomUUID() });
    }
    if (u.pathname === '/rest/v1/rpc/admin_is_platform_admin_v1') {
      const p = await req.json();
      return Response.json(state.admins.includes(p.p_user));
    }
    if (u.pathname === '/rest/v1/boom_help_packs') {
      state.packQueries.push(u.search);
      if (u.searchParams.get('version') === 'eq.999') return Response.json([]); // app mới hơn máy chủ
      return Response.json([{ version: 1, content: { version: 1, chunks: [CHUNK] } }]);
    }
    if (u.pathname === '/rest/v1/boom_answer_cache') return Response.json(state.cache);
    if (u.pathname === '/rest/v1/boom_qa_log') {
      // trí nhớ: lọc theo người hỏi + 'ok' + có câu trả lời, mới → cũ
      state.memQueries.push(u.search);
      const user = (u.searchParams.get('user_id') ?? '').replace('eq.', '');
      const rows = state.logs.filter((l) => l.user === user && l.status === 'ok' && l.answer).reverse();
      return Response.json(rows.slice(0, Number(u.searchParams.get('limit') ?? 8)).map((l) => ({ question: l.question, answer: l.answer })));
    }
    if (u.pathname === '/rest/v1/user_accounts') {
      return Response.json(u.searchParams.get('id') === `eq.${U2}` ? [{ display_name: 'Trần Thị Lan', boom_xung_ho: 'chi' }] : []);
    }
    if (u.pathname === '/rest/v1/rpc/boom_cache_hit_v1') {
      const p = await req.json();
      if (p.p_cache_id === 'r1') return Response.json({ ok: false, status: 'retired' });
      const free = state.logs.filter((l) => l.user === p.p_user && ['no_context', 'blocked', 'cached'].includes(String(l.status)));
      if (free.length >= p.p_free_per_hour) return Response.json({ ok: false, status: 'rate_limited' });
      const row = { id: crypto.randomUUID(), status: 'cached', user: p.p_user, question: p.p_question, cache_id: p.p_cache_id } as Row;
      state.logs.push(row);
      return Response.json({ ok: true, status: 'cached', id: row.id, answer: state.cacheAnswers[p.p_cache_id] });
    }
    if (u.pathname === '/rest/v1/rpc/boom_ai_reserve_v1') {
      // mô phỏng hàm giữ chỗ có khoá: đếm + ghi trong cùng một bước (JS chạy đơn luồng)
      const p = await req.json();
      let status = 'pending';
      if (p.p_mode === 'log_only' || p.p_mode === 'blocked') {
        status = p.p_mode === 'blocked' ? 'blocked' : 'no_context';
        if (state.logs.filter((l) => ['no_context', 'blocked'].includes(String(l.status))).length >= p.p_unanswered_per_hour) {
          return Response.json({ ok: false, status: 'rate_limited' });
        }
      } else if (state.logs.filter((l) => ['pending', 'ok', 'error'].includes(String(l.status))).length >= p.p_user_per_hour) {
        return Response.json({ ok: false, status: 'rate_limited' }); // bị chặn: không ghi dòng
      }
      const row = { id: crypto.randomUUID(), status, user: p.p_user, question: p.p_question, chunk_ids: p.p_chunk_ids } as Row;
      state.logs.push(row);
      return Response.json({ ok: status === 'pending', status, id: row.id });
    }
    if (u.pathname === '/rest/v1/rpc/boom_feedback_v1') {
      const p = await req.json();
      const row = { id: crypto.randomUUID(), status: 'feedback', user: p.p_user, question: p.p_question, answer: p.p_answer, rating: p.p_rating, model: p.p_tool } as Row;
      state.logs.push(row);
      return Response.json({ ok: true, status: 'feedback', id: row.id });
    }
    if (u.pathname === '/rest/v1/rpc/boom_ai_finish_v1') {
      const p = await req.json();
      const row = state.logs.find((l) => l.id === p.p_id && l.status === 'pending');
      if (row) Object.assign(row, { status: p.p_status, answer: p.p_answer, cost_usd: p.p_cost_usd, model: p.p_model });
      return Response.json(!!row);
    }
    return new Response('not found', { status: 404 });
  });
}

const token = (claims: Row, secret = SECRET, exp = true) => {
  const j = new jose.SignJWT(claims).setProtectedHeader({ alg: 'HS256' });
  return (exp ? j.setExpirationTime('1h') : j).sign(new TextEncoder().encode(secret));
};

const call = (auth: string | null, body: Row) =>
  fetch(`${FN}/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: `Bearer ${auth}` } : {}) },
    body: JSON.stringify(body),
  });

Deno.test('boom-chat chạy thật với máy chủ giả', async (t) => {
  const srv = mock();
  const hash = await chunkHash([CHUNK]);
  state.cache = [
    { id: 'g1', kind: 'guide', questions: ['làm sao để huỷ món đã gửi bếp', 'huỷ món đã gửi bếp thế nào'], chunk_ids: [ID], chunk_hash: hash },
    { id: 'g-cu', kind: 'guide', questions: ['in lại phiếu bếp'], chunk_ids: [ID], chunk_hash: 'bai-da-doi' },
    { id: 'a1', kind: 'advice', questions: ['mẹo giữ chân khách quen'], chunk_ids: [], chunk_hash: null },
    { id: 'r1', kind: 'advice', questions: ['in tờ rơi quảng cáo'], chunk_ids: [], chunk_hash: null },
  ];
  state.cacheAnswers = { g1: '1. Bấm "Huỷ món" (đã duyệt).', a1: 'Dạ {goi} ơi, tích điểm cho khách quen (đã duyệt).' };
  const fn = new Deno.Command(Deno.execPath(), {
    args: ['run', '--allow-net', '--allow-env', fromFileUrl(new URL('./index.ts', import.meta.url))],
    env: {
      OPENAI_API_KEY: FAKE_KEY,
      BOOM_AI_ENABLED: 'true',
      BOOM_OPENAI_BASE_URL: `http://127.0.0.1:${MOCK}/v1`,
      BOOM_ALLOW_TEST_BASE: 'true',
      SUPABASE_URL: `http://127.0.0.1:${MOCK}`,
      SUPABASE_SERVICE_ROLE_KEY: 'svc-test',
      JWT_SECRET: SECRET,
      BOOM_USER_PER_HOUR: '6',
      BOOM_UNANSWERED_PER_HOUR: '3',
    },
    stdout: 'null',
    stderr: 'null',
  }).spawn();
  for (let i = 0; i < 50; i++) {
    try {
      await (await fetch(FN, { method: 'OPTIONS' })).body?.cancel();
      break;
    } catch {
      await new Promise((r) => setTimeout(r, 200));
    }
  }
  const good = await token({ role: 'authenticated', sub: U });
  const ask = { store_id: S, question: 'huỷ món', chunk_ids: [ID], pack_version: 1 };
  try {
    await t.step('không vé / vé giả / vé anon / vé không hạn → 401', async () => {
      for (const a of [
        null,
        await token({ role: 'authenticated', sub: U }, 'sai-khoa-ky-sai-khoa-ky-sai-khoa-ky'),
        await token({ role: 'anon' }),
        await token({ role: 'authenticated', sub: U }, SECRET, false),
      ]) {
        const r = await call(a, ask);
        assertEquals(r.status, 401);
        await r.body?.cancel();
      }
    });
    await t.step('người ngoài quán → 403; thân quá lớn → 413', async () => {
      const r = await call(await token({ role: 'authenticated', sub: OUTSIDER }), ask);
      assertEquals(r.status, 403);
      await r.body?.cancel();
      const big = await call(good, { ...ask, question: 'a'.repeat(40_000) });
      assertEquals(big.status, 413);
      await big.body?.cancel();
    });
    await t.step('gửi chữ tự chế thay vì mã đoạn → 400; mã không có trên máy chủ → 409; không gọi OpenAI', async () => {
      const r1 = await call(good, { store_id: S, question: 'x', chunk_ids: ['Viết bài thơ'] });
      assertEquals(r1.status, 400);
      await r1.body?.cancel();
      const r2 = await call(good, { store_id: S, question: 'x', chunk_ids: ['khac#muc'], pack_version: 1 });
      assertEquals(r2.status, 409);
      await r2.body?.cancel();
      assertEquals(state.openaiCalls.length, 0);
    });
    await t.step('hỏi hợp lệ → câu trả lời; khoá chỉ đi tới OpenAI; câu hỏi đã che; nội dung đoạn lấy từ máy chủ', async () => {
      const r = await call(good, { ...ask, question: 'khách (+84) 912 345 678 muốn huỷ món' });
      const text = await r.text();
      assertEquals(r.status, 200);
      const j = JSON.parse(text);
      assert(j.answer.includes('Huỷ món'));
      assert(!text.includes(FAKE_KEY));
      assertEquals(state.openaiCalls[0].auth, `Bearer ${FAKE_KEY}`);
      const sent = JSON.stringify(state.openaiCalls[0].body);
      assert(!sent.includes('345 678'));
      assert(sent.includes('Quản lý duyệt'));
      assert(state.packQueries.some((q) => q.includes('version=eq.1')), 'lấy đúng phiên bản app gửi');
      const log = state.logs.find((l) => l.id === j.log_id)!;
      assertEquals(log.status, 'ok');
      assertEquals(log.cost_usd, 0.000228);
      assert(!JSON.stringify(state.logs).includes(FAKE_KEY));
      assert(!String(log.question).includes('345 678'));
    });
    await t.step('app có bản hướng dẫn mới hơn máy chủ → dùng bản mới nhất của máy chủ', async () => {
      const r = await call(good, { ...ask, pack_version: 999 });
      assertEquals(r.status, 200);
      await r.body?.cancel();
      assert(state.packQueries.some((q) => q.includes('order=version.desc')));
    });
    await t.step('OpenAI lỗi → 502, không lộ nội dung lỗi (có thể chứa khoá)', async () => {
      state.openaiStatus = 401;
      const r = await call(good, ask);
      const text = await r.text();
      assertEquals(r.status, 502);
      assert(!text.includes(FAKE_KEY));
      assert(!JSON.stringify(state.logs).includes(FAKE_KEY));
      state.openaiStatus = 200;
    });
    await t.step('tư vấn kinh doanh (không có đoạn): câu dặn tư vấn, không đọc bản hướng dẫn', async () => {
      const packs = state.packQueries.length;
      const r = await call(good, { store_id: S, question: 'làm sao tăng khách buổi sáng', mode: 'advice', chunk_ids: [] });
      assertEquals(r.status, 200);
      const j = await r.json();
      assert(j.log_id);
      const sys = String((state.openaiCalls.at(-1)!.body.messages as Row[])[0].content);
      assert(sys.includes('TƯ VẤN KINH DOANH'));
      assert(sys.includes('đánh giá chính trị, đảng phái, lãnh đạo; tranh luận tôn giáo'));
      assertEquals(state.packQueries.length, packs);
    });
    await t.step('trí nhớ 5 giờ: câu tư vấn sau nhớ lượt trước của CHÍNH người hỏi; người khác không thấy', async () => {
      const logsBefore = state.logs.length; // không làm lệch các bước đếm hạn mức phía sau
      const r = await call(good, { store_id: S, question: 'vậy nên làm gì trước', mode: 'advice', chunk_ids: [], memory_age_s: 3600 });
      assertEquals(r.status, 200);
      await r.body?.cancel();
      const user = String((state.openaiCalls.at(-1)!.body.messages as Row[])[1].content);
      assert(user.startsWith('TRAO ĐỔI GẦN ĐÂY'), user);
      assert(user.includes('Người hỏi: làm sao tăng khách buổi sáng'));
      const q = state.memQueries.at(-1)!;
      assert(q.includes(`user_id=eq.${U}`) && q.includes(`store_id=eq.${S}`) && q.includes('status=eq.ok') && q.includes('created_at=gte.'));
      // người khác cùng quán: không có lượt nào của họ → không có khối trí nhớ
      const other = await token({ role: 'authenticated', sub: U2 });
      const r2 = await call(other, { store_id: S, question: 'nên khuyến mãi gì cuối tuần', mode: 'advice', chunk_ids: [] });
      assertEquals(r2.status, 200);
      await r2.body?.cancel();
      assert(!String((state.openaiCalls.at(-1)!.body.messages as Row[])[1].content).includes('TRAO ĐỔI GẦN ĐÂY'));
      state.logs.splice(logsBefore);
    });
    await t.step('so sánh chi nhánh: GPT nhận số chuỗi; sổ hỏi đáp KHÔNG lưu số chuỗi (quản lý quán đọc được sổ — QC 25/10)', async () => {
      const logsBefore = state.logs.length;
      const chain = { name: 'Chuỗi A', period: 'Tháng này', stores: [{ name: 'CN Bí Mật', revenue: 98765432, orders: 9 }] };
      const r = await call(good, { store_id: S, question: 'so sánh doanh thu các chi nhánh', mode: 'advice', chunk_ids: [], chain });
      assertEquals(r.status, 200);
      const j = await r.json();
      const um = String((state.openaiCalls.at(-1)!.body.messages as Row[])[1].content);
      assert(um.includes('98.765.432đ'), JSON.stringify(j) + um.slice(0, 400));
      const row = state.logs.find((l) => l.id === j.log_id)!;
      assertEquals(row.answer, CHAIN_LOG_NOTE);
      assert(String(row.model).includes('so_lieu') && String(row.model).includes('chuoi'));
      const f = await call(good, {
        store_id: S, question: 'so sánh doanh thu các chi nhánh', mode: 'feedback', rating: 'down',
        answer: 'CN Bí Mật 98.765.432đ', reason: null, tool: 'boom_so_lieu_chuoi_du_phong', chunk_ids: [],
      });
      await f.body?.cancel();
      assert(!JSON.stringify(state.logs).includes('98.765.432'));
      // số các module: GPT nhận, sổ không lưu
      const m = await call(good, { store_id: S, question: 'tháng này chi phí gì nhiều nhất', mode: 'advice', chunk_ids: [],
        modules: { finance: { period: 'Tháng này', income: 1, expense: 87654321, top_expense: [{ name: 'Bí mật', amount: 87654321 }] } } });
      const mj = await m.json();
      assert(String((state.openaiCalls.at(-1)!.body.messages as Row[])[1].content).includes('87.654.321đ'));
      const mrow = state.logs.find((l) => l.id === mj.log_id)!;
      assertEquals(mrow.answer, MODULE_LOG_NOTE);
      assert(String(mrow.model).includes('so_lieu') && String(mrow.model).includes('module'));
      assert(!JSON.stringify(state.logs).includes('87.654.321'));
      state.logs.splice(logsBefore);
    });
    await t.step('trang quản trị: lịch sử NGUYÊN VĂN (kể cả số), câu app tự trả, lời dặn chỉ cho vé quản trị', async () => {
      const logsBefore = state.logs.length;
      state.full.length = 0;
      const m = await call(good, { store_id: S, question: 'tháng này chi phí gì nhiều nhất', mode: 'advice', chunk_ids: [],
        modules: { finance: { period: 'Tháng này', income: 1, expense: 55555555 } } });
      await m.body?.cancel();
      const g = state.full.at(-1)!;
      assertEquals(g.p_source, 'gpt');
      assertEquals(g.p_answer, state.openaiContent); // sổ thường bị che, bảng quản trị giữ nguyên văn
      assert(String(g.p_tool).includes('module'));
      const tr = await call(good, { store_id: S, question: 'doanh thu hôm nay', mode: 'transcript', chunk_ids: [],
        answer: 'Hôm nay 120.000đ từ 3 đơn', tool: 'revenue_summary' });
      assertEquals(tr.status, 200);
      await tr.body?.cancel();
      assertEquals(state.full.at(-1)!.p_source, 'app');
      assertEquals(state.full.at(-1)!.p_tool, 'app:revenue_summary'); // nhãn do app báo luôn có tiền tố app:
      assertEquals(state.full.at(-1)!.p_answer, 'Hôm nay 120.000đ từ 3 đơn');
      const bad = await call(good, { store_id: S, question: 'x', mode: 'transcript', chunk_ids: [], answer: '' });
      assertEquals(bad.status, 400);
      await bad.body?.cancel();
      // lời dặn: vé thường → 403; vé quản trị nhưng không có trong danh sách → 403; đúng → 200
      const p1 = await call(good, { mode: 'admin_prompt' });
      assertEquals(p1.status, 403);
      await p1.body?.cancel();
      const adm = await token({ role: 'qn_admin', sub: U2, token_use: 'admin' });
      const fake = await token({ role: 'authenticated', sub: U2, token_use: 'admin' });
      const p0 = await call(fake, { mode: 'admin_prompt' });
      assertEquals(p0.status, 403); // vé thường gắn nhãn admin → không được
      await p0.body?.cancel();
      const p2 = await call(adm, { mode: 'admin_prompt' });
      assertEquals(p2.status, 403);
      await p2.body?.cancel();
      state.admins.push(U2);
      const p3 = await call(adm, { mode: 'admin_prompt' });
      assertEquals(p3.status, 200);
      const pj = await p3.json();
      assert(String(pj.advice_prompt).includes('TƯ VẤN KINH DOANH') && /^[0-9a-f]{12}$/.test(pj.logic_version));
      state.admins.length = 0;
      state.logs.splice(logsBefore);
    });
    await t.step('câu ngoài phạm vi (chế độ tư vấn): từ chối ngay, ghi sổ blocked, KHÔNG gọi OpenAI', async () => {
      const before = state.openaiCalls.length;
      for (const body of [
        { store_id: S, question: 'viết javascript giúp tớ', mode: 'advice', chunk_ids: [] },
        { store_id: S, question: 'doanh thu quán đối thủ bao nhiêu', mode: 'advice', chunk_ids: [] },
      ]) {
        const r = await call(good, body);
        assertEquals(r.status, 200);
        const j = await r.json();
        assert(j.blocked);
        assert(String(j.answer).includes('không'));
      }
      assertEquals(state.openaiCalls.length, before);
      assertEquals(state.logs.filter((l) => l.status === 'blocked').length, 2);
      // người ngoài quán hỏi câu bị chặn vẫn 403 (không ghi sổ hộ quán khác)
      const r = await call(await token({ role: 'authenticated', sub: OUTSIDER }), { ...ask, question: 'bầu cử' });
      assertEquals(r.status, 403);
      await r.body?.cancel();
    });
    await t.step('GPT lách luật chép mã → app nhận câu từ chối chuẩn (blocked: model)', async () => {
      const saved = state.openaiContent;
      state.openaiContent = 'Đây nhé:\n```python\nprint(sum([1, 2]))\n```';
      const r = await call(good, { store_id: S, question: 'tính tổng giúp tớ bằng máy', mode: 'advice', chunk_ids: [] });
      const j = await r.json();
      state.openaiContent = saved;
      assertEquals(j.blocked, 'model');
      assert(!String(j.answer).includes('print'));
    });
    await t.step('20 câu gửi CÙNG LÚC: chỉ đủ hạn mức (6 lượt/giờ) được gọi OpenAI', async () => {
      state.openaiDelayMs = 300;
      const before = state.openaiCalls.length; // đã dùng 5 lượt (hạn mức 6)
      const rs = await Promise.all(Array.from({ length: 20 }, () => call(good, ask)));
      const codes = rs.map((r) => r.status);
      await Promise.all(rs.map((r) => r.body?.cancel()));
      assertEquals(codes.filter((c) => c === 200).length, 1);
      assertEquals(codes.filter((c) => c === 429).length, 19);
      assertEquals(state.openaiCalls.length - before, 1);
      state.openaiDelayMs = 0;
    });
    await t.step('câu không có hướng dẫn: chỉ ghi sổ, hạn mức riêng (chung với câu bị chặn), không gọi OpenAI', async () => {
      const before = state.openaiCalls.length;
      // hạn mức 3/giờ, đã có 2 câu bị chặn → chỉ ghi thêm 1
      const rs = [];
      for (let i = 0; i < 3; i++) rs.push(await call(good, { store_id: S, question: 'thời tiết', mode: 'log_only', chunk_ids: [] }));
      const bodies = await Promise.all(rs.map((r) => r.json()));
      assertEquals(bodies.map((b) => b.logged), [true, false, false]);
      assertEquals(state.logs.filter((l) => l.status === 'no_context').length, 1);
      assertEquals(state.openaiCalls.length, before);
    });
    await t.step('👍/👎 câu số liệu: ghi sổ feedback (đã che số), không gọi OpenAI', async () => {
      const before = state.openaiCalls.length;
      const u2 = await token({ role: 'authenticated', sub: U2 });
      const r = await call(u2, {
        store_id: S, question: 'doanh thu tháng này gọi 0912345678', mode: 'feedback', rating: 'down',
        answer: 'Hôm nay quán chưa có đơn', reason: 'sai kỳ', tool: 'orders_summary_read_only',
      });
      const j = await r.json();
      assertEquals(r.status, 200);
      assertEquals(j.logged, true);
      const row = state.logs.find((l) => l.id === j.log_id)!;
      assertEquals(row.rating, 'down');
      assert(!String(row.question).includes('0912345678'));
      assertEquals(state.openaiCalls.length, before);
    });
    await t.step('bộ nhớ câu đã duyệt: cách hỏi khác vẫn khớp, không gọi OpenAI; bài đã đổi / câu bị gỡ → không dùng', async () => {
      const u2 = await token({ role: 'authenticated', sub: U2 });
      const before = state.openaiCalls.length;
      const r1 = await call(u2, { ...ask, question: 'Boom ơi hủy món đã gửi bếp thế nào?' });
      const j1 = await r1.json();
      assertEquals(r1.status, 200);
      assertEquals(j1.cached, true);
      assertEquals(j1.answer, '1. Bấm "Huỷ món" (đã duyệt).');
      assert(j1.log_id);
      const r2 = await call(u2, { store_id: S, question: 'cho tớ hỏi mẹo giữ chân khách quen', mode: 'advice', chunk_ids: [] });
      assertEquals((await r2.json()).answer, 'Dạ Chị Lan ơi, tích điểm cho khách quen (đã duyệt).'); // {goi} điền theo người hỏi
      // app xếp bài đúng thứ 2 trong 3 đoạn gửi lên → vẫn dùng câu đã duyệt (26/10)
      const r3 = await call(u2, { ...ask, question: 'làm sao để huỷ món đã gửi bếp', chunk_ids: ['khac#muc-gan', ID] });
      assertEquals((await r3.json()).cached, true);
      assertEquals(state.openaiCalls.length, before);
      assertEquals(state.logs.filter((l) => l.status === 'cached').length, 3);
      // "chưa gửi bếp" khác nghĩa "đã gửi bếp" → không trả câu đã duyệt
      for (const body of [
        { ...ask, question: 'huỷ món chưa gửi bếp' },
        { ...ask, question: 'in lại phiếu bếp' }, // bài hướng dẫn đã đổi sau khi duyệt
        { store_id: S, question: 'in tờ rơi quảng cáo', mode: 'advice', chunk_ids: [] }, // vừa bị gỡ
      ]) {
        const r = await call(u2, body);
        const j = await r.json();
        assert(!j.cached, JSON.stringify(body));
      }
    });
  } finally {
    fn.kill();
    await fn.status;
    await srv.shutdown();
  }
});
