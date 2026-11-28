#!/usr/bin/env bash
# Tự kiểm vì sao một quán thấy app chậm (mở bàn, gửi bếp) — CHỈ ĐỌC.
# Cách dùng: tool/kiem_cham.sh "<tên quán>" <YYYY-MM-DD> [giờ_từ] [giờ_đến]   (giờ VN, mặc định 17 23)
# Ví dụ:    tool/kiem_cham.sh "Bò Đen Trà Quán" 2026-11-11 20 22
# Cách đọc kết quả (Bò Đen 11/11): app báo quá hạn nhưng nginx vẫn có yêu cầu của máy đó được trả 200
# ⇒ mạng phía điện thoại (5G/Wi‑Fi); nginx im lặng hẳn ⇒ máy mất mạng; "API tại máy chủ" > 100 ms
# hoặc áp lực CPU cao ⇒ máy chủ nghẽn. Mục 4 chỉ thấy yêu cầu có mã phiên bàn, nên im lặng
# dài cũng có thể là máy đang ở màn khác; chỉ tin khoảng im trùng lúc app báo quá hạn.
set -euo pipefail
TEN="${1:?Thiếu tên quán}"; NGAY="${2:?Thiếu ngày YYYY-MM-DD}"; TU="${3:-17}"; DEN="${4:-23}"
case "$TEN$NGAY$TU$DEN" in *"'"*) echo "Không dùng dấu nháy đơn"; exit 1;; esac
PSQL='docker exec -i supabase-db psql -U supabase_admin -d postgres -X -q -A -F " | "'
BD="$NGAY $TU:00+07"; KT="$NGAY $DEN:59+07"

sql() { ssh azvn-vps "$PSQL" <<EOF
begin read only; set timezone='Asia/Ho_Chi_Minh';
$1
rollback;
EOF
}

SID=$(sql "select id from stores where name = '$TEN';" | grep -E '^[0-9a-f-]{36}$' | head -1 || true)
[ -n "$SID" ] || { echo "Không thấy quán '$TEN'"; exit 1; }
echo "== Quán $TEN ($SID), $NGAY ${TU}h–${DEN}h giờ VN"

echo; echo "== 1. Mỗi giờ: tổng nhật ký | quá hạn | cảnh báo | lỗi"
sql "select to_char(created_at,'HH24') gio, count(*), count(*) filter (where message like '%Timeout%'),
  count(*) filter (where level='WARNING'), count(*) filter (where level='ERROR')
  from app_logs where store_id='$SID' and created_at between '$BD' and '$KT' group by 1 order by 1;"

echo; echo "== 2. Gửi bếp: số lần | trung vị ms | chậm nhất ms | số lần > 1 giây"
sql "with g as (select (regexp_match(details::jsonb->>'result','ok (\d+)ms'))[1]::int ms from app_logs
  where store_id='$SID' and created_at between '$BD' and '$KT' and details like '%\"act\":\"send_kitchen\"%')
  select count(*), percentile_cont(.5) within group (order by ms), max(ms), count(*) filter (where ms>1000) from g;"
sql "select to_char(created_at,'HH24:MI:SS'), staff_name, details::jsonb->>'table', details::jsonb->>'result'
  from app_logs where store_id='$SID' and created_at between '$BD' and '$KT' and details like '%\"act\":\"send_kitchen\"%'
  and (details::jsonb->>'result' not like 'ok %' or (regexp_match(details::jsonb->>'result','ok (\d+)ms'))[1]::int > 1000)
  order by created_at;"

echo; echo "== 3. Quá hạn / lỗi theo phút và máy"
sql "select to_char(created_at,'HH24:MI'), left(device_id,4), staff_name, count(*), left(min(message),70)
  from app_logs where store_id='$SID' and created_at between '$BD' and '$KT' and level in ('WARNING','ERROR')
  group by 1,2,3 order by 1 limit 60;"

echo; echo "== 4. Máy chủ nhận gì từ các máy của quán (nginx, khớp IP theo mã phiên bàn)"
sql "select id from ban_sessions where store_id='$SID' and opened_at between '$BD'::timestamptz - interval '1 day' and '$KT';" \
  | grep -E '^[0-9a-f-]{36}$' > /tmp/qn_kiem_cham_sid.txt || true
UTC_TU=$(( (10#$TU + 17) % 24 )); UTC_DEN=$(( (10#$DEN + 17) % 24 ))
ssh azvn-vps "cat > /tmp/qn_kiem_cham_sid.txt" < /tmp/qn_kiem_cham_sid.txt
ssh azvn-vps "bash -s" <<EOF
cd /var/log/nginx
D=\$(date -d "$NGAY" +%d/%b/%Y)
zcat -f access.log access.log.1 access.log.2.gz 2>/dev/null | grep -F "\$D:" | grep -F -f /tmp/qn_kiem_cham_sid.txt \
 | awk -v a=$UTC_TU -v b=$UTC_DEN '{h=substr(\$4,14,2)+0; if ((a<=b && h>=a && h<=b) || (a>b && (h>=a || h<=b))) print}' > /tmp/qn_kiem_cham.log
echo "Số yêu cầu của quán: \$(wc -l < /tmp/qn_kiem_cham.log)"
echo "-- IP | số yêu cầu | không phải 2xx"
awk '{n[\$1]++; if (\$9 !~ /^2/) e[\$1]++} END {for (k in n) print k, n[k], e[k]+0}' /tmp/qn_kiem_cham.log | sort -k2 -rn | head -10
echo "-- Khoảng im lặng > 20 giây của từng IP (giờ VN)"
awk '{split(substr(\$4,14,8),t,":"); s=t[1]*3600+t[2]*60+t[3]; if (p[\$1] && s-p[\$1]>20) printf "%s im %ds tới %02d:%s\n", \$1, s-p[\$1], (t[1]+7)%24, substr(\$4,17,5); p[\$1]=s}' /tmp/qn_kiem_cham.log | head -30
echo "-- Tổng lưu lượng cả máy chủ (mọi quán) mỗi giờ VN"
zcat -f access.log access.log.1 2>/dev/null | grep -F "\$D:" | awk '{print substr(\$4,14,2)}' | sort | uniq -c \
 | awk -v a=$UTC_TU -v b=$UTC_DEN '{h=\$2+0; if ((a<=b && h>=a && h<=b) || (a>b && (h>=a || h<=b))) printf "%02dh VN: %d yêu cầu (%.1f/giây)\n", (h+7)%24, \$1, \$1/3600}'
rm -f /tmp/qn_kiem_cham.log /tmp/qn_kiem_cham_sid.txt
echo; echo "== 5. Máy chủ lúc này"
uptime
echo "Áp lực CPU (some = % thời gian có tiến trình chờ CPU): \$(head -1 /proc/pressure/cpu)"
echo -n "API tại máy chủ (giây, 5 lần):"; for i in 1 2 3 4 5; do echo -n " \$(curl -s -o /dev/null -w %{time_total} http://127.0.0.1:8000/rest/v1/)"; done; echo
EOF
rm -f /tmp/qn_kiem_cham_sid.txt
