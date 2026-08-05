# Báo Cáo Audit VPS Production Read-Only & Empirical Staging Mapping
File: `supabase/staging_production_readonly_audit.md`
Date: 2026-08-01
Timestamp Audit: `2026-08-01T01:30:00+07:00`
Mode: `READ-ONLY AUDIT (ZERO SECRET EXPOSURE)`

---

## 1. DỮ LIỆU TÀI NGUYÊN VPS PRODUCTION (VPS CAPACITY AUDIT)

Audit trực tiếp qua SSH lệnh read-only (`uname`, `lscpu`, `free -h`, `df -h`, `docker system df`, `ss -ltn`):

- **OS / Kernel:** Linux cook-ai-vn 5.15.0-185-generic x86_64
- **CPU:** 1 CPU Core (`Intel Xeon Processor Skylake`)
- **RAM Tổng / Đang Dùng / Còn Trống:** `1.9 GiB` / `1.2 GiB` / `103 MiB` (Buff/Cache: `584 MiB`, Available: `478 MiB`)
- **Swap Tổng / Đang Dùng:** `5.3 GiB` / `2.0 GiB` (Đang sử dụng 2.0 GiB swap)
- **Disk Dung Lượng / Đang Dùng:** `52 GB` / `35 GB` (Còn trống `14 GB` - 72% Use)
- **Docker Disk Usage:** Images: `9.1 GB` (11 active), Containers: `130.5 MB`, Local Volumes: `519.1 kB`
- **Listening Ports trên VPS:** `8000` (Kong), `3003` (Studio), `5432` (Supavisor/Postgres), `6543` (Pooler), `5678` (n8n), `8444` (Kong SSL), `3306` (MySQL local), `80/443` (Nginx)

> ⚠️ **KẾT LUẬN SỨC CHỨA VPS (VPS CAPACITY RESULT): FAIL FOR PARALLEL SECOND STACK**
> VPS hiện tại chỉ có **1 CPU Core** và **1.9 GB RAM**, trong đó RAM khả dụng chỉ còn **478 MB** và đã phải tiêu thụ **2.0 GB Swap**.
> Nếu dựng thêm một Supabase stack song song 11 containers trên cùng VPS này sẽ làm quá tải RAM (OOM Crash) và ảnh hưởng trực tiếp tới Production.
> **Khuyến nghị:** Môi trường Staging nên được chạy trên một VPS riêng biệt hoặc chạy local Docker, hoặc chỉ chạy stack Staging theo dạng đợt kiểm thử ngắn hạn.

---

## 2. BẢNG MATRIX COMPATIBILITY IMAGE VERIFIED THỰC TẾ (EMPIRICAL AUDIT)

Audit thông qua `docker ps` và `docker inspect` (trích xuất duy nhất Image:Tag và Digest, không đọc `.Config.Env` values):

| Service Name | Production Container Name | Production Image:Tag Thực Tế | Image Digest / Tag Version |
|---|---|---|---|
| Database | `supabase-db` | `supabase/postgres:17.6.1.136` | `17.6.1.136` |
| Auth | `supabase-auth` | `supabase/gotrue:v2.189.0` | `v2.189.0` |
| REST API | `supabase-rest` | `postgrest/postgrest:v14.12` | `v14.12` |
| Realtime | `realtime-dev.supabase-realtime` | `supabase/realtime:v2.102.3` | `v2.102.3` |
| Storage API | `supabase-storage` | `supabase/storage-api:v1.60.4` | `v1.60.4` |
| Postgres Meta | `supabase-meta` | `supabase/postgres-meta:v0.96.6` | `v0.96.6` |
| Supabase Studio | `supabase-studio` | `supabase/studio:2026.07.07-sha-a6a04f2` | `2026.07.07-sha-a6a04f2` |
| API Gateway | `supabase-kong` | `kong/kong:3.9.1` | `3.9.1` |
| Image Proxy | `supabase-imgproxy` | `darthsim/imgproxy:v3.30.1` | `v3.30.1` |
| Connection Pooler | `supabase-pooler` | `supabase/supavisor:2.9.5` | `2.9.5` |
| Edge Runtime | `supabase-edge-functions` | `supabase/edge-runtime:v1.74.0` | `v1.74.0` |

---

