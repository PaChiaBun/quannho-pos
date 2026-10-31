// Hàm máy chủ boom-chat — Boom trả lời câu hỏi "cách làm" bằng GPT (mặc định gpt-4o-mini) DỰA TRÊN đoạn hướng dẫn.
// ke-hoach-trien-khai-boom.md Bước 4.2. Khoá OpenAI chỉ đọc từ biến môi trường của dịch vụ hàm trên VPS —
// không bao giờ trả về app, không ghi vào sổ / nhật ký. App chỉ gửi MÃ đoạn hướng dẫn; nội dung lấy từ bản
// hướng dẫn đã đăng trên máy chủ (boom_help_packs) → không dùng hàm này làm cổng GPT tuỳ ý được.
// Chế độ 'advice' (24/10): tư vấn kinh doanh cho quán khi không có đoạn hướng dẫn liên quan.
// Luật của Boom (logic.ts): ở chế độ tư vấn / ghi sổ, câu chắc chắn ngoài phạm vi (chính trị, tôn giáo, lập trình,
// số liệu quán khác…) bị chặn TRƯỚC khi gọi GPT — trả câu từ chối, ghi sổ 'blocked', không tốn tiền. Chế độ trả lời
// theo hướng dẫn KHÔNG qua bộ lọc (đã gắn đoạn hướng dẫn cụ thể; bộ lọc chặn nhầm sẽ che mất bài đã duyệt).
// Bộ nhớ câu đã duyệt (Bước 4.3): câu hỏi giống câu đã duyệt → trả câu đó, KHÔNG gọi GPT (chạy cả khi chưa có
// khoá; tắt riêng bằng BOOM_CACHE_ENABLED=false). Câu loại hướng dẫn chỉ dùng khi bài hướng dẫn chưa đổi.
// Lớp hai: câu dặn GPT có luật; câu trả lời chép mã / GPT tự từ chối → trả câu từ chối chuẩn (blocked: 'model').
//
// Biến môi trường:
//   OPENAI_API_KEY (thiếu → AI_DISABLED, app trả nguyên văn)   BOOM_AI_ENABLED (mặc định false)
//   BOOM_OPENAI_MODEL (gpt-4o-mini)          BOOM_USER_PER_HOUR (30)        BOOM_UNANSWERED_PER_HOUR (60)
//   BOOM_STORE_USD_PER_DAY (0.5)             BOOM_STORE_USD_PER_MONTH (3)   BOOM_MONTH_USD_CAP (10, cả hệ thống)
//   BOOM_PRICE_IN_PER_M / BOOM_PRICE_OUT_PER_M (0.15 / 0.6)   BOOM_CACHE_ENABLED (mặc định true)
//   BOOM_OPENAI_BASE_URL + BOOM_ALLOW_TEST_BASE=true — CHỈ khi test (không thì luôn là api.openai.com)
//   JWT_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (có sẵn trong dịch vụ hàm của Supabase tự host)
import * as jose from 'jsr:@panva/jose@6';
import {
  ADVICE_PROMPT,
  SYSTEM_PROMPT,
  blockReason,
  CHAIN_LOG_NOTE,
  MODULE_LOG_NOTE,
  buildMessages,
  cacheKey,
  type CachedAnswer,
  chunkHash,
  clipAnswer,
  costUsd,
  findCached,
  goiNguoiHoi,
  DANH_XUNG,
  type HelpChunk,
  type Persona,
  modelRefused,
  isUuid,
  LIMITS,
  openaiBase,
  packToMap,
  parseRequest,
  pickChunks,
  plainAnswer,
  REFUSAL,
  RETRY_SCOPE_NOTE,
  looksBusiness,
  loaiCau,
  isScopeRefusal,
  guessesAppFeature,
  memorySince,
  type MemoryTurn,
  pickMemory,
  redact,
  refusalFor,
  kiemTraLoi,
  noteKiem,
  soLieuGoc,
} from './logic.ts';

