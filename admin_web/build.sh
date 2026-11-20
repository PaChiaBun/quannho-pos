#!/bin/bash
# Đóng gói trang quản trị → build/admin_web (config.js lấy địa chỉ + khoá công khai anon từ app, không chép tay).
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=build/admin_web
rm -rf "$OUT" && mkdir -p "$OUT"
cp admin_web/index.html admin_web/app.css admin_web/app.js "$OUT/"
cp -R admin_web/fonts "$OUT/fonts"
KEY=$(grep -o "_supabaseAnonKey = '[^']*'" lib/core/services/supabase_service.dart | sed "s/.*= '//; s/'$//")
[ -n "$KEY" ] || { echo "❌ Không đọc được khoá anon"; exit 1; }
printf "window.QN_ADMIN_CONFIG = Object.freeze({ supabaseUrl: '/supabase', anonKey: '%s' });\n" "$KEY" > "$OUT/config.js"
echo "✅ $OUT: $(ls "$OUT" | tr '\n' ' ')"