## 3. AUDIT THƯ MỤC CẤU HÌNH PRODUCTION & INIT SCRIPTS REALITY

- **Đường dẫn Compose Production trên VPS:** `/var/www/supabase-setup/docker/`
- **Các File Init SQL thực tế mounted vào Database (`/docker-entrypoint-initdb.d`):**
  1. `/var/www/supabase-setup/docker/volumes/db/roles.sql` -> `/docker-entrypoint-initdb.d/init-scripts/99-roles.sql` (379 bytes)
  2. `/var/www/supabase-setup/docker/volumes/db/jwt.sql` -> `/docker-entrypoint-initdb.d/init-scripts/99-jwt.sql` (207 bytes)
  3. `/var/www/supabase-setup/docker/volumes/db/webhooks.sql` -> `/docker-entrypoint-initdb.d/init-scripts/98-webhooks.sql` (8771 bytes)
  4. `/var/www/supabase-setup/docker/volumes/db/_supabase.sql` -> `/docker-entrypoint-initdb.d/migrations/97-_supabase.sql` (83 bytes)
  5. `/var/www/supabase-setup/docker/volumes/db/logs.sql` -> `/docker-entrypoint-initdb.d/migrations/99-logs.sql` (144 bytes)
  6. `/var/www/supabase-setup/docker/volumes/db/pooler.sql` -> `/docker-entrypoint-initdb.d/migrations/99-pooler.sql` (144 bytes)
  7. `/var/www/supabase-setup/docker/volumes/db/realtime.sql` -> `/docker-entrypoint-initdb.d/migrations/99-realtime.sql` (117 bytes)

---

## 4. BẢNG MANIFEST XÁC MINH ROLES & PASSWORDS DỰA TRÊN THỰC TẾ (`roles.sql`)

| Service Name | Database Role | LOGIN Permission | Password Variable Name | Schema Owner | Grants / Privileges | Init Script File Thực Tế | Verified Status |
|---|---|---|---|---|---|---|---|
| `auth` | `supabase_auth_admin` | YES | `POSTGRES_PASSWORD` | `auth` | `ALTER USER supabase_auth_admin WITH PASSWORD :'pgpass'` | `roles.sql` | `VERIFIED_LIVE_READ_ONLY` |
| `storage` | `supabase_storage_admin` | YES | `POSTGRES_PASSWORD` | `storage` | `ALTER USER supabase_storage_admin WITH PASSWORD :'pgpass'` | `roles.sql` | `VERIFIED_LIVE_READ_ONLY` |
| `rest` | `authenticator` | YES | `POSTGRES_PASSWORD` | N/A (Proxy role) | `ALTER USER authenticator WITH PASSWORD :'pgpass'` | `roles.sql` | `VERIFIED_LIVE_READ_ONLY` |
| `functions` | `supabase_functions_admin` | YES | `POSTGRES_PASSWORD` | `vault` | `ALTER USER supabase_functions_admin WITH PASSWORD :'pgpass'` | `roles.sql` | `VERIFIED_LIVE_READ_ONLY` |
| `pooler` | `pgbouncer` | YES | `POSTGRES_PASSWORD` | N/A | `ALTER USER pgbouncer WITH PASSWORD :'pgpass'` | `roles.sql` | `VERIFIED_LIVE_READ_ONLY` |

---

## 5. AUDIT KONG PRODUCTION ROUTING & OPEN ROUTES

File cấu hình Kong Production `/var/www/supabase-setup/docker/volumes/api/kong.yml`:
- **Unauthenticated Open Routes (OAuth Callbacks):**
  - `/verify` -> `http://auth:9999/verify`
  - `/callback` -> `http://auth:9999/callback`
  - `/authorize` -> `http://auth:9999/authorize`
  - `/.well-known/jwks.json` -> `http://auth:9999/.well-known/jwks.json`
- **Protected Routes (Cần `apikey` header):**
  - `/auth/v1/` -> `http://auth:9999/` (`key-auth` plugin, `key_names: ["apikey"]`)
  - `/rest/v1/` -> `http://rest:3000/` (`key-auth` plugin, `key_names: ["apikey"]`)
  - `/realtime/v1/` -> `http://realtime:4000/socket` (`key-auth` plugin, `key_names: ["apikey"]`)
  - `/storage/v1/` -> `http://storage:5000/` (`cors`, `request-transformer`)
  - `/pg-meta` -> `http://meta:8080/` (`key-auth`, `acl`)

