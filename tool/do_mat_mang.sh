#!/bin/bash
# Đo mất mạng lúc thanh toán bàn (đợt 8 lộ trình tính giờ, .docs/ke-hoach-mat-mang.md). CHỈ ĐỌC.
#   bash tool/do_mat_mang.sh [số ngày, mặc định 30]
# Nguồn: app_logs (app giữ nhật ký trên máy khi mất mạng rồi gửi lên sau, tới 24 giờ), ban_sessions, stores.
#   1. Các đợt mạng chập chờn theo quán: số khung 15 phút có dòng lỗi mạng.
#   2. Thanh toán bàn: phiên mở màn Thu tiền (open_checkout) có thanh toán xong (checkout_done) không, tách
#      trong / ngoài khung mạng chập chờn và bàn tính giờ / bàn thường.
#   3. Chốt giờ (bàn tính giờ) lỗi: dòng "ban_chot_gio_v1 lỗi" của tag tinh_gio.
# Giới hạn 60 giây mỗi câu; quá thì báo lỗi, không đè máy chủ.
set -u
NGAY="${1:-30}"
[[ "$NGAY" =~ ^[0-9]+$ ]] || { echo "Số ngày phải là số"; exit 1; }
ssh -o BatchMode=yes -o ConnectTimeout=15 azvn-vps \
  "docker exec -i supabase-db psql -U supabase_admin -d postgres -X -q -P pager=off -v ngay=$NGAY" <<'EOF'
begin read only;
set local statement_timeout = '60s';
-- giao dịch chỉ đọc không tạo được bảng tạm: mỗi câu lặp lại phần "goc" (đọc app_logs một lần mỗi câu)
\set goc 'goc as materialized (select store_id, created_at, tag, message, details, (message ilike ''%SocketException%'' or message ilike ''%Failed host lookup%'' or message ilike ''%TimeoutException%'' or message ilike ''%Connection reset%'' or message ilike ''%HandshakeException%'') la_loi_mang from app_logs where created_at > now() - make_interval(days => ' :ngay '))'

\echo '── 1. Mạng chập chờn theo quán (khung 15 phút có lỗi mạng) ──'
with :goc
select s.name quan, count(distinct date_bin('15 min', g.created_at, '2026-01-01')) khung_15p,
       count(distinct (g.created_at at time zone 'Asia/Ho_Chi_Minh')::date) so_ngay, count(*) dong_loi
from goc g join stores s on s.id = g.store_id where g.la_loi_mang group by 1 order by 2 desc limit 15;

\echo '── 2. Thanh toán bàn: mở màn Thu tiền → có thanh toán xong không ──'
with :goc, loi as (select distinct store_id, date_bin('15 min', created_at, '2026-01-01') k from goc where la_loi_mang),
mo as (select store_id, details::jsonb->>'session' ss, min(created_at) dau from goc
       where tag = 'action' and details like '%"act":"open_checkout"%' group by 1, 2),
xong as (select store_id, details::jsonb->>'session' ss, min(created_at) t from goc
         where tag = 'action' and details like '%"act":"checkout_done"%' group by 1, 2)
select case when l.k is not null then 'lúc mạng chập chờn' else 'lúc bình thường' end khi,
       case when bs.gio_bat_dau is not null then 'bàn tính giờ' else 'bàn thường' end loai,
       count(*) so_phien, count(x.ss) xong, count(*) - count(x.ss) chua_xong,
       round((percentile_cont(0.5) within group (order by extract(epoch from x.t - m.dau)) filter (where x.ss is not null))::numeric) giay_trung_vi,
       count(*) filter (where extract(epoch from x.t - m.dau) > 300) lau_hon_5_phut
from mo m
left join loi l on l.store_id = m.store_id and l.k = date_bin('15 min', m.dau, '2026-01-01')
left join xong x on x.store_id = m.store_id and x.ss = m.ss
left join ban_sessions bs on bs.id::text = m.ss
where m.ss is not null
group by 1, 2 order by 1, 2;

\echo '── 3. Chốt giờ bàn tính giờ lỗi (lỗi mạng / lỗi khác) ──'
with :goc
select s.name quan, count(*) filter (where g.la_loi_mang) loi_mang, count(*) filter (where not g.la_loi_mang) loi_khac
from goc g join stores s on s.id = g.store_id
where g.tag = 'tinh_gio' and g.message like 'ban_chot_gio_v1 lỗi%' group by 1 order by 2 desc;
rollback;
EOF
