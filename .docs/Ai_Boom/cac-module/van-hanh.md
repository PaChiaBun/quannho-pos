# ⚙️ Module: Vận Hành (Operations)

**Trạng thái:** ✅ Hoàn thành (v1.0)  
**Cập nhật:** 17/05/2026

---

## Mục Đích
Hệ thống checklist công việc theo ca — giúp nhân viên biết cần làm gì trong ca, manager theo dõi tiến độ realtime.

---

## Kiến Trúc 3 Tab

### Tab 1: Nhiệm Vụ (Staff view)
- Nhân viên thấy danh sách task được giao cho mình hôm nay
- Task nhóm theo giờ mục tiêu (08:30, 09:00, Cuối ca…)
- **Shift badge** hiển thị ca hiện tại (tự detect theo giờ thực)
- Nhấn task → đánh dấu hoàn thành (haptic feedback)
- Long press → thêm ghi chú trước khi hoàn thành
- Progress header: `X / Y nhiệm vụ` + progress bar
- "Hoàn thành! 🎉" khi xong tất cả

### Tab 2: Cấu Hình (Manager only)
- Tạo / sửa / xóa template công việc
- Mỗi template có:
  - Tên công việc + mô tả/hướng dẫn
  - Giờ mục tiêu (chuỗi: "09:00", "Cuối ca"...)
  - **Vai trò** (dropdown — ai thấy task này)
  - **Ca làm việc** (dropdown — task chỉ hiện trong ca nào)
  - **Assign nhân viên cụ thể** (chip multi-select — cá nhân hóa)
- Card template hiển thị badge: 🕐 giờ, 🔆 gắn ca, 🟢 X NV
- Tab "Bộ Mẫu": 19 preset roles (Tạp vụ, Thu ngân, Bếp, Bar...) để nạp nhanh

### Tab 3: Báo Cáo (Manager only)
- Xem tiến độ hoàn thành task của tất cả nhân viên
- Lọc theo ngày

---

## 🔒 Logic Lọc Task (Shift Gating)

Task hiển thị cho nhân viên theo thứ tự ưu tiên:

```
Ưu tiên 1: Assign cá nhân
  → task có assignedStaffIds chứa userId của nhân viên → LUÔN HIỆN

Ưu tiên 2: Match vai trò
  → task.storeRoleId == null (tất cả) HOẶC khớp role của nhân viên
  → không khớp role → ẨN

Ưu tiên 3: Check ca
  → task có shiftConfigId → chỉ hiện khi isCurrentShift() == true
  → task không có shiftConfigId → hiện tất cả ca
```

**isCurrentShift():** So sánh `startHour:startMinute` đến `endHour:endMinute` với giờ hiện tại. Hỗ trợ ca qua đêm (endHour < startHour).

---

## 📊 Database

### Bảng `ops_task_templates`
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | UUID | PK |
| store_id | UUID | FK → stores |
| store_role_id | UUID? | FK → store_roles (null = tất cả vai trò) |
| role_name | TEXT? | Tên vai trò (cache) |
| title | TEXT | Tên công việc |
| description | TEXT? | Hướng dẫn chi tiết |
| target_time | TEXT? | "09:00", "Cuối ca", null |
| sort_order | INT | Thứ tự hiển thị |
| is_active | BOOL | Xóa mềm |
| shift_config_id | UUID? | FK → store_shift_configs (null = tất cả ca) |
| assigned_staff_ids | UUID[] | Assign cá nhân (array) |

### Bảng `ops_daily_logs`
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | UUID | PK |
| store_id | UUID | FK |
| template_id | UUID | FK → ops_task_templates |
| staff_id | UUID | Nhân viên được giao |
| staff_name | TEXT | Cache tên |
| log_date | DATE | Ngày (YYYY-MM-DD) |
| is_completed | BOOL | Đã hoàn thành chưa |
| completed_at | TIMESTAMPTZ? | Thời điểm hoàn thành |
| notes | TEXT? | Ghi chú khi hoàn thành |

---

## Luồng Hoạt Động

```
Manager tạo template (Cấu Hình)
  → Gán role + ca + nhân viên cụ thể

Nhân viên vào app (Nhiệm Vụ)
  → ensureMyLogsToday() chạy auto khi mở tab
  → Lọc templates theo role + ca + assign
  → Tạo daily_log cho từng template match
  → Nhân viên thấy task và đánh dấu hoàn thành

Manager xem báo cáo (Báo Cáo)
  → Thấy tiến độ toàn quán
```

---

## Provider Architecture

| Provider | Loại | Mô tả |
|----------|------|-------|
| `opsRepositoryProvider` | Provider | Singleton OpsRepository |
| `opsTemplatesProvider` | StreamProvider | Tất cả templates (manager) |
| `opsShiftConfigsProvider` | FutureProvider | Danh sách ca của quán |
| `opsMyTemplatesProvider` | StreamProvider | Templates lọc cho NV hiện tại |
| `opsMyLogsProvider` | StreamProvider | Logs hôm nay của NV |
| `opsStoreRolesProvider` | FutureProvider | Roles cho dropdown |
| `opsReportProvider` | FutureProvider.family | Báo cáo theo ngày |

---

## File Structure

```
lib/modules/ops/
  ├── screens/
  │   ├── ops_screen.dart          ← Entry + tab router
  │   ├── ops_staff_screen.dart    ← Tab Nhiệm Vụ (staff)
  │   ├── ops_config_screen.dart   ← Tab Cấu Hình (manager)
  │   └── ops_report_screen.dart  ← Tab Báo Cáo (manager)
  ├── providers/
  │   └── ops_providers.dart       ← Riverpod providers + shift gating logic
  └── repository/
      └── ops_repository.dart      ← Supabase CRUD
```

---

## Câu Hỏi Thường Gặp

- *"Thêm công việc mới?"* → Vận Hành → Cấu Hình → "+" → điền form → Lưu
- *"Nhân viên không thấy task?"* → Kiểm tra: (1) task có đúng role không, (2) task gắn ca → đang đúng giờ ca không, (3) có assign đúng staff_id không
- *"Muốn task chỉ hiện trong Ca Sáng?"* → Cấu Hình → sửa task → chọn "Ca Sáng" trong dropdown Ca làm việc
- *"Assign 1 task cho riêng 1 người?"* → Cấu Hình → sửa task → chọn tên nhân viên trong "Assign nhân viên cụ thể"
- *"Task tự tạo mỗi ngày không?"* → Có — `ensureMyLogsToday()` tự seed log khi nhân viên mở tab Nhiệm Vụ
- *"Manager thấy task của nhân viên không?"* → Có — tab Báo Cáo hiện tiến độ toàn quán. Nhưng tab Nhiệm Vụ của owner thì hiện TẤT CẢ task (không lọc ca)