---

## 6. DANH SÁCH TÊN BIẾN MÔI TRƯỜNG CỦA CÁC SERVICE (ZERO SECRETS EXPOSED)

Trích xuất duy nhất tên biến bằng `docker inspect --format '{{range .Config.Env}}{{index (split . "=") 0}} {{end}}'`:

- **Realtime Variable Names:** `APP_NAME`, `SEED_SELF_HOST`, `SECRET_KEY_BASE`, `DB_ENC_KEY`, `ERLANG_COOKIE`, `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `API_JWT_SECRET`, `METRICS_JWT_SECRET`, `DB_AFTER_CONNECT_QUERY`, `SLOT_NAME_SUFFIX`, `DNS_NODES`, `ERL_AFLAGS`, `DISABLE_HEALTHCHECK_LOGGING`
- **GoTrue Auth Variable Names:** `GOTRUE_API_HOST`, `GOTRUE_API_PORT`, `API_EXTERNAL_URL`, `GOTRUE_SITE_URL`, `GOTRUE_DB_DRIVER`, `GOTRUE_DB_DATABASE_URL`, `GOTRUE_JWT_SECRET`, `GOTRUE_JWT_EXP`, `GOTRUE_JWT_AUD`, `GOTRUE_JWT_DEFAULT_GROUP_NAME`, `GOTRUE_JWT_ADMIN_ROLES`, `GOTRUE_DISABLE_SIGNUP`, `GOTRUE_URI_ALLOW_LIST`
- **Storage Variable Names:** `ANON_KEY`, `SERVICE_KEY`, `POSTGREST_URL`, `PGRST_JWT_SECRET`, `DATABASE_URL`, `TENANT_ID`, `REGION`, `FILE_SIZE_LIMIT`, `STORAGE_BACKEND`, `FILE_STORAGE_BACKEND_PATH`, `IMGPROXY_URL`, `STORAGE_PUBLIC_URL`, `ENABLE_IMAGE_TRANSFORMATION`
- **PostgREST Variable Names:** `PGRST_DB_URI`, `PGRST_DB_SCHEMAS`, `PGRST_DB_ANON_ROLE`, `PGRST_JWT_SECRET`, `PGRST_DB_EXTRA_SEARCH_PATH`, `PGRST_APP_SETTINGS_JWT_SECRET`, `PGRST_APP_SETTINGS_JWT_EXP`

---

## 7. DANH SÁCH CÁC LỆNH READ-ONLY ĐÃ CHẠY TRÊN VPS

1. `ssh ... "uname -a; lscpu; free -h; df -h; docker system df; ss -ltn; docker ps"`
2. `ssh ... "find /root /var/www /opt /etc -name 'docker-compose*.yml'"`
3. `ssh ... "docker inspect --format '{{.Name}}: {{range .Mounts}}{{.Source}}->{{.Destination}} {{end}}' supabase-db ..."`
4. `ssh ... "ls -la /var/www/supabase-setup/docker/volumes/db/"`
5. `ssh ... "cat /var/www/supabase-setup/docker/volumes/db/roles.sql; cat .../jwt.sql; cat .../realtime.sql"`
6. `ssh ... "grep -E 'name:|path|strip_path|url|origins|credentials|methods|key_names' /var/www/supabase-setup/docker/volumes/api/kong.yml"`
7. `ssh ... "docker inspect --format '{{range .Config.Env}}{{index (split . \"=\") 0}} {{end}}' <container_name>"`

---

## 8. TỔNG KẾT TRẠNG THÁI NGUYÊN TẮC AN TOÀN

- ❌ **SQL Executed:** `NO`
- ❌ **Production Data Modified:** `NO`
- ❌ **Container State Changed:** `NO`
- ❌ **VPS File Modified:** `NO`
- ❌ **Nginx Modified:** `NO`
- ❌ **Docker Objects Created:** `NO`
- ❌ **Deploy:** `NO`
- ❌ **Git Commit/Push:** `NO`
- 🟢 **Secret Exposure:** `NONE` (Zero secret values read, exported, or logged)
