# Kế Hoạch Triển Khai Supabase Staging Độc Lập (Standalone Supabase Staging Plan)
File: `supabase/staging_supabase_deployment_plan.md`
Date: 2026-08-01

---

## 1. MỤC TIÊU DỰ ÁN STAGING

Thiết lập một hạ tầng **Self-Hosted Supabase Staging hoàn toàn độc lập** trên VPS (project name: `quannho_staging`), tách biệt 100% về container, volume, port, database, JWT secret, Nginx server block và tên miền với hệ thống Production (`quannho.lpm.vn`).

---

## 2. BẢNG SO SÁNH HẠ TẦNG PRODUCTION VS STAGING

| Thành Phần | Môi Trường Production Hiện Tại | Môi Trường Staging Độc Lập Dự Kiến | Cách Chứng Minh Độc Lập | Image Version Matrix Source |
|---|---|---|---|---|
| **Docker Project** | Default (`supabase`) | `quannho_staging` | 2 stack docker-compose riêng rẽ | N/A |
| **Studio Domain** | `https://quannho-db.lpm.vn` | `https://quannho-staging-db.lpm.vn` | Tên miền dedicated riêng (Bảo vệ bằng Basic Auth) | N/A |
| **API Domain** | `https://quannho.lpm.vn/supabase/` | `https://quannho-staging.lpm.vn/` | Dedicated API domain tại ROOT `/` (Kong 8010) | N/A |
| **Studio Container & Port** | `supabase-studio` (`127.0.0.1:3003`) | `staging-supabase-studio` (`127.0.0.1:3013`) | Port 3013 khác 3003 | `supabase/studio:20240729-6887bb4` |
| **Postgres Meta & Port** | `supabase-meta` | `staging-supabase-meta` (`127.0.0.1:8080`) | Meta API cho Studio query DB | `supabase/postgres-meta:v0.84.2` |
| **Kong Gateway & Port** | `supabase-kong` (`127.0.0.1:8000`) | `staging-supabase-kong` (`127.0.0.1:8010`) | Port 8010 khác 8000 | `kong:2.8.1` |
| **PostgreSQL & Port** | `supabase-db` (`127.0.0.1:5432`) | `staging-supabase-db` (`127.0.0.1:5433`) | Port 5433 khác 5432 | `supabase/postgres:15.1.0.147` |
| **GoTrue Auth & Port** | `supabase-auth` (`127.0.0.1:9999`) | `staging-supabase-auth` (`127.0.0.1:9998`) | Port 9998 khác 9999 | `supabase/gotrue:v2.158.1` |
| **PostgREST & Port** | `supabase-rest` (`127.0.0.1:3000`) | `staging-supabase-rest` (`127.0.0.1:3010`) | Port 3010 khác 3000 | `postgrest/postgrest:v12.2.0` |
| **Realtime & Port** | `supabase-realtime` (`127.0.0.1:4000`) | `staging-supabase-realtime` (`127.0.0.1:4010`) | Port 4010 khác 4000 | `supabase/realtime:v2.33.58` |
| **Storage & Port** | `supabase-storage` (`127.0.0.1:5000`) | `staging-supabase-storage` (`127.0.0.1:5010`) | Port 5010 khác 5000 | `supabase/storage-api:v1.11.13` |
| **Imgproxy & Port** | N/A | `staging-supabase-imgproxy` (`127.0.0.1:8088`) | Thumbnail rendering cho Storage | `darthsim/imgproxy:v3.8.0` |
| **DB Volume** | `db_data` | `quannho_staging_staging_db_data` | Volume vật lý riêng biệt | N/A |
| **Storage Volume** | `storage_data` | `quannho_staging_staging_storage_data` | Storage volume vật lý riêng biệt | N/A |

*Lưu ý quay trình kiểm tra:* Phiên bản image trong bảng trên được trích xuất từ nhật ký triển khai VPS (`nhat_ky.md` L1747-1770). Trạng thái chính thức: `NOT VERIFIED AGAINST LIVE CONTAINER INSPECTION` cho đến khi thực hiện `docker inspect` trực tiếp trên VPS ở giai đoạn bảo trì.

---

## 3. QUY TRÌNH KONG TEMPLATE RENDERING & GITIGNORE FILE RUNTIME

File runtime sinh ra từ template bắt buộc phải được bảo vệ bởi `.gitignore`:

```gitignore
# Runtime Staging Files (Generated on VPS)
supabase/kong.staging.yml
supabase/docker-compose.staging.yml
supabase/.env.staging.server
supabase/.env.staging.local
supabase/candidate_baseline_schema.sql
supabase/backups/
```

- Canonical template được lưu Git: `supabase/kong.staging.yml.template.example`
- Lệnh render runtime trên VPS:
  ```bash
  envsubst < kong.staging.yml.template.example > /var/www/quannho_staging/kong.staging.yml
  chmod 600 /var/www/quannho_staging/kong.staging.yml
  ```

---

## 4. DANH SÁCH CHÍNH XÁC 8 FILE HỒ SƠ STAGING

1. `supabase/staging_supabase_deployment_plan.md` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/staging_supabase_deployment_plan.md))
2. `supabase/docker-compose.staging.yml.example` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/docker-compose.staging.yml.example))
3. `supabase/.env.staging.server.example` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/.env.staging.server.example))
4. `supabase/nginx_staging.example.conf` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/nginx_staging.example.conf))
5. `supabase/kong.staging.yml.template.example` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/kong.staging.yml.template.example)) — Canonical Template File
6. `supabase/staging_schema_install_order.md` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/staging_schema_install_order.md))
7. `supabase/staging_verification_checklist.md` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/staging_verification_checklist.md))
8. `supabase/staging_backup_and_destroy_plan.md` ([File](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/staging_backup_and_destroy_plan.md))

---

## 5. THÔNG TIN VÀ QUYỀN CẦN THIẾT

- Quyền SSH sudo trên VPS `<VPS_PUBLIC_IP>`.
- Quyền quản trị DNS Cloudflare/Domain registrar để thêm 2 A records `quannho-staging-db.lpm.vn` và `quannho-staging.lpm.vn`.
- Trạng thái hiện tại: **ĐÃ HOÀN THÀNH 100% HỒ SƠ 8 FILE TĨNH (SỬA QC LẦN 3) — DỪNG LẠI CHỜ PHÊ DUYỆT.**
