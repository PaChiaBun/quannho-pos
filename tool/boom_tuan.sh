#!/usr/bin/env bash
# Theo dõi Boom hằng tuần (kế hoạch .docs/ke-hoach-tinh-chinh-boom-18-11.md, giai đoạn 5) — CHỈ ĐỌC.
# Chỉ in SỐ ĐẾM (lượt, lỗi, chê, thời gian, tiền, hạn mức); KHÔNG in nội dung câu hỏi / câu trả lời.
# Cách dùng: tool/boom_tuan.sh [số ngày, mặc định 7]
# Cách đọc: "⚠" ở cột hạn mức = quán đã dùng từ 70% hạn mức tháng → hỏi Chủ Quán có nâng không (kế hoạch, mục 6).
#   Lượt bị chặn vì hết lượt KHÔNG có trong sổ hỏi đáp (máy chủ không ghi dòng); đếm qua câu báo app ghi vào lịch sử,
#   nên chỉ thấy từ bản app có sửa ngày 19/11 trở đi.
set -euo pipefail
N="${1:-7}"; case "$N" in ''|*[!0-9]*) echo "Số ngày phải là số"; exit 1;; esac
DOCK=/var/www/supabase-setup/docker
# hạn mức đang đặt trên máy chủ: chỉ đọc đúng 3 biến này, không in biến nào khác
read -r NGAY THANG CA < <(ssh azvn-vps "cd $DOCK && docker compose -f docker-compose.yml -f docker-compose.quannho-boom.yml exec -T functions sh -c 'for v in BOOM_STORE_USD_PER_DAY BOOM_STORE_USD_PER_MONTH BOOM_MONTH_USD_CAP; do printenv \$v || echo -; done'" 2>/dev/null | tr '\n' ' '; echo)
# không đọc được / chưa đặt → mức mặc định trong index.ts
num() { case "$1" in ''|-|*[!0-9.]*) echo "$2";; *) echo "$1";; esac; }
NGAY=$(num "${NGAY:-}" 0.5); THANG=$(num "${THANG:-}" 3); CA=$(num "${CA:-}" 10)

ssh azvn-vps 'docker exec -i supabase-db psql -U supabase_admin -d postgres -X -q -A -t -F " | "' <<EOF
begin read only; set timezone='Asia/Ho_Chi_Minh';
\echo == Boom $N ngày qua (hạn mức: $NGAY USD / quán / ngày · $THANG USD / quán / tháng · $CA USD cả hệ thống / tháng)
with l as (select * from boom_qa_log where created_at >= now() - interval '$N days')
select 'Lượt hỏi ' || count(*) || ' · trả lời được ' || count(*) filter (where status = 'ok') || ' · lỗi ' || count(*) filter (where status = 'error')
  || ' · không có bài ' || count(*) filter (where status = 'no_context') || ' · từ chối ' || count(*) filter (where status = 'blocked')
  || ' · số quán có hỏi ' || count(distinct store_id) || ' · số người hỏi ' || count(distinct user_id) from l
union all
select 'Đánh giá: khen ' || count(*) filter (where rating = 'up') || ' · chê ' || count(*) filter (where rating = 'down') from l
union all
select 'Thời gian chờ mô hình (lượt trả lời được): giữa ' || coalesce(round((percentile_cont(0.5) within group (order by latency_ms) / 1000)::numeric, 1)::text, '-')
  || ' giây · 9 trên 10 lượt dưới ' || coalesce(round((percentile_cont(0.9) within group (order by latency_ms) / 1000)::numeric, 1)::text, '-')
  || ' giây · quá 12 giây ' || count(*) filter (where latency_ms > 12000) || ' lượt' from l where status = 'ok' and latency_ms is not null
union all
select 'Tiền: $N ngày ' || round(coalesce(sum(cost_usd) filter (where created_at >= now() - interval '$N days'), 0), 2) || ' USD · tháng này '
  || round(coalesce(sum(cost_usd), 0), 2) || ' / $CA USD (' || round(100 * coalesce(sum(cost_usd), 0) / $CA) || '%)'
  from boom_qa_log where created_at >= date_trunc('month', now())
union all
select 'Lượt app báo hết lượt (đếm từ bản app 19/11): ' || count(*) from boom_qa_full
  where created_at >= now() - interval '$N days' and (answer like '%đã dùng hết lượt hỏi Bé Boom%' or answer like '%Bé Boom cần nghỉ một chút%');
\echo
\echo == Lỗi theo ngày (ngày | lượt lỗi | trên tổng lượt gọi mô hình)
select to_char(created_at, 'DD/MM'), count(*) filter (where status = 'error'), count(*) filter (where status in ('ok', 'error'))
  from boom_qa_log where created_at >= now() - interval '$N days' group by 1, date_trunc('day', created_at) having count(*) filter (where status = 'error') > 0 order by date_trunc('day', created_at);
\echo
\echo == Từng quán (quán | lượt $N ngày | tiền $N ngày | tiền tháng này | % hạn mức tháng | ngày tốn nhất trong tháng so với hạn mức ngày)
select s.name, count(*) filter (where l.created_at >= now() - interval '$N days'),
  round(coalesce(sum(l.cost_usd) filter (where l.created_at >= now() - interval '$N days'), 0), 2),
  round(sum(l.cost_usd), 2),
  round(100 * sum(l.cost_usd) / $THANG) || '%' || case when sum(l.cost_usd) >= 0.7 * $THANG then ' ⚠' else '' end,
  (select round(max(d), 2) from (select sum(cost_usd) d from boom_qa_log x where x.store_id = l.store_id and x.created_at >= date_trunc('month', now()) group by date_trunc('day', x.created_at)) t) || ' / $NGAY'
  from boom_qa_log l join stores s on s.id = l.store_id where l.created_at >= date_trunc('month', now())
  group by s.name, l.store_id order by sum(l.cost_usd) desc;
rollback;
EOF