const env = (k: string, d = '') => Deno.env.get(k) ?? d;
const num = (k: string, d: number) => {
  const v = Number(env(k));
  return Number.isFinite(v) && v > 0 ? v : d;
};

const OPENAI_KEY = env('OPENAI_API_KEY');
const MODEL = env('BOOM_OPENAI_MODEL', 'gpt-4o-mini');
const ENABLED = env('BOOM_AI_ENABLED', 'false') === 'true';
const CACHE_ON = env('BOOM_CACHE_ENABLED', 'true') !== 'false';
const OPENAI_BASE = openaiBase(env('BOOM_OPENAI_BASE_URL'), env('BOOM_ALLOW_TEST_BASE') === 'true');
const QUOTA = {
  p_user_per_hour: num('BOOM_USER_PER_HOUR', 30),
  p_unanswered_per_hour: num('BOOM_UNANSWERED_PER_HOUR', 60),
  p_store_usd_day: num('BOOM_STORE_USD_PER_DAY', 0.5),
  p_store_usd_month: num('BOOM_STORE_USD_PER_MONTH', 3),
  p_global_usd_month: num('BOOM_MONTH_USD_CAP', 10),
};
const PRICES = { inPerM: num('BOOM_PRICE_IN_PER_M', 0.15), outPerM: num('BOOM_PRICE_OUT_PER_M', 0.6) };
const UPSTREAM_TIMEOUT_MS = 12_000; // app chờ 20 giây — máy chủ bỏ trước để không trả tiền cho câu không ai thấy
const SB_URL = env('SUPABASE_URL', 'http://kong:8000');
const SERVICE_KEY = env('SUPABASE_SERVICE_ROLE_KEY');
const JWT_SECRET = env('JWT_SECRET');

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
}

