# Quy Trình Backup Snapshot Và Destroy Staging An Toàn
File: `supabase/staging_backup_and_destroy_plan.md`
Date: 2026-08-01

---

## 1. MỤC TIÊU QUY TRÌNH

Đảm bảo môi trường Staging có thể được **chụp snapshot dữ liệu thử nghiệm**, khôi phục lại điểm chuẩn (clean baseline) bất kỳ lúc nào và **hủy bỏ hoàn toàn (Destroy)** khi hoàn tất kiểm thử mà **tuyệt đối không ảnh hưởng tới container, volume hay dữ liệu của Production (`supabase`)**.

---

## 2. QUY TRÌNH BACKUP SNAPSHOT DỮ LIỆU STAGING HỢP LỆ (SINGLE FILENAME & CHECKSUM)

Thực thi lệnh `pg_dump` qua Compose service `staging-db` với biến tên file duy nhất:

```bash
#!/usr/bin/env bash
set -e

# 1. Tạo thư mục lưu trữ backup ĐỘC LẬP bên ngoài thư mục dự án Staging
BACKUP_DIR="/var/www/quannho_staging_backups/snapshots"
mkdir -p "$BACKUP_DIR"

# 2. Đặt umask 077 để bảo vệ file backup
umask 077

# 3. Tạo biến tên file duy nhất
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
STAGING_BACKUP_FILE="${BACKUP_DIR}/staging_backup_${TIMESTAMP}.sql"

# 4. Chụp snapshot schema & dữ liệu test của Staging qua Compose service
docker compose \
  --project-name quannho_staging \
  --file /var/www/quannho_staging/docker-compose.staging.yml \
  exec -T staging-db \
  pg_dump -U postgres -d postgres > "$STAGING_BACKUP_FILE"

# 5. Kiểm tra exit code câu lệnh
if [ $? -eq 0 ]; then
  echo "Backup command exited with code 0."
else
  echo "Backup command FAILED!" && exit 1
fi

# 6. Kiểm tra file backup tồn tại và dung lượng > 0 bytes trên biến file duy nhất
if [ -s "$STAGING_BACKUP_FILE" ]; then
  echo "Backup file size verified > 0 bytes: ${STAGING_BACKUP_FILE}"
else
  echo "Backup file is empty!" && exit 1
fi

# 7. Tính checksum SHA-256
sha256sum "$STAGING_BACKUP_FILE" > "${STAGING_BACKUP_FILE}.sha256"

# 8. Kiểm tra header hợp lệ của PostgreSQL dump
if head -n 20 "$STAGING_BACKUP_FILE" | grep -q "PostgreSQL database dump"; then
  echo "PostgreSQL dump header verified successfully."
else
  echo "Invalid dump header!" && exit 1
fi
```

---

## 3. THỦ TỤC THỬ NGHIỆM RESTORE (RESTORATION TEST PROCEDURE)

Trước khi thực hiện Destroy, phải thử nghiệm restore file backup vào một database container thử nghiệm tạm thời trong cùng project Staging:

```bash
# 1. Khởi tạo container Postgres thử nghiệm tạm thời
docker run -d --name staging-db-restore-test \
  --network quannho_staging_default \
  -e POSTGRES_PASSWORD=test_restore_pass \
  supabase/postgres:15.1.0.147

# 2. Chờ DB thử nghiệm ready
docker exec staging-db-restore-test pg_isready -U postgres -h localhost

# 3. Restore file backup vừa tạo vào container thử nghiệm
docker exec -i staging-db-restore-test psql -U postgres -d postgres < "$STAGING_BACKUP_FILE"

# 4. Kiểm tra dữ liệu restore thành công
docker exec staging-db-restore-test psql -U postgres -d postgres -c "SELECT COUNT(*) FROM stores;"

# 5. Hủy container thử nghiệm restore
docker rm -f staging-db-restore-test
```

---

## 4. THỦ TỤC VÀ LỆNH DESTROY MÔI TRƯỜNG STAGING AN TOÀN 100%

### 4.1 Các Kiểm Tra Bắt Buộc Trước Khi Xóa (Pre-Destroy Mandatory Checks)
Trước khi chạy lệnh destroy, người vận hành bắt buộc phải kiểm tra và xác nhận 6 yếu tố:

1. **Project Label Check:** Xác nhận label `com.docker.compose.project=quannho_staging`.
2. **Container List Check:** Liệt kê chính xác danh sách container thuộc project:
   ```bash
   docker ps --filter "label=com.docker.compose.project=quannho_staging"
   ```
3. **Volume List Check:** Liệt kê các volume thuộc project (Compose tự thêm prefix `quannho_staging_`):
   ```bash
   docker volume ls --filter "label=com.docker.compose.project=quannho_staging"
   ```
4. **Absolute Path Verification:** Xác nhận đường dẫn tuyệt đối file compose:
   `/var/www/quannho_staging/docker-compose.staging.yml`
5. **Backup File Location Verification:** File backup SQL tồn tại trong đường dẫn độc lập `/var/www/quannho_staging_backups/snapshots/` và SHA-256 hash khớp.
6. **Restore Test Verification:** Đã khôi phục thử thành công trên `staging-db-restore-test`.

### 4.2 Lệnh Destroy Chính Xác Theo Compose Project Name
Chạy lệnh destroy duy nhất với tham số `--project-name` và `--file` tuyệt đối:

```bash
docker compose --project-name quannho_staging \
  --file /var/www/quannho_staging/docker-compose.staging.yml \
  down --volumes
```

---

## 5. QUY TRÌNH DỌN DẸP NGINX VÀ THƯ MỤC CÓ GUARD KIỂM TRA

Chỉ sau khi đã xác minh đường dẫn tuyệt đối bằng phép so sánh chuỗi:

```bash
TARGET_STAGING_DIR="/var/www/quannho_staging"

if [ "$TARGET_STAGING_DIR" = "/var/www/quannho_staging" ] && [ "$TARGET_STAGING_DIR" != "/" ] && [ "$TARGET_STAGING_DIR" != "/var/www" ]; then
  sudo rm -rf "$TARGET_STAGING_DIR"
else
  echo "Safety Guard Abort: Invalid path target!" && exit 1
fi
```
