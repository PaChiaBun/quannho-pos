#!/bin/bash
# Quan Nho — sao luu co so du lieu hang dem (13/10/2026, Chu Quan yeu cau: giu 5 ngay, tu xoa ban cu).
# Chi xoa ban cu SAU KHI ban moi da duoc kiem tra hop le; luon giu it nhat MIN_KEEP ban moi nhat.
set -euo pipefail
DIR=/var/backups/quannho-db
KEEP_DAYS=${KEEP_DAYS:-5}
MIN_KEEP=${MIN_KEEP:-3}
MIN_BYTES=${MIN_BYTES:-5000000}     # ban dump < 5 MB la bat thuong (DB that ~21 MB)
CONTAINER=supabase-db
TS=$(date +%Y%m%d_%H%M%S)
mkdir -p "$DIR"; chmod 700 "$DIR"
TMP="$DIR/.dang_chay_$TS.dump"; FINAL="$DIR/quannho_$TS.dump"; GLOB="$DIR/quannho_${TS}_globals.sql"
trap 'rm -f "$TMP"' EXIT

echo "Bat dau sao luu $TS"
docker exec "$CONTAINER" pg_dump -U supabase_admin -d postgres -Fc --no-owner > "$TMP"
SZ=$(stat -c %s "$TMP")
[ "$SZ" -ge "$MIN_BYTES" ] || { echo "LOI: ban dump qua nho ($SZ byte) -> bo, KHONG xoa ban cu"; exit 1; }
N=$(docker exec -i "$CONTAINER" pg_restore --list < "$TMP" | wc -l)
[ "$N" -ge 100 ] || { echo "LOI: ban dump khong doc duoc dung ($N muc) -> bo, KHONG xoa ban cu"; exit 1; }
docker exec "$CONTAINER" pg_dumpall -U supabase_admin --globals-only > "$GLOB" 2>/dev/null || true
mv "$TMP" "$FINAL"; chmod 600 "$FINAL" "$GLOB" 2>/dev/null || true
echo "OK: $FINAL ($((SZ/1048576)) MB, $N muc)"

# Don ban cu: chi khi co >= MIN_KEEP ban hop le, chi xoa ban qua KEEP_DAYS ngay
ls -1t "$DIR"/quannho_*.dump 2>/dev/null | tail -n +$((MIN_KEEP+1)) | while read -r f; do
  if [ -n "$(find "$f" -mmin +$((KEEP_DAYS*1440)) 2>/dev/null)" ]; then
    rm -f "$f" "${f%.dump}_globals.sql"; echo "Da xoa ban cu: $(basename "$f")"
  fi
done
echo "Con lai: $(ls -1 "$DIR"/quannho_*.dump | wc -l) ban, $(du -sh "$DIR" | cut -f1)"