const svcHeaders = () => ({
  apikey: SERVICE_KEY,
  Authorization: `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
});

/** Vé quản trị (token_use = 'admin', cổng /api/auth/admin-jwt cấp) → id người dùng; null nếu không phải. */
async function adminCaller(req: Request): Promise<string | null> {
  const h = req.headers.get('authorization') ?? '';
  const token = h.startsWith('Bearer ') ? h.slice(7).trim() : '';
  if (!token || !JWT_SECRET) return null;
  try {
    const { payload } = await jose.jwtVerify(token, new TextEncoder().encode(JWT_SECRET), {
      algorithms: ['HS256'],
      requiredClaims: ['exp', 'sub'],
    });
    if (payload.role !== 'qn_admin' || payload.token_use !== 'admin' || !isUuid(payload.sub)) return null;
    const ok = await rest('rpc/admin_is_platform_admin_v1', { method: 'POST', body: JSON.stringify({ p_user: payload.sub }) });
    return ok === true ? (payload.sub as string) : null;
  } catch {
    return null;
  }
}

/** Lịch sử NGUYÊN VĂN cho trang quản trị (bảng khoá, chỉ hàm admin_* đọc). Lỗi ghi không ảnh hưởng câu trả lời. */
async function writeFull(row: {
  log_id?: string | null; store_id: string; user_id: string; source: 'gpt' | 'app'; tool: string | null;
  question: string; answer: string | null; chunk_ids?: string[];
}): Promise<boolean> {
  try {
    const res = await rest('rpc/boom_qa_full_write_v1', {
      method: 'POST',
      body: JSON.stringify({
        p_log_id: row.log_id ?? null, p_store: row.store_id, p_user: row.user_id, p_source: row.source,
        p_tool: row.tool, p_question: redact(row.question), p_answer: row.answer === null ? null : redact(row.answer),
        p_chunk_ids: row.chunk_ids ?? [],
      }),
      signal: AbortSignal.timeout(2000),
    }) as { ok?: boolean };
    return res?.ok === true;
  } catch {
    return false; // bảng chưa có / chậm → bỏ qua
  }
}

/** Người gọi: JWT HS256 của app (role authenticated, có hạn) → id người dùng; null nếu không hợp lệ. */
async function callerId(req: Request): Promise<string | null> {
  const h = req.headers.get('authorization') ?? '';
  const token = h.startsWith('Bearer ') ? h.slice(7).trim() : '';
  if (!token || !JWT_SECRET) return null;
  try {
    const { payload } = await jose.jwtVerify(token, new TextEncoder().encode(JWT_SECRET), {
      algorithms: ['HS256'],
      requiredClaims: ['exp', 'sub'],
    });
    return payload.role === 'authenticated' && isUuid(payload.sub) ? (payload.sub as string) : null;
  } catch {
    return null;
  }
}

async function rest(path: string, init?: RequestInit) {
  const r = await fetch(`${SB_URL}/rest/v1/${path}`, { ...init, headers: svcHeaders() });
  if (!r.ok) throw new Error(`REST_${r.status}`);
  return await r.json();
}

async function isMember(storeId: string, userId: string): Promise<boolean> {
  const [m, o] = await Promise.all([
    rest(`store_members?select=user_id&store_id=eq.${storeId}&user_id=eq.${userId}&limit=1`),
    rest(`stores?select=id&id=eq.${storeId}&owner_user_id=eq.${userId}&limit=1`),
  ]);
  return (Array.isArray(m) && m.length > 0) || (Array.isArray(o) && o.length > 0);
}

/** Trí nhớ 5 giờ: tối đa 4 lượt GPT trả lời gần nhất của người hỏi ở quán này (lỗi → không nhớ). */
async function recall(storeId: string, userId: string, since: Date): Promise<{ turns: MemoryTurn[]; hasData: boolean }> {
  try {
    const rows = await rest(
      `boom_qa_log?select=question,answer,rating,model&user_id=eq.${userId}&store_id=eq.${storeId}&status=eq.ok` +
        `&answer=not.is.null&created_at=gte.${encodeURIComponent(since.toISOString())}&order=created_at.desc&limit=8`,
      { signal: AbortSignal.timeout(1500) }, // sổ chậm → bỏ trí nhớ, không làm treo câu trả lời
    );
    if (!Array.isArray(rows)) return { turns: [], hasData: false };
    // Trí nhớ có câu trả lời kèm số liệu riêng của quán → lượt này cũng gắn nhãn số liệu (ẩn khỏi hàng chờ duyệt)
    return { turns: pickMemory(rows), hasData: rows.some((x) => String(x?.model ?? '').includes('so_lieu')) };
  } catch {
    return { turns: [], hasData: false };
  }
}

/** Tên + cách gọi (Anh / Chị) người hỏi tự chọn — lỗi / chưa có thì Boom gọi "Anh/Chị". */
async function persona(userId: string): Promise<Persona | null> {
  try {
    const rows = await rest(`user_accounts?select=display_name,boom_xung_ho&id=eq.${userId}&limit=1`);
    const r = Array.isArray(rows) ? rows[0] : null;
    if (!r) return null;
    const x = typeof r.boom_xung_ho === 'string' && Object.hasOwn(DANH_XUNG, r.boom_xung_ho) ? r.boom_xung_ho : null;
    return { xung_ho: x, ten: typeof r.display_name === 'string' ? r.display_name : null };
  } catch {
    return null;
  }
}

// Bản hướng dẫn đã đăng. Mỗi phiên bản không bao giờ sửa → giữ trong bộ nhớ theo phiên bản.
// App gửi phiên bản nó đang dùng; máy chủ chưa có bản đó (app mới hơn) → dùng bản mới nhất.
const packByVersion = new Map<number, Map<string, HelpChunk>>();
async function helpPack(version: number | null): Promise<Map<string, HelpChunk>> {
  if (version !== null && packByVersion.has(version)) return packByVersion.get(version)!;
  let rows = version !== null ? await rest(`boom_help_packs?select=version,content&version=eq.${version}`) : [];
  if (!Array.isArray(rows) || rows.length === 0) {
    rows = await rest('boom_help_packs?select=version,content&order=version.desc&limit=1');
  }
  const row = Array.isArray(rows) ? rows[0] : null;
  const map = packToMap(row ? row.content : null);
  if (row && typeof row.version === 'number' && packByVersion.size < 20) packByVersion.set(row.version, map);
  return map;
}

// Bộ nhớ câu đã duyệt — nạp lại sau 5 phút (duyệt thêm / gỡ câu có tác dụng trong ≤ 5 phút); khoá so khớp tính
// sẵn một lần khi nạp. Nạp lỗi (chưa có bảng…) → coi như trống trong 1 phút, không gọi lại mỗi câu.
let cacheList: { at: number; ttl: number; list: CachedAnswer[] } | null = null;
async function cachedAnswers(): Promise<CachedAnswer[]> {
  if (cacheList && Date.now() - cacheList.at < cacheList.ttl) return cacheList.list;
  try {
    const rows = await rest(
      'boom_answer_cache?select=id,kind,questions,chunk_ids,chunk_hash&status=eq.approved&order=created_at.desc&limit=3000',
    );
    const list = (Array.isArray(rows) ? rows : []) as CachedAnswer[];
    for (const e of list) e.keys = e.questions.map(cacheKey).filter(Boolean);
    cacheList = { at: Date.now(), ttl: 5 * 60_000, list };
  } catch {
    cacheList = { at: Date.now(), ttl: 60_000, list: [] };
  }
  return cacheList.list;
}

/** Trả câu đã duyệt nếu khớp; null = không có / lỗi → gọi GPT như thường. */
async function fromCache(
  r: { store_id: string; question: string; mode: string; chunk_ids: string[]; pack_version: number | null },
  user: string,
) {
  let hit;
  try {
    hit = findCached(await cachedAnswers(), r.question, r.mode === 'answer' ? 'guide' : 'advice', r.chunk_ids);
    if (!hit) return null;
    if (hit.entry.kind === 'guide') {
      const chunks = pickChunks(await helpPack(r.pack_version), hit.entry.chunk_ids);
      if (!chunks || (await chunkHash(chunks)) !== hit.entry.chunk_hash) return null; // bài đã đổi
    }
  } catch {
    return null;
  }
  try {
    const res = await rest('rpc/boom_cache_hit_v1', {
      method: 'POST',
      body: JSON.stringify({
        p_store: r.store_id,
        p_user: user,
        p_question: redact(r.question),
        p_cache_id: hit.entry.id,
        p_free_per_hour: QUOTA.p_unanswered_per_hour,
      }),
    }) as { ok: boolean; status: string; id?: string; answer?: string };
    if (res.ok && res.answer) {
      // Câu đã duyệt dùng chung mọi quán: cách gọi viết "{goi}" → điền đúng người đang hỏi ("Chị Lan"…)
      const answer = res.answer.includes('{goi}') ? res.answer.replaceAll('{goi}', goiNguoiHoi(await persona(user))) : res.answer;
      await writeFull({ log_id: res.id, store_id: r.store_id, user_id: user, source: 'gpt', tool: `cache:${r.mode}`,
        question: r.question, answer, chunk_ids: hit.entry.chunk_ids });
      return json(200, { answer, log_id: res.id, model: 'cache', cached: true });
    }
    if (res.status === 'retired') cacheList = null; // vừa bị gỡ → nạp lại lần sau
    if (res.status === 'inactive_store') return json(403, { error: 'STORE_INACTIVE' });
    return null; // bị gỡ / hết lượt bộ nhớ → đi đường GPT thường (hạn mức GPT riêng)
  } catch {
    return null;
  }
}

async function reserve(r: { store_id: string; question: string; chunk_ids: string[]; mode: string }, user: string) {
  return await rest('rpc/boom_ai_reserve_v1', {
    method: 'POST',
    body: JSON.stringify({
      p_store: r.store_id,
      p_user: user,
      p_question: redact(r.question),
      p_chunk_ids: r.chunk_ids,
      p_mode: r.mode,
      ...QUOTA,
    }),
  }) as { ok: boolean; status: string; id?: string };
}

async function finish(id: string, row: Record<string, unknown>) {
  try {
    await rest('rpc/boom_ai_finish_v1', {
      method: 'POST',
      body: JSON.stringify({
        p_id: id,
        p_status: row.status,
        p_answer: row.answer ?? null,
        p_model: row.model ?? MODEL,
        p_input_tokens: row.input_tokens ?? 0,
        p_output_tokens: row.output_tokens ?? 0,
        p_cost_usd: row.cost_usd ?? 0,
        p_latency_ms: row.latency_ms ?? null,
      }),
    });
  } catch {
    // ghi sổ lỗi không làm hỏng câu trả lời
  }
}

const STATUS_ERROR: Record<string, [number, string]> = {
  rate_limited: [429, 'RATE_LIMITED'],
  budget: [429, 'BUDGET_EXCEEDED'],
  inactive_store: [403, 'STORE_INACTIVE'],
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json(405, { error: 'METHOD_NOT_ALLOWED' });
  const len = Number(req.headers.get('content-length') ?? '0');
  if (len > LIMITS.bodyMaxBytes) return json(413, { error: 'TOO_LARGE' });

  // Không có vé → 401 ngay, chưa đọc nội dung
  if (!(req.headers.get('authorization') ?? '').startsWith('Bearer ')) return json(401, { error: 'UNAUTHORIZED' });

  let body: unknown;
  try {
    const raw = await req.text();
    if (raw.length > LIMITS.bodyMaxBytes) return json(413, { error: 'TOO_LARGE' });
    body = JSON.parse(raw);
  } catch {
    return json(400, { error: 'BAD_REQUEST' });
  }

  // Trang quản trị: xem nguyên văn lời dặn đang chạy (chỉ vé quản trị + tài khoản quản trị riêng còn hiệu lực)
  if ((body as Record<string, unknown> | null)?.mode === 'admin_prompt') {
    if (!(await adminCaller(req))) return json(403, { error: 'FORBIDDEN' });
    return json(200, {
      // mã phiên bản lời dặn = 12 ký tự đầu SHA-256 của hai lời dặn (đổi lời dặn → đổi mã)
      model: MODEL, enabled: ENABLED, cache_on: CACHE_ON,
      logic_version: [...new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(ADVICE_PROMPT + SYSTEM_PROMPT)))]
        .map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 12),
      advice_prompt: ADVICE_PROMPT, guide_prompt: SYSTEM_PROMPT, refusal: REFUSAL,
    });
  }
  const user = await callerId(req);
  if (!user) return json(401, { error: 'UNAUTHORIZED' });


  const parsed = parseRequest(body);
  if (!parsed.ok) return json(400, { error: parsed.error });
  const r = parsed.req;

  try {
    if (!(await isMember(r.store_id, user))) return json(403, { error: 'NOT_STORE_MEMBER' });
  } catch {
    return json(503, { error: 'SERVER_BUSY' });
  }

  // 👍/👎 cho câu trả lời không gọi GPT → một dòng 'feedback' trong sổ (không tốn tiền; hạn mức "không tốn tiền").
  if (r.mode === 'feedback' && r.feedback) {
    try {
      const res = await rest('rpc/boom_feedback_v1', {
        method: 'POST',
        body: JSON.stringify({
          p_store: r.store_id,
          p_user: user,
          p_question: redact(r.question),
          p_answer: r.feedback.tool?.includes('chuoi') ? CHAIN_LOG_NOTE : r.feedback.tool?.includes('module') ? MODULE_LOG_NOTE : redact(r.feedback.answer),
          p_rating: r.feedback.rating,
          p_reason: r.feedback.reason ? redact(r.feedback.reason) : null,
          p_tool: r.feedback.tool,
          p_free_per_hour: QUOTA.p_unanswered_per_hour,
        }),
      }) as { ok: boolean; status: string; id?: string };
      if (res.ok) return json(200, { logged: true, log_id: res.id });
      const [code, err] = STATUS_ERROR[res.status] ?? [400, 'BAD_FEEDBACK'];
      return json(code, { error: err });
    } catch {
      return json(503, { error: 'SERVER_BUSY' });
    }
  }

  // Câu app tự trả (số liệu nhanh, hướng dẫn nguyên văn, chào hỏi…) → chỉ ghi lịch sử nguyên văn, không gọi GPT.
  if (r.mode === 'transcript' && r.transcript) {
    // Câu do app tự báo → nhãn luôn bắt đầu 'app:' (không giả được nhãn câu GPT / bộ nhớ đã duyệt — QC 26/10)
    const ok = await writeFull({ store_id: r.store_id, user_id: user, source: 'app',
      tool: `app:${(r.transcript.tool ?? 'khac').replace(/^app:/, '')}`.slice(0, 80),
      question: r.question, answer: r.transcript.answer });
    return json(200, { logged: ok });
  }

  // Luật: câu ngoài phạm vi → từ chối ngay, chỉ ghi sổ (hạn mức chung với câu không có hướng dẫn).
  const why = r.mode === 'answer' ? null : blockReason(r.question);
  if (why) {
    try {
      const res = await reserve({ ...r, mode: 'blocked', chunk_ids: [] }, user);
      // Chỉ ghi lịch sử khi sổ nhận (còn hạn mức) — gửi câu bị chặn liên tục không làm đầy bảng (QC 26/10)
      if (res.ok && res.id) {
        await writeFull({ log_id: res.id, store_id: r.store_id, user_id: user, source: 'gpt', tool: `boom_tu_choi:${why}`,
          question: r.question, answer: refusalFor(why) });
      }
    } catch {
      // ghi sổ lỗi không ảnh hưởng câu từ chối
    }
    return json(200, { answer: refusalFor(why), blocked: why });
  }

  // Câu Boom không tìm thấy hướng dẫn — chỉ ghi sổ (hàng chờ cải thiện, có hạn mức riêng), không gọi GPT.
  if (r.mode === 'log_only') {
    try {
      const res = await reserve(r, user);
      return json(200, { logged: res.status === 'no_context' });
    } catch {
      return json(503, { error: 'SERVER_BUSY' });
    }
  }

  // Câu kèm số liệu / lượt trước: câu trả lời tuỳ ngữ cảnh → không dùng bộ nhớ câu đã duyệt.
  if (CACHE_ON && !r.facts && !r.chain && !r.modules && !r.history) {
    const cached = await fromCache(r, user);
    if (cached) return cached;
  }

  if (!ENABLED || !OPENAI_KEY || !OPENAI_BASE) return json(503, { error: 'AI_DISABLED' });

  let chunks: HelpChunk[] | null = [];
  if (r.mode === 'answer') {
    try {
      chunks = pickChunks(await helpPack(r.pack_version), r.chunk_ids);
    } catch {
      return json(503, { error: 'SERVER_BUSY' });
    }
  }
  if (!chunks) return json(409, { error: 'HELP_PACK_MISMATCH' }); // app có bài mới hơn máy chủ → app trả nguyên văn

  let res;
  try {
    res = await reserve(r, user);
  } catch {
    return json(503, { error: 'QUOTA_UNAVAILABLE' });
  }
  if (!res.ok || !res.id) {
    const [code, err] = STATUS_ERROR[res.status] ?? [503, 'QUOTA_UNAVAILABLE'];
    return json(code, { error: err });
  }
  const logId = res.id;
  // Sổ ghi rõ lượt có số liệu quán / lượt trước: câu trả lời riêng của một quán, không duyệt vào bộ nhớ dùng chung.
  let kind = `${MODEL}${r.facts || r.chain || r.modules ? '+so_lieu' : ''}${r.chain ? '+chuoi' : ''}${r.modules ? '+module' : ''}${r.history ? '+ngu_canh' : ''}`;

  // Trí nhớ cho câu tư vấn và câu hướng dẫn; lấy TRƯỚC khi gọi GPT —
  // dòng của lượt này đang 'pending' nên không tự nhắc lại chính mình.
  const [who, mem] = await Promise.all([
    persona(user),
    // Cả câu hướng dẫn: câu nói tiếp ("dịch luôn mấy món còn lại") hay rơi vào chế độ hướng dẫn (QC 24/10)
    r.mode === 'advice' || r.mode === 'answer'
      ? recall(r.store_id, user, memorySince(new Date(), r.memory_age_s))
      : Promise.resolve({ turns: [] as MemoryTurn[], hasData: false }),
  ]);
  const memory = mem.turns;
  if (memory.length) kind += `+nho${mem.hasData && !kind.includes('so_lieu') ? '+so_lieu' : ''}`;
  const t0 = Date.now();
  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), UPSTREAM_TIMEOUT_MS);
  const messages = buildMessages(r.question, chunks, who, { facts: r.facts, chain: r.chain, modules: r.modules, history: r.history, memory });
  const callGpt = (msgs: { role: string; content: string }[], signal: AbortSignal = ac.signal) =>
    fetch(`${OPENAI_BASE}/chat/completions`, {
      method: 'POST',
      signal,
      headers: { Authorization: `Bearer ${OPENAI_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: MODEL, temperature: 0.2, max_tokens: r.mode === 'advice' ? (loaiCau(r.question, !!r.history || (memory?.length ?? 0) > 0) === 'ke_hoach' ? 900 : 600) : 650, messages: msgs }), // hướng dẫn 450 → 650: chép đủ bước (26/10)
    });
  try {
    const up = await callGpt(messages);
    let latency = Date.now() - t0;
    if (!up.ok) {
      await up.body?.cancel();
      // Không chép nội dung lỗi của OpenAI (có thể chứa thông tin tài khoản) — chỉ mã trạng thái.
      await finish(logId, { model: kind, status: 'error', latency_ms: latency, answer: `HTTP ${up.status}` });
      return json(502, { error: 'AI_UPSTREAM_ERROR' });
    }
    const data = await up.json();
    let answer = clipAnswer(plainAnswer(String(data?.choices?.[0]?.message?.content ?? '')));
    let inTok = Number(data?.usage?.prompt_tokens) || 0;
    let outTok = Number(data?.usage?.completion_tokens) || 0;
    // GPT tự từ chối câu tư vấn mà bộ lọc luật không chặn (vd "đàm phán đại lý", "chủ nhà tăng tiền thuê") → hỏi lại
    // MỘT lần kèm nhắc phạm vi; câu thật sự ngoài phạm vi thì GPT vẫn giữ câu từ chối (chấm cố vấn 24/10).
    // Chỉ câu có từ khoá kinh doanh, còn ≥ 4 giây; lần hỏi lại có hẹn giờ riêng, lỗi thì giữ câu trả lời + token lần 1.
    const left = UPSTREAM_TIMEOUT_MS - (Date.now() - t0);
    if (isScopeRefusal(answer) && looksBusiness(r.question) && left >= 4000) {
      const ac2 = new AbortController();
      const timer2 = setTimeout(() => ac2.abort(), Math.min(left, 8000));
      try {
        const again = await callGpt([
          ...messages.slice(0, 1),
          { role: 'system', content: RETRY_SCOPE_NOTE },
          ...messages.slice(1),
        ], ac2.signal);
        if (again.ok) {
          const d2 = await again.json();
          const a2 = clipAnswer(plainAnswer(String(d2?.choices?.[0]?.message?.content ?? '')));
          inTok += Number(d2?.usage?.prompt_tokens) || 0;
          outTok += Number(d2?.usage?.completion_tokens) || 0;
          if (a2) answer = a2;
        } else {
          await again.body?.cancel();
        }
      } catch {
        // hỏi lại lỗi / quá giờ → dùng câu trả lời + token của lần 1
      } finally {
        clearTimeout(timer2);
      }
      kind += '+retry';
      latency = Date.now() - t0;
    }
    // Tự kiểm (lần 41–42): số không có trong khối / không tính ra được, khuyên giảm giá món giá vốn cao, lộ tên dòng nội bộ
    // → hỏi lại GPT MỘT lần kèm danh sách lỗi. Còn ≥ 4 giây; lỗi / quá giờ thì giữ câu trả lời lần trước.
    const left2 = UPSTREAM_TIMEOUT_MS - (Date.now() - t0);
    const bad = r.mode === 'advice' && (r.facts || r.modules || r.chain) && left2 >= 4000
      ? kiemTraLoi(answer, soLieuGoc(r.question, { facts: r.facts, chain: r.chain, modules: r.modules, history: r.history, memory }))
      : [];
    if (bad.length) {
      const ac3 = new AbortController();
      const timer3 = setTimeout(() => ac3.abort(), Math.min(left2, 8000));
      try {
        const again = await callGpt([...messages, { role: 'assistant', content: answer }, { role: 'user', content: noteKiem(bad) }], ac3.signal);
        if (again.ok) {
          const d3 = await again.json();
          const a3 = clipAnswer(plainAnswer(String(d3?.choices?.[0]?.message?.content ?? '')));
          inTok += Number(d3?.usage?.prompt_tokens) || 0;
          outTok += Number(d3?.usage?.completion_tokens) || 0;
          if (a3) answer = a3;
        } else {
          await again.body?.cancel();
        }
      } catch {
        // hỏi lại lỗi / quá giờ → giữ câu trả lời trước
      } finally {
        clearTimeout(timer3);
      }
      kind += '+kiem_so';
      latency = Date.now() - t0;
    }
    // Câu hướng dẫn app mà GPT đoán nút / chức năng "(nếu có…)" → không đưa bước bịa ra, nói thẳng chưa có hướng dẫn (QC 24/10)
    if (r.mode === 'answer' && guessesAppFeature(answer)) {
      answer = `Dạ ${goiNguoiHoi(who)} ơi, Bé Boom chưa thấy hướng dẫn cho việc này trong app ạ. ${goiNguoiHoi(who)} xem thử các mục hướng dẫn gần nhất hoặc hỏi Chủ quán nhé.`;
      kind += '+doan_nut';
    }
    const cost = costUsd(inTok, outTok, PRICES);
    if (!answer) {
      await finish(logId, { model: kind, status: 'error', latency_ms: latency, input_tokens: inTok, output_tokens: outTok, cost_usd: cost, answer: 'EMPTY' });
      return json(502, { error: 'AI_EMPTY_ANSWER' });
    }
    await finish(logId, { model: kind, status: 'ok', answer: r.chain ? CHAIN_LOG_NOTE : r.modules ? MODULE_LOG_NOTE : answer, input_tokens: inTok, output_tokens: outTok, cost_usd: cost, latency_ms: latency });
    const refused = modelRefused(answer);
    await writeFull({ log_id: logId, store_id: r.store_id, user_id: user, source: 'gpt',
      tool: refused ? 'boom_tu_choi:model' : `${r.mode}:${kind}`,
      question: r.question, answer: refused ? refusalFor('programming') : answer, chunk_ids: r.chunk_ids });
    if (refused) return json(200, { answer: refusalFor('programming'), blocked: 'model', log_id: logId });
    return json(200, { answer, log_id: logId, model: MODEL });
  } catch (e) {
    const timeout = e instanceof DOMException && e.name === 'AbortError';
    // OpenAI có thể vẫn tính tiền lượt quá giờ → ghi chi phí ước lượng (≈ 1 lượt)
    await finish(logId, { model: kind, status: 'error', latency_ms: Date.now() - t0, answer: timeout ? 'TIMEOUT' : 'NETWORK', cost_usd: 0.001 });
    return json(504, { error: timeout ? 'AI_TIMEOUT' : 'AI_NETWORK' });
  } finally {
    clearTimeout(timer);
  }
});
