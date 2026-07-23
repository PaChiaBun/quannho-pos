# Nhật Ký Phát Triển — Quán Nhỏ POS

> Ghi lại công việc mỗi ngày để dễ theo dõi tiến độ.
> Format: ✅ Hoàn thành | 🔲 Cần làm | ⚠️ Vấn đề | ➡️ Tiếp theo

---

## 2026-04-22

### Đã làm
- ✅ Tạo hệ thống `.docs/` và workflow `/qn` để nạp context dự án
- ✅ Redesign màn hình bếp (`kitchen_screen.dart`):
  - UI card phiếu bếp đẹp hơn: gradient header, font to, quantity pill
  - Thêm ghi chú nội bộ bếp (tap vào món → bottom sheet)
  - Thêm dialog hỏi lý do khi dọn phiếu
- ✅ DB migration v8: thêm `kitchenNote` + `editHistoryJson` vào `kitchen_ticket_items`
- ✅ Redesign POS screen: gradient header, product grid theo category, cart bar
- ✅ POS Note System: long press → sheet chọn món + ghi chú, nút Bếp → confirm sheet

---

## 2026-04-23 (sáng)

### Đã làm
- ✅ Module Nhân Viên Universal (schema v11):
  - 3 bảng Drift: `StaffMembers`, `StaffShifts`, `StaffPermissions`
  - CRUD + PIN verify (SHA-256) + clockIn/clockOut
  - `staff_login_screen.dart`: chọn NV + PIN keypad
  - `nhan_vien_screen.dart`: quản lý + chấm công

---

## 2026-04-23 (chiều) — Hệ thống Auth mới

### Quyết định kiến trúc
> **Bỏ toàn bộ "Kết nối quán bằng mã thiết bị"** → Thay bằng **Tài khoản người dùng (SĐT + Mật khẩu)**

Logic mới:
- Nhân viên **tự tạo tài khoản** (SĐT + mật khẩu) → đưa SĐT cho chủ quán add vào
- Chủ quán **tạo quán** → nhận mã quán `QN-XXXX` (lưu trong Cài đặt, dùng khi cần)
- **Đa thiết bị, đa quán**: đăng nhập 1 lần, chọn quán nếu thuộc nhiều nơi
- **Không cần PIN** để mở app — chỉ cần đăng nhập 1 lần, session tự persist

### Files đã tạo/sửa
| File | Vai trò |
|------|---------|
| `lib/core/services/user_auth_service.dart` | Service auth chính: Đăng ký / Đăng nhập / Tạo quán / Session |
| `lib/core/providers/session_provider.dart` | Riverpod provider quản lý SessionData toàn app |
| `lib/screens/auth_screen.dart` | UI màn hình Login + Register (1 màn hình, 2 tab) |
| `supabase/add_auth_tables.sql` | SQL tạo bảng auth trên Supabase |
| `lib/screens/splash_screen.dart` | Bỏ onboarding check → thẳng /auth hoặc /home |
| `lib/screens/settings_screen.dart` | Thêm mã quán + nút Đăng xuất |
| `lib/main.dart` | Thêm route /auth, await Supabase init |

### Cấu trúc Data (Supabase)

#### Bảng `user_accounts`
```sql
id            uuid PRIMARY KEY
phone         text UNIQUE          -- SĐT chuẩn hoá: +84...
password_hash text                 -- SHA-256(phone:password:qn_pos_2024_salt)
display_name  text
created_at    timestamptz
```

#### Bảng `store_members`
```sql
id         uuid PRIMARY KEY
user_id    uuid → user_accounts.id
store_id   uuid → stores.id
role       text  -- owner / manager / cashier / waiter / kitchen / stock
is_owner   boolean
created_at timestamptz
UNIQUE(user_id, store_id)
```

#### Bảng `stores` (thêm column mới)
```sql
-- Thêm vào schema cũ:
owner_user_id uuid → user_accounts.id
```

### Session lưu trữ (SharedPreferences)
| Key | Kiểu | Giá trị |
|-----|------|---------|
| `auth_user_id` | String | UUID của user |
| `auth_user_phone` | String | SĐT đã chuẩn hoá |
| `auth_user_name` | String | Tên hiển thị |
| `auth_store_id` | String? | UUID quán đang chọn |
| `auth_store_name` | String? | Tên quán |
| `auth_store_code` | String? | Mã quán `QN-XXXX` |
| `auth_role` | String | owner / cashier / ... |
| `auth_is_owner` | bool | Có phải chủ quán không |

### Logic phân quyền
```
Đăng nhập
├── stores.isEmpty → Hiện dialog: "Tạo quán" hoặc "Đợi chủ add vào"
├── stores.length == 1 → Vào /home thẳng
└── stores.length > 1 → Hiện /store_picker để chọn quán
```

### Bugs đã fix hôm nay
- ✅ `SupabaseService.initialize()` không có `await` → race condition khi khởi động
- ✅ `_generateCode()` dùng timestamp → có thể trùng → đổi sang `Random.secure()`
- ✅ GRANT permission `stores`, `devices` table bị thiếu → tạo quán bị lỗi 403
- ✅ Onboarding screen sau khi hoàn tất → redirect `/home` → đổi thành `/auth`

### Tiếp theo (ưu tiên)
- ➡️ **Module Nhân viên**: Khi chủ add nhân viên → insert `store_members` (SĐT lookup từ `user_accounts`)
- ➡️ Đổi mật khẩu
- ➡️ RLS: thiết lập policies trước khi production
- ➡️ Migrate data từ Drift local → Supabase cloud (products, orders, v.v.)

---

## 2026-04-24

### Đã làm
- ✅ Tạo `lib/core/widgets/create_store_sheet.dart` — bottom sheet tạo quán dùng chung (Dashboard + Settings)
- ✅ Dashboard header: khi chưa có quán → hiện card CTA "Chưa có quán nào" với nút "Tạo quán" ngay chỗ doanh thu
- ✅ Settings `_ShopInfoCard`: khi chưa có quán → hiện nút outlined "Tạo quán mới" thay cho mã quán
- ✅ Sau khi tạo thành công: session tự cập nhật tại chỗ, header chuyển sang hiện doanh thu — không navigate

### Tiếp theo (ưu tiên)
- ➡️ Test luồng: đăng nhập tài khoản chưa có quán → tạo quán từ Dashboard/Settings → xác nhận header chuyển sang doanh thu
- ➡️ **Module Nhân viên**: Khi chủ add nhân viên → insert `store_members` (SĐT lookup từ `user_accounts`)
- ➡️ Đổi mật khẩu

---


---

## 2026-04-28

### Đã làm
- ✅ Tách module **Chấm công** thành module độc lập (tab index 10)
- ✅ `chamcong_screen.dart`: Staff view (VÀO/RA CA + selfie + GPS) + Manager view (báo cáo)
- ✅ `drive_service.dart`: Upload ảnh Google Drive qua Service Account, fallback Supabase Storage
- ✅ SQL migration: thêm cột photo_url, latitude, longitude, address, drive_file_id vào staff_shifts
- ✅ SQLite schema v12: seed module `chamcong` vào local DB

### ⚠️ Bug pattern hay gặp — REALTIME PERMISSIONS (lỗi lặp lại)

> Sau khi chủ đổi quyền, nhân viên không thấy cập nhật

**Root cause:** Supabase Broadcast KHÔNG đáng tin cậy (sender + receiver phải subscribe đồng thời)

**Fix chuẩn:**
1. Subscribe **Postgres Realtime** trực tiếp lên bảng `store_roles` trong `StaffSyncService`
2. `permsVersionProvider` counter → `_staffPermsProvider` watch → auto-refetch
3. `role_manager._save()` gọi `broadcastPermsChanged` sau khi lưu
4. SQL bắt buộc: `ALTER PUBLICATION supabase_realtime ADD TABLE store_roles;`

### Tiếp theo
- ➡️ Setup Google Drive Service Account (Phase 2 chấm công)
- ➡️ Test luồng: chụp ảnh → GPS → upload Drive → xem báo cáo chủ quán
- ➡️ RLS policies trước khi production

---

## 2026-04-28 (tiếp) — Manager View Chấm Công & Icon Vai Trò

### Đã làm
- ✅ Fix build error: `_ManagerViewState.build` sai signature (`WidgetRef ref` → dùng field `ref` của `ConsumerState`)
- ✅ **Mở rộng bộ icon vai trò:** Từ 12 → 50 icon, chia 6 nhóm (Nhân viên, F&B, Bán hàng, Kho/Vận, Dịch vụ, Kỹ thuật)
  - Cập nhật cả `_iconMap` trong `nhan_vien_screen.dart` và `_kIcons` trong `role_manager_screen.dart`
- ✅ **Đại tu Manager View chấm công** (`chamcong_screen.dart`):
  - Chuyển `_ManagerView` sang `ConsumerStatefulWidget` để hỗ trợ filter
  - Thêm filter: Hôm nay / Tuần này / Tháng này
  - Section "Đang làm ca" với badge LIVE (realtime)
  - Collapsible groups — gom ca theo từng nhân viên, có thể đóng/mở
  - Thống kê tổng ca + tổng giờ trên mỗi nhóm
  - Nâng limit fetch từ 30 → 300 ca

---

## 2026-04-29 — Thu Chi & Kiến Trúc AI Bum

### Đã làm

#### Module Thu Chi (`finance_screen.dart`)
- ✅ **Redesign header:** Period tabs (Hôm nay/Tuần/Tháng) đưa vào inline title row — xóa bỏ thanh chips riêng bên dưới header
- ✅ **Xóa bar chart:** Bỏ `_IncomeExpenseBar` khỏi header (trông xấu khi data = 0)
- ✅ **FAB label:** Thêm label "Ghi chi" cho FAB đỏ (trước chỉ là icon không rõ nghĩa)
- ✅ **Fix filter arrows:** "↓ Thu / ↑ Chi" → "↑ Thu / ↓ Chi" (thu = tiền vào ↑, chi = tiền ra ↓)
- ✅ **Group by date:** List giao dịch phân nhóm theo ngày (Hôm nay / Hôm qua / T3, 27/04...) với divider line
- ✅ **Subtitle header:** Thêm dòng mờ nhỏ "Doanh thu POS · Chi phí vận hành" giúp user hiểu module ngay khi mở
- ✅ **Auto badge clickable:** Badge [Auto ⓘ] có thể tap → SnackBar giải thích "Tự động từ: [tên đơn]. Không thể xóa thủ công."

#### Kiến Trúc AI Bum
- ✅ **Thảo luận & thiết kế** toàn bộ kiến trúc Bum qua 12 câu hỏi:
  - Cấu trúc: 1 file chính + thư mục module riêng
  - Mục đích: vừa doc dev, vừa system prompt cho AI
  - Tone: tùy đối tượng (chủ quán: chuyên nghiệp, nhân viên: thân thiện)
  - Phạm vi: hướng dẫn app + tư vấn kinh doanh + phân tích data thực
  - Memory: compressed memory 3 tầng (~3,000-4,000 tokens/request, tiết kiệm 70%)
  - Engine: GPT (OpenAI)
  - Data: Bum đọc được toàn bộ data quán
- ✅ **Tạo 13 files** trong `.docs/Ai_Bum/`:
  - `Ai_Bum.md` — tổng quan, system prompt chính
  - `tinh-cach-bum.md` — tính cách, cách xưng hô, milestone
  - `ky-uc-bum.md` — kiến trúc memory 3 tầng, schema DB, token budget
  - `xu-ly-data.md` — data context, phân cấp quyền, ví dụ inject prompt
  - `cac-module/` — 9 files chi tiết từng module (ban-hang, kho-hang, thu-chi, diem-tich, bao-cao, quan-ly-ban, bep, nhan-vien, cham-cong)

### Quyết Định Quan Trọng
> **Quy tắc mới:** Sau mỗi tính năng hoàn thành → cập nhật file module trong `Ai_Bum/cac-module/` + nhật ký này. Đây là tài liệu sống theo dự án.

### Tiếp Theo
- ➡️ Dev các module còn lại → cập nhật `Ai_Bum/cac-module/` tương ứng
- ➡️ Khi đủ module → bắt đầu build tính năng Bum thật sự (chat UI + GPT integration)
- ➡️ Setup bảng `bum_memories` trên Supabase cho memory dài hạn

---

## 2026-04-29 (tối) — Chấm Công Realtime Fix

### Đã làm
- ✅ **Fix Manager View hiển thị 0 ca:**
  - Root cause: `isManager = s.isOwner || s.role == 'manager'` — thiếu `role == 'owner'`
  - Khi `isOwner` không persist đúng từ SharedPreferences (session cũ) → query theo userId chủ quán → 0 ca
  - Fix: thêm `|| s.role == 'owner'` vào cả 2 chỗ (`_myShiftsProvider` + `_isManager` getter)
- ✅ **Thêm Supabase Realtime cho Manager View:**
  - Subscribe `staff_shifts` table → khi nhân viên Vào/Ra Ca → `ref.invalidate(_myShiftsProvider)` → data cập nhật ngay
  - Bỏ `PostgresChangeFilter` (cần `REPLICA IDENTITY FULL` mới hoạt động với filter)
  - SQL chạy trên Supabase: `ALTER TABLE staff_shifts REPLICA IDENTITY FULL;`
  - SQL chạy trên Supabase: `ALTER PUBLICATION supabase_realtime ADD TABLE staff_shifts;`
- ✅ **Thêm Timer.periodic 60s cho duration LIVE:**
  - `_ShiftRow` là `StatelessWidget` → duration tính 1 lần khi render → "0p" không đếm lên
  - Fix: `_liveTimer = Timer.periodic(60s, () => setState({}))` trong `_ManagerViewState`
  - Duration LIVE cập nhật mỗi phút — trễ tối đa 1 phút, chấp nhận được
  - 0 network calls — chỉ rebuild local widget

### Kết Quả
- Owner thấy ca nhân viên realtime khi vào/ra ca ✅
- Duration LIVE đếm lên theo phút (19p vs 20p — chênh tối đa 1p) ✅

---

## 2026-04-30 (tối) — Responsive Layout: Tablet & Desktop

### Bối cảnh
Mục tiêu: Làm POS chạy tốt trên **Pixel Tablet** (Android emulator 2560×1600, 2x DPI → 1280×800 logical px) mà không phá layout mobile (iPhone/Android phone ~360px).

### Đã làm

#### G0 — Responsive Utility
- ✅ Tạo `lib/utils/responsive.dart`:
  - `isMobile` < 600px | `isTablet` 600–1023px | `isDesktop` ≥ 1024px
  - `isLargeScreen` = tablet + desktop
  - `gridColumns` → 2 / 3 / 4 cột theo thiết bị

#### G1 — Navigation Shell (`main.dart`)
- ✅ **Tablet/Desktop**: thay `BottomNavigationBar` → `NavigationRail` bên trái
  - Tablet: icon-only (width 72px)
  - Desktop: icon + label (extended, width 160px)
  - Logo thương hiệu Bum (`assets/branding/logo_head.png`) ở đầu Rail
- ✅ **Mobile**: giữ nguyên BottomNavigationBar

#### G2 — Dashboard Grid (`dashboard_screen.dart`)
- ✅ Grid modules: từ hardcode 2 cột → responsive 3–4 cột trên màn hình lớn

#### G3 — POS Split-pane (`pos_screen.dart`)
- ✅ **Desktop/Tablet**: layout 2 cột cố định
  - Trái (flex 62): menu sản phẩm + search + category chips
  - Phải (320–380px): `_CartPanel` permanent — không cần mở sheet
- ✅ **Mobile**: giữ nguyên layout đơn cột + floating cart bar
- ✅ **Product grid**: dùng `LayoutBuilder` đo width thực của khu vực → tự chọn 2/3/4 cột
- ✅ **`_CartPanel`**: thêm `isPanel` flag:
  - `isPanel: true` (desktop) → không gọi `Navigator.pop()`, không có drag handle
  - `isPanel: false` (mobile sheet) → giữ nguyên hành vi cũ
- ✅ **Fix màn đen sau "Đơn mới"**: `_CartPanel` mobile gọi `Navigator.pop()` trước khi mở checkout → pop nhầm POS screen → fix bằng `isPanel` flag

#### G4 — Card kích thước responsive (`_ProductCard`)
- ✅ Wrap trong `LayoutBuilder` để scale theo width thực của card:
  - **Normal** (> 260px): icon 52, font 20/17, pad 14
  - **Compact** (160–260px): icon 40, font 14/13, pad 10 ← tablet 3 cột
  - **Tiny** (< 160px): icon 32, font 12/11, pad 8 ← desktop 4 cột
- ✅ `childAspectRatio` theo số cột: 4 cột=1.1 / 3 cột=1.3 / 2 cột=0.88

### Câu hỏi: Ảnh hưởng tới mobile không?

> **CÓ ảnh hưởng, nhưng là ảnh hưởng tốt:**

| Thay đổi | Mobile trước | Mobile sau | Đánh giá |
|---|---|---|---|
| NavigationRail | BottomNav (giữ nguyên) | BottomNav (không đổi) | ✅ Không ảnh hưởng |
| POS layout | Đơn cột | Đơn cột (giữ nguyên) | ✅ Không ảnh hưởng |
| Cart panel | Floating bar | Floating bar (giữ nguyên) | ✅ Không ảnh hưởng |
| Product grid | 2 cột | 2 cột (LayoutBuilder ~163px) → Compact mode | ✅ Font nhỏ hơn (14px thay 30px) — phù hợp hơn |
| Card size | fontSize=30 cứng (quá to!) | fontSize=14 compact | ✅ Tốt hơn, không overflow |
| childAspectRatio | 0.88 (giữ nguyên) | 0.88 | ✅ Không đổi |

**Kết luận:** Responsive logic chạy runtime theo `MediaQuery` / `LayoutBuilder` nên **tự thích nghi đúng thiết bị**. Mobile nhận font nhỏ hơn (hợp lý cho 2 cột ~163px rộng). Tablet nhận 3 cột + cart panel cố định.

### Môi trường test
- **Tablet emulator**: Pixel Tablet API34 (1280×800 logical px) — dùng để test responsive
- **Build**: `flutter run` vào emulator Android, không build macOS (Xcode beta không ổn định)

### Tiếp theo
- ➡️ Test thực tế trên điện thoại Android thật
- ➡️ G4: Module Bếp — Kanban 3 cột trên Desktop/Tablet
- ➡️ G5: Print routing theo thiết bị (bill bếp / bill thu ngân / mang về)

---

## 2026-05-01 (~23:44 → 00:51)

### Vấn đề phát hiện
- ⚠️ **Bàn trên tablet không hiển thị** dù phone đã tạo bàn
- ⚠️ `BanSyncService` chỉ dùng Supabase Broadcast (ephemeral) → cần cả 2 máy online cùng lúc mới sync được
- ⚠️ Bảng `ban_zones` và `ban_dining_tables` **chưa được tạo trên Supabase** (SQL migration chưa chạy)
- ⚠️ `GRANT` permission cho `anon` role chưa có → `permission denied` khi đọc DB
- ⚠️ Channel Broadcast bị `timedOut` → `_channel == null` → `saveZones/saveTables` bỏ qua không push gì
- ⚠️ Broadcast payload: `Applied 0 zones` do device khác (staff phone) respond với DB trống

### Đã làm
- ✅ **Chạy SQL migration** trên Supabase tạo `ban_zones` + `ban_dining_tables`
- ✅ **Tắt RLS** + **GRANT ALL TO anon, authenticated** → fix permission denied
- ✅ **BanSyncService overhaul** — dual-layer sync:
  - Layer 1: **Supabase DB** (persistent) — load khi app start, ghi khi thêm/sửa bàn
  - Layer 2: **Broadcast** (realtime) — push ngay cho device đang online
- ✅ **Auto-reconnect**: channel `timedOut/channelError/closed` → tự kết nối lại sau 5 giây
- ✅ **DB persist độc lập**: `saveZones/saveTables` ghi lên Supabase DB kể cả khi channel chết
- ✅ **Batch upsert**: thay vì loop từng bàn một (N HTTP req) → 1 batch call duy nhất
- ✅ **Dual-format payload**: xử lý cả `{zones:[]}` lẫn `{payload:{zones:[]}}` để tương thích

### Kỹ thuật quan trọng
```dart
// Batch upsert thay vì loop:
await _sb.from('ban_zones').upsert(
  zones.map((z) => {...}).toList(),
  onConflict: 'id',
);

// Auto-reconnect khi channel mất:
} else if (status == RealtimeSubscribeStatus.timedOut || ...) {
  Future.delayed(const Duration(seconds: 5), () => _subscribeChannel(storeId, db));
}
```

### Phát hiện root cause
- Phone (emulator-5554) channel bị `timedOut` từ 17:15 → đến tận 23:49 chưa reconnect → **mọi `saveTables` call đều bị bỏ qua** vì `_channel == null`
- Broadcast giữa phone→tablet hoạt động đúng nhưng tablet bị "Applied 0 zones" vì **staff phone (5556) có DB trống** respond trước phone thật

### Trạng thái hiện tại
- ✅ Sync **phone ↔ staff phone ↔ tablet** hoạt động
- ✅ DB Supabase có data — thiết bị mới join sẽ load được ngay cả khi không có máy khác online
- ⚠️ Emulator ARM (`qemu-system-aarch64`) chạy chậm hơn device thật — **bình thường, device thật sẽ mượt**

### Tiếp theo
- ➡️ G5: Module **In ấn** — tách luồng in: bếp / thu ngân / mang về
- ➡️ Test end-to-end: Mở bàn → Gọi món → Bếp Kanban → Thanh toán
- ➡️ Bật lại **RLS đúng cách** trước khi release production (hiện đang tắt cho dev)

---

## 2026-05-01 (chiều — 14:19 → ...)

### Đã làm

#### Fix Manager View Chấm Công — "0 ca"
- ✅ **Debug + xác định root cause**: Manager có `storeId` hợp lệ, query trả về 17 ca, nhưng `SingleChildScrollView` lồng sai trong `CustomScrollView` khiến widget không render đúng
- ✅ **Thêm debug print** vào `_myShiftsProvider` và `_applyFilter` — xác nhận timezone (`isUtc=true`, `toLocal()` đúng ngày 01/05)
- ✅ **Bỏ `RefreshIndicator > SingleChildScrollView`** lồng sai — giữ layout phẳng trong `SliverToBoxAdapter`
- ✅ **Thêm nút "Làm mới"** góc phải trên — `ref.invalidate(_myShiftsProvider)` thủ công
- ✅ **Fix stats "Đang làm"**: dùng `allShifts` (toàn bộ ca) thay vì `filtered` (đã lọc ngày) → tránh hiện sai 0 người đang làm
- ✅ **Label stats động**: "Ca hôm nay / Ca tuần / Ca tháng" thay đổi theo tab filter
- ✅ **Fix "Đang làm ca" section**: hiển thị từ `activeAll` (không filter ngày) thay vì `activeFiltered`

#### Responsive POS (từ 2026-04-30)
- ✅ Đã hoạt động ổn định trên cả emulator-5554 (phone) và emulator-5556 (staff phone)

#### Bắt đầu dev — Tuỳ chỉnh thời gian Chấm Công
- ➡️ Thêm mũi tên ← → để lùi/tới tuần/tháng
- ➡️ Tap vào tiêu đề → mở date picker để chọn khoảng bất kỳ
- ➡️ "Hôm nay" cố định, không thay đổi
- ➡️ Server-side filter (from/to) khi cần xem data xa hơn 300 ca cache

### Quyết định kiến trúc
> **Tuần/Tháng nav**: thêm `_weekStart` + `_navYear/_navMonth` vào state, filter client-side.
> Khi cần xem xa hơn 300 records → `getShifts(from, to)` query server-side.

### Tiếp theo
- ➡️ Hoàn thiện UI ← → tuần/tháng + date picker
- ➡️ G5: Module **In ấn**
- ➡️ Test end-to-end: Mở bàn → Gọi món → Bếp → Thanh toán

---

## 2026-05-01 (tối)

### Đã làm

#### Hệ thống ảnh sản phẩm — Cook.ai Library
- ✅ **Bỏ AI generate ảnh** (Stable Diffusion + Gemini) — không ổn định, sai món
- ✅ **Tích hợp thư viện Cook.ai.vn**: khi nhấn "Tìm ảnh từ Cook.ai.vn" →
  - Gọi `https://cook.ai.vn/api/recipes/?action=search&q={tên món}&limit=9`
  - Hiện bottom sheet grid 3×3 ảnh thật của Cook.ai
  - Chọn ảnh → download → upload lên Supabase Storage → lưu vào DB
- ✅ **Fix Supabase Storage RLS**: tạo policy `product-images: allow all` cho phép anon upload/read/delete
- ✅ Nút đổi thành **"Tìm ảnh từ Cook.ai.vn"** (icon image_search, màu cam)
- ✅ Loading state: "Đang tìm..." màu cam thay vì "Gemini đang tạo..." màu xanh

#### UI Card sản phẩm — Bán hàng (POS)
- ✅ **Ảnh fill full card** khi sản phẩm có ảnh (thay vì ảnh nhỏ 52px góc trái)
- ✅ **Gradient overlay** phía dưới card (0% → 55% đen) để đọc tên/giá rõ
- ✅ **Thanh nền mờ** (42% đen) ở đáy card chứa tên + giá — nổi hẳn trên ảnh
- ✅ **Tên món to hơn**: `nameSize + 4`, `FontWeight.w900`
- ✅ **Giá format "20K"** thay vì "20 K Đ đ":
  - `20K` / `150K` / `1.5Tr` — ngắn gọn, đọc nhanh
  - Helper `fmtCard()` riêng cho card, hoá đơn vẫn dùng format đầy đủ
- ✅ **Fix double đ**: bỏ thêm "đ" thủ công vì `fmtMoney()` đã có "Đ" rồi
- ✅ Card không có ảnh: giữ nguyên layout icon cũ (không bị ảnh hưởng)

### Kiến trúc API
- Cook.ai.vn là domain production chạy 24/7 trên VPS riêng
- App gọi thẳng internet (không phụ thuộc PC) → hoạt động khi deploy App Store bình thường
- 700+ ảnh đồ ăn Việt Nam thật, chính xác, miễn phí

### Tiếp theo
- ➡️ Thêm nhiều sản phẩm có ảnh để test hiển thị grid trong POS
- ➡️ G5: Module **In ấn** (hoá đơn nhiệt)
- ➡️ Test end-to-end: Mở bàn → Gọi món → Bếp → Thanh toán

---

## 2026-05-02 — Migration hoàn tất: Drift → Supabase (UI Layer)

### Bối cảnh
Toàn bộ UI layer (`pos_screen`, `ban_screen`, `inventory_screen`) còn phụ thuộc Drift SQLite local. Mục tiêu session này: xóa triệt để Drift khỏi các screen, thay bằng Supabase repository pattern.

### Đã làm

#### Phase 1 — `ban_screen.dart` (hoàn tất từ session trước)
- ✅ Fix `_TableShapePainter`: đổi field `colorValue` → `color` theo schema mới
- ✅ Tất cả `BanRepository` method calls đã đúng
- ✅ **0 lỗi** static analysis

#### Phase 2 — `inventory_screen.dart`
- ✅ Xóa import `drift/drift.dart`, `app_database.dart`
- ✅ `imagePath` → `imageUrl` toàn bộ file
- ✅ `StockStatus.notTracked` → `StockStatus.ok` (enum đã đổi)
- ✅ `CoreProductsCompanion` → `Map<String, dynamic>` trong `update()`
- ✅ `adjustStock(productName:)` → xóa param không còn tồn tại
- ✅ `m.referenceId` → `m.note` (field rename trong `StockMovementModel`)
- ✅ `DateTime.fromMillisecondsSinceEpoch(String)` → `DateTime.parse(String)` (timestamp đổi sang ISO 8601)
- ✅ **0 lỗi** static analysis

#### Phase 3 — `pos_screen.dart` (65 lỗi → 0)
- ✅ `CoreProduct` → `ProductModel` toàn bộ (~15 chỗ, dùng sed)
- ✅ `imagePath` → `imageUrl`
- ✅ Rewrite `_sendCartToKitchen()`: Drift insert → Supabase insert cho 5 bảng (`ban_zones`, `ban_dining_tables`, `ban_sessions`, `ban_session_items`, `kitchen_tickets`, `kitchen_ticket_items`)
- ✅ Rewrite `_TablePickerSheet`: `db.select(db.banDiningTables)` → `banRepositoryProvider.watchAllTables()`
- ✅ Rewrite `_RecentOrdersSheet`: Drift stream → `posRepositoryProvider.watchTodayOrders()` → `StreamBuilder<List<OrderModel>>`
- ✅ Rewrite `_PosOrderCard`: `StatelessWidget(AppDatabase db)` → `ConsumerWidget` dùng `posRepositoryProvider.getOrderItems()`
- ✅ `DateTime.fromMillisecondsSinceEpoch(int)` → `DateTime.tryParse(String)`
- ✅ Fix null-safety: `sessionProvider?.storeId`
- ✅ Fix method name: `watchTables()` → `watchAllTables()`
- ✅ **0 lỗi** static analysis

#### Phase 4 — Rà soát & cleanup
- ✅ Xóa import `ban_sync_service` thừa khỏi `ban_screen.dart`
- ✅ Khôi phục imports đúng cho `inventory_screen.dart` (dart:convert, dart:typed_data, http, image_picker, app_providers)
- ✅ Rewrite 4 test files (`product_repository_test`, `customer_repository_test`, `loyalty_repository_test`, `settings_repository_test`):
  - Skip các test Drift in-memory (không còn hỗ trợ)
  - Thêm pure Dart unit tests cho models (`ProductModel.fromMap`, `CustomerModel.fromMap`, `LoyaltyRewardModel.fromMap`, `LoyaltyStats`)
- ✅ Deprecate `test/helpers/test_database.dart`
- ✅ **0 lỗi** toàn project (kể cả test/)

### Dead code còn lại (không xóa — tham khảo sau)
| File | Mô tả |
|------|-------|
| `ban_sync_service.dart` | Legacy Drift-based sync, không được gọi từ đâu |
| `product_sync_service.dart` | Legacy Drift product sync, không được gọi từ đâu |
| `app_event_bus.dart` | Legacy event bus dùng Drift, không được gọi từ đâu |

> Có thể xóa 3 file này trong sprint sau khi đã confirm không còn cần.

### Kỹ thuật quan trọng

```dart
// Timestamp: Supabase dùng ISO 8601 (String), không phải epoch (int)
final dt = DateTime.tryParse(order.createdAt) ?? DateTime.now();

// Supabase upsert — tránh conflict khi tạo zone/table hệ thống:
await sb.from('ban_zones').upsert({...}, onConflict: 'id', ignoreDuplicates: true);

// Stream provider inline (tránh tạo provider toàn cục cho 1 widget):
final tablesAsync = ref.watch(StreamProvider((ref) =>
  ref.watch(banRepositoryProvider).watchAllTables()));
```

### Trạng thái kiến trúc sau session

| Layer | Trạng thái |
|-------|-----------|
| UI Screens | ✅ 100% Supabase |
| Repositories | ✅ 100% Supabase |
| Services (sync/event) | ⚠️ Dead code Drift — không ảnh hưởng runtime |
| Test files | ✅ 0 lỗi (skip Drift tests, thêm model tests) |
| Production code | ✅ **0 errors, 0 Drift dependencies** |

### Tiếp theo
- ✅ Xóa `ban_sync_service.dart`, `product_sync_service.dart`, `app_event_bus.dart`, `app_events.dart` (dead code) — **2026-05-02**
- ➡️ Test end-to-end: Mở bàn → Gọi món → Bếp Kanban → Thanh toán
- ➡️ G5: Module **In ấn** — bill bếp / bill thu ngân / mang về
- ➡️ Bật lại **RLS đúng cách** trước khi release production
- ➡️ Viết integration tests thật với Supabase test environment

---

## 2026-05-03 — Module Kho Chuyên Nghiệp

### Bối cảnh
Thêm module mới dành cho nhà hàng lớn: quản lý định lượng khẩu phần, công thức chế biến, lệnh sản xuất, và tự động trừ kho nguyên liệu thô khi bán hàng.

### Đã làm

#### Database Migration (`supabase/kho_pro_migration.sql`)
- ✅ Tạo 4 bảng mới trên Supabase Production:
  - `recipes` — công thức món ăn (gắn với POS product)
  - `recipe_ingredients` — nguyên liệu trong từng công thức (số lượng, đơn vị)
  - `production_orders` — lệnh sản xuất theo ngày (pending/in_progress/done)
  - `production_logs` — log nguyên liệu đã dùng + giá vốn tại thời điểm
- ✅ Thêm 4 cột vào bảng `products`: `is_raw_material`, `ingredient_category`, `cost_price_latest`, `unit_cooking`
- ✅ RLS: `USING(true)` — đồng bộ với pattern toàn dự án (cách ly theo `store_id` tầng app)
- ✅ GRANT `SELECT, INSERT, UPDATE, DELETE` cho `anon, authenticated`
- ✅ 5 index tối ưu truy vấn theo `store_id`, `recipe_id`, `scheduled_date`

#### Module Flutter (`lib/modules/kho_chuyen_nghiep/`)
- ✅ Tạo module độc lập, đăng ký tại index 11 trong `IndexedStack` (`main.dart`)
- ✅ Entry screen: `kho_chuyen_nghiep_screen.dart` — 5 tab (Tổng quan / Nguyên liệu / Công thức / Sản xuất / Báo cáo)
- ✅ `kho_chuyen_nghiep_dashboard_screen.dart` — overview KPI: tồn kho thấp, lệnh hôm nay, food cost
- ✅ `ingredient_list_screen.dart` — danh sách nguyên liệu thô, lọc theo category
- ✅ `recipe_list_screen.dart` + `recipe_form_screen.dart` + `recipe_detail_screen.dart`
- ✅ `production_order_screen.dart` — tạo lệnh SX, kiểm tra tồn kho, thực hiện → tự trừ nguyên liệu
- ✅ `kho_chuyen_nghiep_report_screen.dart` — 3 tab: Food Cost / Tiêu thụ / Sản lượng
- ✅ `kho_chuyen_nghiep_repository.dart` — toàn bộ Supabase CRUD (recipes, ingredients, production)
- ✅ `kho_chuyen_nghiep_providers.dart` — Riverpod providers

#### Đăng ký vào hệ thống Module
- ✅ `module_tile.dart` → thêm `'kho_pro'` vào `kModuleConfigs` (màu tím `#9333EA`, icon `restaurant_menu_rounded`)
- ✅ `module_repository.dart` → thêm `ModuleConfig(id: 'kho_pro', label: 'Kho Chuyên Nghiệp', position: 4)`
- ✅ `staff_service.dart` → thêm `'kho_pro'` vào `kAllModules` + `kDefaultPerms` (owner/manager/stock)
- ✅ `dashboard_screen.dart` → thêm vào `permMap` + `_navigateTo('/kho_pro' → index 11)`
- ✅ `app_providers.dart` → thêm `NavTab.khoPro = 11` + đổi `nav_slots_v2` default `[0,1,2,11]`

#### Đổi tên chuẩn hoá
- ✅ Đổi tên folder `kho_pro/` → `kho_chuyen_nghiep/`
- ✅ Đổi tên 5 file: `kho_pro_*.dart` → `kho_chuyen_nghiep_*.dart`
- ✅ Cập nhật toàn bộ imports trong 19 files (sed batch)
- ✅ `flutter analyze` → **0 errors**

### Cấu trúc file module
```
lib/modules/kho_chuyen_nghiep/
├── providers/
│   └── kho_chuyen_nghiep_providers.dart
├── repository/
│   └── kho_chuyen_nghiep_repository.dart
└── screens/
    ├── kho_chuyen_nghiep_screen.dart          ← Entry (5 tabs)
    ├── kho_chuyen_nghiep_dashboard_screen.dart
    ├── kho_chuyen_nghiep_report_screen.dart
    ├── ingredient_list_screen.dart
    ├── recipe_list_screen.dart
    ├── recipe_form_screen.dart
    ├── recipe_detail_screen.dart
    └── production_order_screen.dart
```

### Quy tắc quan trọng
> Module ID trong DB/permMap giữ nguyên `'kho_pro'` (để tương thích data Supabase đã lưu).
> Chỉ đổi tên file/folder/label hiển thị sang `kho_chuyen_nghiep` / "Kho Chuyên Nghiệp".

### Tiếp theo
- ➡️ Phase 4: POS Integration — EventBus listener tự động trừ nguyên liệu khi bán
- ➡️ Thêm "Guided Tour" lần đầu mở module cho user mới
- ➡️ Test lệnh sản xuất end-to-end: tạo công thức → tạo lệnh → hoàn thành → kiểm tra tồn kho

---

## 2026-05-04 — UI/UX Polish & Navigation Fixes (Kho CN)

### Đã làm

#### Navigation & AppBar
- ✅ Fix màn hình đen khi bấm back khỏi Kho CN: dùng `ref.read(navTabProvider.notifier).goTo(0)` thay vì `Navigator.pop` (module nằm trong IndexedStack tab 11)
- ✅ Thêm `SliverAppBar` + nút Back cho `ProductionOrderScreen`
- ✅ Refactor AppBar Kho CN: tách `title/leading` ra khỏi `FlexibleSpaceBar.background` → fix chữ "Kho Chuyên Nghiệp" bị cắt khi scroll (parallax issue)

### Tiếp theo
- ➡️ POS Integration — EventBus tự động trừ nguyên liệu khi bán
- ➡️ Xóa dead code: `ban_sync_service.dart`, `product_sync_service.dart`, `app_event_bus.dart`

---

## 2026-05-05 — 4 Product Types + Kho Filter Overhaul

### Bối cảnh
Nghiên cứu đối thủ (Toast, MarketMan, Lightspeed, KiotViet, MISA CukCuk, Sapo FnB) → triển khai **4 product types** chuyên nghiệp theo chuẩn F&B quốc tế.

### Thiết kế Product Types
```
ingredient    → Nguyên liệu thô    → Nhập từ NCC, dùng trong recipe
semi_finished → Bán thành phẩm    → SX từ ingredient, dùng trong recipe
purchased     → Hàng mua sẵn bán  → Nhập từ NCC, bán POS trực tiếp (bia, nước...)
finished      → Thành phẩm        → SX từ recipe, bán qua POS
```

### Đã làm

#### Filter Logic (không cần ALTER TABLE — product_type là TEXT field)
- ✅ **Phiếu nhập kho**: chỉ `ingredient + purchased + semi_finished` (không nhập `finished`)
- ✅ **Kho CN → Tab Nguyên liệu**: hiện `ingredient + semi_finished`; badge phân biệt loại
- ✅ **RecipeForm dropdown**: chỉ cho chọn `ingredient + semi_finished` làm nguyên liệu
- ✅ **Badge màu** trong picker + card theo loại (xanh lá / xanh dương / cam)

#### Module Kho cơ bản — Tab Restructure (3 → 4 tab)
- ✅ **Tất cả / Nguyên liệu / Hàng hoá & Menu / Cảnh báo**
  - "Nguyên liệu": `ingredient + semi_finished`
  - "Hàng hoá & Menu": `purchased + finished`
  - "Cảnh báo": gộp sắp hết + hết hàng; hết hàng lên đầu; badge đỏ/cam theo mức nghiêm trọng

#### Files đã sửa
| File | Thay đổi |
|------|---------|
| `phieu_nhap_hang_screen.dart` | Filter picker + badge màu |
| `ingredient_list_screen.dart` | Filter `semi_finished` + badge |
| `recipe_form_screen.dart` | Dropdown filter `ingredient + semi_finished` |
| `inventory_screen.dart` | 4 tab mới, tab scrollable, gộp cảnh báo |
| `kho_repository.dart` | Comment enum 4 loại |

### Quyết định thiết kế cuối ngày (05/05)

> **Lưu lại để không quên** — chi tiết đầy đủ ở `.docs/Ai_Bum/cac-module/kho-hang.md`

1. **Không có trường "Loại sản phẩm"** trong form SP — quá phức tạp với user
2. **Chip "Nguyên liệu"** trong Danh mục → auto-map `product_type = ingredient` khi lưu
3. **Mọi danh mục khác** → auto-map `product_type = finished`
4. **Chip "Thêm"** thay cho "Khác" → tạo danh mục tùy chỉnh mới (chip tím, có nút ✕)
5. **Phiếu nhập** hiện tất cả SP (không filter) — vì có quán mua đồ ăn từ nơi khác bán lại
6. **Thứ tự tab Kho:** Tất cả → Hàng hoá & Menu → Nguyên liệu → Cảnh báo

### Tiếp theo
- ➡️ **POS Integration** — tự động trừ kho nguyên liệu khi bán
- ➡️ Xóa dead code: `ban_sync_service.dart`, `product_sync_service.dart`, `app_event_bus.dart`
- ➡️ Test lệnh SX end-to-end: tạo công thức → lệnh SX → hoàn thành → kiểm kho

---

## 2026-05-06 — Fix Giá Vốn = 0 (Kho Chuyên Nghiệp)

### Bối cảnh
Giá vốn công thức luôn hiện **0 Đ** dù nguyên liệu đã được lưu đúng (3 nguyên liệu, ingredient_id hợp lệ, products join trả về cost đúng).

### Root Cause
```dart
// ❌ SAI — cost_price_latest = 0 (default DB, không phải null)
// → 0 ?? 55000 = 0 vì 0 không phải null
final rawCost = (prodData?['cost_price_latest'] ?? prodData?['cost_price']) as num?;

// ✅ ĐÚNG — kiểm tra > 0 thay vì ??
final cl = (prodData?['cost_price_latest'] as num?)?.toDouble() ?? 0;
final cp = (prodData?['cost_price'] as num?)?.toDouble() ?? 0;
final rawCost = cl > 0 ? cl : cp;
```

**Nguyên nhân sâu xa:** Bảng `products` có cột `cost_price_latest` với giá trị mặc định = `0` (không phải `NULL`). Cột này chỉ được cập nhật khi có đơn nhập hàng qua `phieu_nhap_hang`. Khi chưa có đơn nhập, `cost_price_latest = 0` → toán tử `??` nhận `0` là giá trị hợp lệ → không fallback về `cost_price`.

### Đã làm
- ✅ **Debug bằng print()** xuyên suốt `fetchRecipes()` và `_saveIngredients()`:
  - Xác nhận ingredient_id được lưu đúng ✅
  - Xác nhận products join trả về `cost=55000, unit=kg` ✅
  - Xác nhận `costLatest=0.0` dù DB có `cost=55000` → lộ bug `??`
- ✅ **Fix** trong `kho_chuyen_nghiep_repository.dart` → `_buildIngredients` loop:
  - Đổi logic `??` → `cl > 0 ? cl : cp`
- ✅ **Verified:** Log xác nhận `cost=27250.0` sau fix:
  ```
  "banh canh": 3 ings, cost=27250.0
    thit heo: costLatest=95.0, lineCost=19000.0
    ray song: costLatest=55.0, lineCost=2750.0
    banh canh: costLatest=55.0, lineCost=5500.0
  ```
- ✅ Dọn sạch toàn bộ debug print sau khi xác nhận fix

### Kỹ thuật quan trọng
> **Quy tắc:** Cột DB có DEFAULT 0 (không phải NULL) → **KHÔNG dùng `??`** để fallback.  
> Phải kiểm tra `> 0` hoặc check riêng `!= null && != 0`.

### Quy trình lưu giá vốn (chuẩn hoá)
```
cost_price (products) = Giá vốn thủ công do chủ nhập
cost_price_latest (products) = Giá vốn tự động từ đơn nhập gần nhất (0 nếu chưa có)

Khi tính giá vốn công thức:
→ Dùng cost_price_latest nếu > 0 (có đơn nhập → giá thực tế)
→ Fallback về cost_price nếu cost_price_latest = 0 (chưa có đơn nhập)
```

### Tiếp theo
- ➡️ **POS Integration** — tự động trừ kho nguyên liệu khi bán
- ➡️ Test lệnh SX end-to-end: tạo công thức → lệnh SX → hoàn thành → kiểm kho
- ➡️ Xóa dead code: `ban_sync_service.dart`, `product_sync_service.dart`, `app_event_bus.dart`

---

## 2026-05-09 — Fix Module Thu Chi (Finance Sync)

### Bối cảnh
Module Thu Chi hiển thị **Tổng thu: 0 Đ** dù Dashboard đã hiện doanh thu 1.3 Tr Đ (3 đơn). Đã QC nhiều lần nhưng không tìm ra root cause vì chỉ đọc code mà không chạy debug log.

### Phương pháp phát hiện

Chạy `flutter run -d emulator-5554 --debug` → thực hiện đơn test → đọc log:

```
[Checkout] finance silent err: PostgrestException(
  message: Could not find the 'reference_id' column of 'finance_records'
  in the schema cache, code: PGRST204
)
```

**Kết luận:** Lỗi infrastructure Supabase, không phải logic Dart. Đọc code không thể phát hiện.

---

### Root Cause #1 — Cột thiếu trong `finance_records`

Bảng chỉ có: `id, store_id, type, amount, description, is_auto, recorded_at`
Code insert thêm `reference_id` + `category_id` → PGRST204 → insert fail hoàn toàn.

**SQL Migration đã chạy trên Supabase:**
```sql
ALTER TABLE finance_records
  ADD COLUMN IF NOT EXISTS reference_id TEXT,
  ADD COLUMN IF NOT EXISTS category_id  UUID;
NOTIFY pgrst, 'reload schema';
```

---

### Root Cause #2 — `financeRecordsProvider` không được invalidate sau checkout

Stats header refresh đúng nhưng danh sách giao dịch trống vì StreamProvider không bị invalidate.

**Fix — `checkout_sheet.dart` + `ban_screen.dart`:**
```dart
ref.invalidate(financeRecordsProvider);     // list giao dịch
ref.invalidate(financeStatsProvider);
ref.invalidate(todayFinanceStatsProvider);
```

---

### Root Cause #3 — `showModalBottomSheet` không `await` trong finance_screen

Ghi thu/Ghi chi → `Navigator.pop(context, true)` trả về nhưng caller không bắt → providers không refresh.

**Fix — `finance_screen.dart`:**
```dart
Future<void> _openAddSheet({String type = 'income'}) async {
  final result = await showModalBottomSheet<bool>(...);
  if (result == true) {
    ref.invalidate(financeRecordsProvider);
    ref.invalidate(financeStatsProvider);
    ref.invalidate(todayFinanceStatsProvider);
  }
}
```

---

### Kết Quả

| Chức năng | Trước | Sau |
|-----------|-------|-----|
| POS bán hàng → ghi vào Thu Chi | ❌ | ✅ |
| Bàn thanh toán → ghi vào Thu Chi | ❌ | ✅ |
| Ghi thu/chi thủ công | ❌ | ✅ |
| Danh sách refresh ngay sau giao dịch | ❌ | ✅ |

### Bài Học Kinh Nghiệm

> **Luôn chạy `flutter run` với debug log trước khi kết luận về logic bug.**
> Lỗi PGRST204 không thể phát hiện chỉ bằng cách đọc code.

**Quy trình debug data không ghi đúng:**
1. `flutter run -d emulator-5554` → có debug console
2. Thực hiện action → đọc `debugPrint` output
3. PGRST204 → kiểm tra schema DB → thêm cột + `NOTIFY pgrst, 'reload schema'`
4. Data ghi được mà UI không refresh → kiểm tra `ref.invalidate()` + `await` sheet

### Tiếp theo
- ✅ **POS Integration** — đã có sẵn trong `pos_repository.dart` (block 3b)
- ✅ **Lệnh SX** — `production_order_screen.dart` đầy đủ logic
- ✅ **Dead code** — 3 file đã xóa từ trước

---

## 2026-05-09

### QC Toàn Diện — Phát Hiện & Fix 5 Vấn Đề

#### Bugs đã fix:

**🔴 BUG #1 — ban_screen thiếu deductIngredients Kho CN (Critical)**
- `ban_screen.dart _checkout()` bước 3 chỉ trừ `products.stock_qty` thô
- Thiếu block gọi `KhoProRepository.deductIngredients()` như `pos_repository.dart`
- **Fix:** Thêm block `3b` vào `_checkout()` — fetch recipes → map theo `posProductId` → `deductIngredients()` (silent fail)

**🟠 BUG #2 — `print()` spam production trong CoreProductRepository**
- `_storeId()` và `watchAll()` dùng `print()` trần → spam console mỗi thao tác
- **Fix:** Đổi sang `assert(() { debugPrint(...); return true; }())` — chỉ log trong debug mode

**🟡 BUG #3 — `updateStockQty()` dùng `.round()` mất precision**
- Nguyên liệu nhỏ (0.25 kg, 100g) bị làm tròn → sai số tích lũy
- **Fix:** Bỏ `.round()`, dùng `toStringAsFixed(3)` giữ 3 decimal

**🟡 ISSUE #4 — `orderNumber` ban_screen không sequential**
- Dùng UUID substring ngẫu nhiên (`QN-20260509-A3F1`) thay vì sequential (`QN-20260509-001`)
- **Fix:** Dùng DB count giống POS screen: `$prefix-${(count + 1).padLeft(3,'0')}`

**🟡 ISSUE #5 — `watchRecords()` finance stream lọc phía client**
- Stream tải toàn bộ `finance_records` của store về → filter ngày phía client
- **Fix:** Thêm `_fetchRecords()` với `.gte()/.lt()` server-side, stream chỉ dùng làm signal trigger

#### Kết quả:
- `flutter analyze` → **0 errors** ✅
- Tất cả cross-module operations vẫn silent fail, không block checkout

#### Vẫn cần theo dõi (low priority):
- `BanSessionModel.openedAt` dùng `int` ms — inconsistent với các models khác
- `KhoProRepository` khởi tạo thủ công trong `pos_repository.dart` — bypass DI
- Thiếu `finance_record` expense cho COGS khi `deductIngredients()` chạy qua POS

### Tiếp theo (sau QC round 1)
- ✅ Test end-to-end: kiểm tra `stock_movements` sau bán
- ✅ **QC Round 2** — fix 3 issues low priority còn lại (xem bên dưới)
- ➡️ Module In ấn / Bill bếp

---

## 2026-05-09 (tiếp)

### QC Round 2 — Fix 3 Issues Low Priority

**#7 — KhoProRepository DI (bypass Riverpod)**
- `pos_repository.dart` tạo `KhoProRepository(_productRepo)` thủ công trong mỗi lần checkout
- **Fix:** 
  - Thêm `_khoProRepo` vào constructor `PosRepository`
  - `app_providers.dart`: `posRepositoryProvider` inject `khoProRepositoryProvider` (re-use từ `kho_chuyen_nghiep_providers.dart`)
  - Không tạo duplicate provider — dùng `show khoProRepositoryProvider` import

**#8 — COGS finance_record expense khi deductIngredients**
- `deductIngredients()` chỉ trừ kho, không ghi chi phí → dashboard/báo cáo thiếu COGS
- **Fix:**
  - Fetch thêm `cost_price_latest`, `cost_price` khi fetch ingredients
  - Tính `totalCogs = Σ (stockDelta × unitCost)`
  - Ghi `finance_records` expense (silent fail) với `reference_id = orderId`
  - Cả POS (`pos_repository.dart`) và Bàn (`ban_screen.dart`) đều truyền `referenceId`

**#6 — BanSessionModel.openedAt int — bỏ qua**
- Kết luận: intentional — compat với Drift legacy (`app_database.g.dart`)
- Thay đổi sẽ break generated code → không đáng rủi ro

#### Kết quả:
- `flutter analyze` → **0 errors** ✅
- Không circular import (app_providers ← kho_chuyen_nghiep_providers được resolved đúng)

### Trạng thái dự án hiện tại
- ✅ POS Integration (trừ nguyên liệu khi bán POS + Bàn)
- ✅ COGS tracking đầy đủ trong Finance module
- ✅ Code chất lượng tốt (DI đúng, không print spam, precision đúng)
- ✅ Finance stream: server-side filter (giảm bandwidth)

### Tiếp theo
- ➡️ **Test end-to-end** thực tế trên device/emulator
- ➡️ **Module In ấn** — bill bếp, bill thu ngân

---

## 2026-05-10 — Module Tính Lương (Payroll)

### Bối cảnh
Xây dựng module Tính Lương hoàn chỉnh tích hợp với chấm công, hỗ trợ 4 chế độ lương và luồng duyệt/trả lương kết nối Finance.

### Đã làm

#### Phase B — Core Engine (`tinhluong_repository.dart`)
- ✅ **4 Model:** `PayrollPeriodModel`, `PayrollRecordModel`, `PayrollItemModel`, `StaffPayConfig`
- ✅ **Engine `calculatePayroll()`:** 4 chế độ lương:
  - **M1** — Theo giờ: `(hours - OT) × rate + OT × rate × 1.5`
  - **M2** — Cố định tháng: `baseSalary + OT × (base/26/8) × 1.5`
  - **M3** — Cố định + OT riêng: `base + OT × hourlyRate × 1.5`
  - **M4** — Theo ngày: `(hours/8) × dayRate + OT × (dayRate/8) × 1.5`
- ✅ **`aggregateShifts()`:** Đọc `staff_shifts`, tổng hợp giờ làm/OT/đi trễ mỗi NV
- ✅ **`generatePeriodRecords()`:** Auto-generate toàn bộ payroll cho kỳ từ chấm công
- ✅ **`recordPayrollExpense()`:** Ghi expense vào `finance_records` khi chốt lương

#### Phase C — Providers (`tinhluong_providers.dart`)
- ✅ 3 `FutureProvider.autoDispose`: `payrollPeriodsProvider`, `payrollRecordsProvider`, `payrollItemsProvider`

#### Phase D — UI (3 màn hình)
- ✅ `tinhluong_screen.dart` — danh sách kỳ lương, tạo kỳ mới (bottom sheet)
- ✅ `period_detail_screen.dart` — chi tiết kỳ, danh sách NV, "Tạo bảng lương tự động", duyệt/trả lương
- ✅ `record_detail_screen.dart` — phiếu lương chi tiết, thêm bonus/khấu trừ thủ công

#### Phase E — Registration (toàn hệ thống)
- ✅ `main.dart` — tab index 12, `_kTabMeta`, `IndexedStack`, `_navBarTabsForRole`
- ✅ `dashboard_screen.dart` — `permMap['tinhluong']` + `tabMap['/tinhluong'] = 12`
- ✅ `module_tile.dart` — `kModuleConfigs['tinhluong']` (teal-700, icon payments, badge 💰)
- ✅ `module_repository.dart` — `_kAllModules` position 10
- ✅ `staff_service.dart` — `kAllModules` + `kDefaultPerms` (owner + manager)
- ✅ `app_providers.dart` — `NavTab.tinhLuong = 12`

#### SQL Migration (`sql_migration_payroll.sql`)
- ✅ `payroll_periods`, `payroll_records`, `payroll_items`, `payroll_rules`
- ✅ `shift_templates`, `shift_assignments` (ca cố định)
- ✅ `ALTER TABLE staff_shifts ADD COLUMN is_late, late_minutes` v.v.
- ⚠️ **CHƯA CHẠY trên Supabase** — cần chạy trước khi test

### Cấu trúc file module
```
lib/modules/tinhluong/
├── providers/
│   └── tinhluong_providers.dart
├── repository/
│   └── tinhluong_repository.dart
└── screens/
    ├── tinhluong_screen.dart          ← Entry (danh sách kỳ)
    ├── period_detail_screen.dart      ← Chi tiết kỳ + auto-generate
    └── record_detail_screen.dart     ← Phiếu lương từng NV
```

### Luồng sử dụng
```
Dashboard → Tính Lương → Tạo kỳ tháng
  → "Tổng hợp bảng lương" (đọc staff_shifts)
  → Xem phiếu từng NV → chỉnh bonus/khấu trừ
  → Gửi duyệt → Duyệt → Trả lương (cash/transfer/momo)
  → Finance tự ghi expense "Chi lương: Tháng 5/2026"
```

### Kỹ thuật quan trọng
```dart
// Engine chuẩn: netPay không âm
final netPay = grossPay < 0 ? 0.0 : grossPay;

// Auto-generate kỳ lương từ chấm công
final shifts = await aggregateShifts(storeId, from, to);
for (final config in staffConfigs.entries) {
  await upsertRecord(periodId, PayrollInput(
    totalHours: shifts[userId]?.totalHours ?? 0, ...
  ));
}
```

### Tiếp theo
- ⚠️ **CHẠY SQL migration** `sql_migration_payroll.sql` trên Supabase trước khi test
- ➡️ Test end-to-end: Chấm công → Tạo kỳ → Auto-generate → Duyệt → Trả lương → Finance
- ➡️ Cấu hình lương NV: UI chỉnh salary_mode, base_salary, hourly_rate từng người
- ➡️ Module In ấn — bill bếp, bill thu ngân

---

## 2026-05-11 — Cấu Hình Lương NV + Module In Ấn

### Đã làm

#### UI Cấu Hình Lương (`staff_salary_config_screen.dart`)
- ✅ Screen mới trong module Tính Lương — truy cập từ icon ⚙️ ở AppBar
- ✅ Model `StaffSalaryConfig` + `StaffSalaryConfigRepo` (CRUD Supabase `staff_salary_configs`)
- ✅ Bottom sheet `_EditSheet`:
  - Nhập tên NV, vai trò, User ID
  - Radio chọn chế độ M1/M2/M3/M4 với mô tả rõ ràng
  - Form nhập mức lương: theo mode (giờ/tháng/ngày)
  - Ngưỡng OT (giờ/ca) + phạt đi trễ (đ/lần)
- ✅ `period_detail_screen._generate()` → đọc `staff_salary_configs` để dùng cấu hình thật, fallback M1/25K

#### Module In Ấn (`bill_printer`)
- ✅ `BillData`, `BillItem`, `BillPdfGenerator`:
  - `generateReceipt()` — hoá đơn thu ngân 80mm: header quán, bảng món, tổng tiền, loyalty
  - `generateKitchenTicket()` — phiếu bếp 80mm: to rõ, số lượng in to, ghi chú
  - Font: NotoSans (Google Fonts) — hỗ trợ tiếng Việt
- ✅ `BillPreviewScreen` — xem trước PDF + nút In / Share
- ✅ Helper `showBillPreview(context, billData)`
- ✅ Tích hợp vào `checkout_sheet.dart`:
  - Sau thanh toán: lưu `_billData` từ cart + shop info
  - Success view: nút **"In hoá đơn"** hiện nếu `_billData != null`
- ✅ `role_manager_screen.dart` — `_kModuleNames['tinhluong']` đã thêm

#### SQL Migration
- ✅ Thêm bảng `staff_salary_configs` vào `sql_migration_payroll.sql`

### Luồng In ấn
```
Checkout thành công
  → "In hoá đơn" → BillPreviewScreen
    → Xem trước PDF 80mm
    → Nút In → Printing.layoutPdf() → máy in Bluetooth/WiFi
    → Nút Share → PDF file
```

### Tiếp theo
- ⚠️ **Chạy SQL migration** `sql_migration_payroll.sql` trên Supabase
- ➡️ Settings: cấu hình tên quán/SĐT/địa chỉ để in lên hoá đơn
- ➡️ Test end-to-end: Bán hàng → Thanh toán → In hoá đơn

---

## 2026-05-11 (tiếp) — Nút In Phiếu Bếp

### Đã làm
- ✅ **Nút "In phiếu" trên mọi phiếu bếp** — `kitchen_screen.dart` `_TicketCard`:
  - Thêm button `🖨️ In phiếu` vào header card (góc phải, bên dưới timer)
  - Hiện ở **mọi trạng thái** (chờ / đang làm / xong) — không phải chờ xong mới in
  - Tap → gọi `_printKitchenTicket()` → mở `BillPreviewScreen` (PDF 80mm)

---

## 2026-05-11 (tiếp 2) — SQL Migration + Bill Footer

### Đã làm
- ✅ **SQL migration `sql_migration_payroll.sql` chạy thành công** trên Supabase Production:
  - `shift_templates`, `shift_assignments` — ca cố định
  - `payroll_periods`, `payroll_records`, `payroll_items`, `payroll_rules` — tính lương
  - `staff_salary_configs` — cấu hình lương NV
  - GRANT anon/authenticated đầy đủ
- ✅ **Kết nối `billFooter`** (lời cuối hoá đơn từ Settings) vào luồng in:
  - `BillData` thêm field `footer`
  - `BillPdfGenerator.generateReceipt()` dùng `bill.footer` thay vì hardcode "Cảm ơn quý khách!"
  - `checkout_sheet.dart` đọc `sRepo.billFooter` và truyền vào `BillData`
  - Luồng hoàn chỉnh: Settings → lưu `bill_footer` → đọc khi checkout → in lên hoá đơn

### Trạng thái hệ thống
- ✅ Tất cả bảng DB đã tạo đầy đủ
- ✅ Module In ấn hoàn chỉnh: checkout → PDF → share/in
- ✅ Module Tính Lương: UI + Engine + DB sẵn sàng
- ✅ Cấu hình lương NV: UI + DB sẵn sàng

### Tiếp theo
- ➡️ **Test end-to-end** thực tế:
  - Chấm công → Tạo kỳ lương → Auto-generate → Duyệt → Trả lương → Finance
  - Bán hàng POS → Thanh toán → In hoá đơn (kiểm tra SĐT/địa chỉ/lời cuối)
- ➡️ Cài đặt lương NV đầu tiên (vào Tính Lương → ⚙️)

---

## 2026-05-11 (sáng) — Module Tính Lương: Fix & Polish

### Đã làm

#### 🔧 Fix module Tính Lương hiển thị trên Home
- ✅ **Root cause**: `module_config_v2` trong Supabase lưu danh sách cũ, không có `chamcong` & `tinhluong`
- ✅ **Fix `ModuleRepository.getAll()`**: Thêm logic auto-merge — khi DB thiếu module mới có `isActive=true` trong code, tự động thêm vào và lưu lên Supabase
- ✅ **Bật default**: `chamcong` và `tinhluong` set `isActive: true` trong `_kAllModules`
- ✅ **Icon**: Đổi icon `tinhluong` từ 💰 (trùng Finance) → 💵

#### 🔐 Fix RLS — Không tạo được kỳ lương
- ✅ **Root cause**: `PostgrestException code 42501` — bảng `payroll_periods` bật RLS nhưng không có policy INSERT
- ✅ **Fix**: Chạy SQL tạo `FOR ALL` policy cho 6 bảng payroll + shift trên Supabase:
  - `payroll_periods`, `payroll_records`, `payroll_items`
  - `staff_salary_configs`, `shift_templates`, `shift_assignments`

#### 🗑️ UX — Bỏ nút FAB trùng lặp
- ✅ Xoá `FloatingActionButton.extended("+ Kỳ lương mới")` — đã có nút `+` trên AppBar
- ✅ Cập nhật hint text empty state: `"Bấm \"+\" góc trên để bắt đầu"`

#### 👥 UX — Dropdown chọn nhân viên thay nhập tay UUID
- ✅ **Thay thế** 3 field nhập tay (Tên NV, Vai trò, User ID) bằng `DropdownButtonFormField`
- ✅ Load danh sách NV từ `store_members JOIN user_accounts` — không cần copy UUID
- ✅ Khi chọn NV → tự điền Vai trò; vẫn có field override Vai trò/Chức danh
- ✅ Fix overflow 14px: dùng `selectedItemBuilder` + `maxLines: 1`
- ✅ Thêm class `_StaffOption` với `==` / `hashCode` override

#### ⚡ Feature — Hệ số OT tuỳ chỉnh (otMultiplier)
- ✅ **Vấn đề**: 4 chỗ hardcode `1.5` trong engine
- ✅ **Thêm field `otMultiplier`** xuyên suốt:
  - `StaffSalaryConfig.otMultiplier` (model + `fromMap` + `upsert`)
  - `StaffPayConfig.otMultiplier`
  - `PayrollInput.otMultiplier` (default 1.5)
  - `calculatePayroll()` — 4 case M1/M2/M3/M4 dùng `input.otMultiplier`
  - `generatePeriodRecords()` → truyền `config.otMultiplier`
  - `period_detail_screen._generate()` → truyền `saved?.otMultiplier ?? 1.5`
- ✅ **UI field**: "Hệ số OT (x lương)" với hint `• 1.5x thường • 2.0x cuối tuần • 3.0x ngày lễ`
- ✅ Đã chạy SQL trên Supabase (2026-05-11):
  ```sql
  ALTER TABLE staff_salary_configs
    ADD COLUMN IF NOT EXISTS ot_multiplier NUMERIC DEFAULT 1.5;
  ```

### Trạng thái hệ thống
- ✅ Module Tính Lương: visible, tạo kỳ lương thành công
- ✅ Cấu hình lương: dropdown NV, hệ số OT tuỳ chỉnh
- ✅ Engine: hoàn toàn per-staff (không còn global default nào)
- ✅ SQL `ot_multiplier` đã chạy thành công trên Supabase Production

### Tiếp theo
- ➡️ **Test E2E đầy đủ**: Cấu hình lương → Chấm công → Tạo kỳ → Generate → Duyệt → Trả
- ➡️ Kiểm tra `Finance sync` sau khi trả lương
- ➡️ Xem xét thêm báo cáo lương theo kỳ (biểu đồ)

---

## 2026-05-11 (chiều) — Fix 2 Bug Module Tính Lương

### Đã làm

**🔴 BUG #1 — N+1 Query trong `generatePeriodRecords()`**
- Root cause: vòng lặp gọi `aggregateShifts()` per-staff → N HTTP requests (1 NV = 1 query)
- Fix: thêm `_fetchRawShiftRows()` (1 query duy nhất) + `_aggregateOneUser()` (tính OT per-staff trong RAM)
- File: `tinhluong_repository.dart`

**🟠 BUG #2 — `period.totalAmount` stale khi ghi Finance expense**
- Root cause: `period` object cũ từ Navigator — không reflect bonus/khấu trừ thêm sau generate
- Fix: `freshTotal = all.fold(0.0, (s, r) => s + r.netPay)` từ records vừa fetch DB
- File: `period_detail_screen.dart`

### Kết quả
- `flutter analyze lib/modules/tinhluong/` → **0 errors** ✅

### Tiếp theo
- ➡️ **Test E2E**: Cấu hình lương → Chấm công → Tạo kỳ → Generate → Duyệt → Trả lương → Finance

---

## 2026-05-11 (chiều 2) — QC Round 2

### Đã làm

**🟡 ISSUE #3 — SQL migration thiếu `ot_multiplier`**
- Fix: thêm `ot_multiplier NUMERIC DEFAULT 1.5` vào `staff_salary_configs` trong `sql_migration_payroll.sql`
- Đồng bộ với `ALTER TABLE` đã chạy production

**🟡 ISSUE #4 — Label OT hardcode `× 1.5` trong UI**
- `record_detail_screen.dart` line 46 hiển thị cứng `× 1.5` bất kể `otMultiplier` thực
- Fix: bỏ hardcode, chỉ hiện số giờ (số tiền đã đúng từ DB)

**🟡 ISSUE #5 — `withOpacity` deprecated (2 chỗ)**
- Fix: đổi sang `withValues(alpha:)` trong `record_detail_screen.dart`

### Kết quả
- `flutter analyze lib/modules/tinhluong/` → **0 errors** ✅
- Còn warnings nhỏ (unnecessary_cast, deprecated Radio API) — không ảnh hưởng runtime

### Tiếp theo
- ➡️ **Test E2E thực tế**: Cấu hình lương → Chấm công → Tạo kỳ → Generate → Duyệt → Trả lương → Finance

---

## 2026-05-12 (sáng) — Fix Hiển Thị Tổng Lương + PDF Phiếu Lương

### Bối cảnh
Sau test thực tế, phát hiện 5 bug trong module Tính Lương chưa được QC đúng.

### Đã làm

**🔴 BUG #1 — List card hiển thị tổng lương sai (stale `total_amount`)**
- Root cause: `fetchPeriods()` chỉ đọc `payroll_periods.total_amount` từ DB — giá trị này không được sync khi thêm bonus/khấu trừ items trước khi deploy fix `_recalcNetPay`
- Fix: Nâng cấp `fetchPeriods()` thành **2-query pattern**:
  1. Fetch periods từ DB
  2. Batch-fetch tất cả `payroll_records.net_pay` trong 1 query duy nhất
  3. Group by `period_id`, tính `liveTotal = sum(net_pay)` trong Dart
  4. Override `totalAmount` trong memory + sync DB nền (fire-and-forget)
- Thêm `copyWith(totalAmount)` vào `PayrollPeriodModel`
- Files: `tinhluong_repository.dart`

**🔴 BUG #2 — PDF + UI hiển thị trùng lặp "Phụ cấp" + từng item**
- Root cause: In cả `record.allowanceTotal` (tổng gộp) VÀ từng `item` riêng type `bonus/allowance` → hiển thị 2 lần cùng số tiền
- Fix: Bỏ dòng `allowanceTotal` tổng hợp ở cả A4 và 80mm PDF, chỉ giữ từng item riêng với label đúng
- Files: `payslip_pdf_service.dart` + `record_detail_screen.dart`

**🟠 BUG #3 — Footer phiếu lương "Cảm ơn quý khách!"**
- Root cause: `billFooter` dùng chung với hoá đơn khách hàng — default là text dành cho khách
- Fix: `_loadStoreInfo()` kiểm tra nếu `billFooter` là default khách → thay bằng `'Cảm ơn bạn vì sự cố gắng trong tháng qua!'`
- Files: `record_detail_screen.dart` + `payslip_pdf_service.dart`

**🟡 BUG #4 — Báo Cáo Lương dùng `total_amount` stale**
- Root cause: `payrollReportProvider` fetch `total_amount` từ `payroll_periods` — cùng vấn đề stale data
- Fix: Batch-fetch `payroll_records.net_pay` và compute live total (đồng bộ pattern với `fetchPeriods`)
- File: `payroll_report_screen.dart`

**🟡 BUG #5 — Chart "Báo Cáo Lương" bị BOTTOM OVERFLOW 14px**
- Root cause: `Column` trong bar chart + `SizedBox(height: 180)` — tổng: bar(150) + text(12) + spacing(7) + label(16) = 185px > 180px
- Fix: Bar max height `150 → 120`, SizedBox `180 → 210`
- File: `payroll_report_screen.dart`

### Kết quả

| Kiểm tra | Trước | Sau |
|---|---|---|
| List card tổng lương | 988.542đ ❌ | 10.544.096đ ✅ |
| PDF trùng "Phụ cấp" + item | Hiển thị 2 lần ❌ | Chỉ item riêng ✅ |
| Footer phiếu lương | "Cảm ơn quý khách!" ❌ | "Cảm ơn bạn vì sự cố gắng..." ✅ |
| Báo cáo lương total | Stale ❌ | Live ✅ |
| Chart overflow | 14px ❌ | Sạch ✅ |

- `flutter analyze lib/modules/tinhluong/` → **0 errors** ✅

### Kỹ thuật quan trọng

```dart
// Pattern batch-fetch live total: 2 queries, không N+1
final records = await _sb.from('payroll_records')
    .select('period_id, net_pay')
    .inFilter('period_id', periodIds);

final Map<String, double> liveTotal = {};
for (final r in records) {
  liveTotal[r['period_id']] = (liveTotal[r['period_id']] ?? 0) + r['net_pay'];
}
return periods.map((p) => p.copyWith(totalAmount: liveTotal[p.id] ?? p.totalAmount)).toList();
```

> **Quy tắc:** Khi hiển thị tổng tiền trên list card — luôn tính từ child records,  
> KHÔNG đọc aggregated column từ parent table (dễ stale sau mutations).

### Tiếp theo
- ➡️ Test E2E đầy đủ phiếu lương: thêm bonus/khấu trừ → list card cập nhật ngay → xuất PDF → kiểm tra footer + items không trùng

---

## 2026-05-12 (tối) — Fix Huỷ Món Bếp Không Cập Nhật

### Root Cause (2 tầng)

**Tầng 1 — Sai `status` khi đóng ticket:**
- Code cũ: toàn bộ items bị huỷ → set `kitchen_tickets.status = 'xong'`
- Sai logic: `'xong'` là hoàn thành, không phải huỷ — bếp vẫn thấy trong tab Xong
- Đúng: set `'huy'` → `_fetchActiveTickets()` đã filter `.neq('status', 'huy')` → ticket biến mất

**Tầng 2 — Realtime không fire khi huỷ partial:**
- `kitchen_ticket_items` chưa có `REPLICA IDENTITY FULL`
- UPDATE `done=true` không trigger Realtime → bếp không reload
- Fix: touch `kitchen_tickets` (update `order_note` = existing) → bếp nhận event → item `done=true` bị lọc bởi `!i.done`

### Đã làm
- ✅ `ban_screen.dart _removeItem()` step 3:
  - Huỷ toàn bộ: `kitchen_tickets.status = 'huy'` (thay 'xong')
  - Huỷ partial: touch `kitchen_tickets` để trigger Realtime
- ✅ Tạo `supabase/fix_cancel_realtime.sql` — cần chạy trên Supabase

### Tiếp theo
- ⚠️ **Chạy `fix_cancel_realtime.sql`** trên Supabase SQL Editor trước khi test
- ➡️ Test: Huỷ 1 món (trong ticket 2 món) → bếp thấy còn 1 món ✓
- ➡️ Test: Huỷ toàn bộ → phiếu biến mất khỏi bếp ✓

---

## 2026-05-14 — Đơn Giản Hoá Logic Huỷ Món Sau Gửi Bếp

### Bối cảnh
Sau nhiều lần thử fix realtime sync (REPLICA IDENTITY, touch ticket để trigger) nhưng không ổn định đủ để tin cậy trong thực tế vận hành → quyết định **đơn giản hoá triệt để**.

### Quyết định kiến trúc

> **Sau khi gửi bếp: không cho tăng/giảm số lượng nữa — chỉ cho xoá trực tiếp.**
> Bếp thấy banner thông báo huỷ. Nhân viên báo bếp bằng bộ đàm.

### Logic mới (đã implement trong code)

**`ban_screen.dart` — UI item list:**
- Nút `-` và `+`: **ẩn hoàn toàn** khi `_isItemSent == true` (`da_gui`, `dang_lam`, `xong`)
- Nút 🗑️ (trash): khi đã gửi → gọi `_updateItemQty(item, 0)` → dialog chọn lý do bắt buộc → `_executeCancelItem()`

**`_executeCancelItem()` — luồng huỷ:**
1. Soft delete: `ban_session_items.kitchen_status = 'huy'` (không hard delete, tránh FK)
2. `kitchen_ticket_items.done = true`
3. Nếu toàn bộ items của ticket đều done → `kitchen_tickets.status = 'huy'`
4. Ghi `ban_session_void_logs` (store_id, session_id, table_label, product_name, action, reason, staff_name)

**`kitchen_screen.dart` — bếp thấy banner:**
- `voidNoticesProvider` stream watch `ban_session_void_logs` theo store_id
- `_VoidNoticeBanner`: banner đỏ "THÔNG BÁO SỬA ĐƠN" — hiện tên món, bàn, lý do, nhân viên
- Tự động dismiss sau **30 giây**, hoặc bấm "Đã hiểu ✓"
- Hiện tối đa 3 thông báo, còn lại gộp "+N thông báo khác"

### Luồng vận hành thực tế
```
Nhân viên bấm 🗑️ món đã gửi
    → Dialog: chọn lý do (Khách đổi ý / Nhầm / Hết món / Khác)
    → Xác nhận → món bị xoá khỏi bill, đánh dấu 'huy'
    → Banner đỏ hiện trên màn hình bếp
    → Nhân viên gọi bộ đàm báo bếp dừng làm
```

### Trạng thái hiện tại
- ✅ UI: nút +/- ẩn đúng khi món đã gửi
- ✅ Huỷ món: soft delete + ghi void log
- ✅ Bếp: banner thông báo tự dismiss 30s
- ✅ Món đã xong (`xong`): không cho xoá (hiện SnackBar cảnh báo màu vàng)
- ⚠️ **`fix_cancel_realtime.sql` chưa chạy** — cần kiểm tra xem có còn cần thiết không

### Tiếp theo
- ➡️ Test thực tế luồng: gửi bếp → xoá món → bếp thấy banner
- ➡️ Kiểm tra `fix_cancel_realtime.sql` — nếu không cần (vì không còn rely vào realtime update món) thì bỏ qua

---

## 2026-05-17 — Fix Navigation: Tab "Vận Hành" Cho Nhân Viên

### Bối cảnh
Sau nhiều session, nhân viên `aaacc` (role `nhan vien`) tap tab "Vận Hành" trên bottom bar nhưng **luôn bị redirect sang ChamCongScreen** thay vì OpsStaffScreen. Lỗi âm thầm, không crash, không log rõ.

### Root Cause Analysis

**Bug 1 — `navBarTabs.add(13)` sau filter:** (đã fix kỳ trước)
- `_navBarTabsForRole()` return set tabs theo storeRoles từ server
- `add(13)` được gọi SAU khi filter `rawSlots`, nên 13 bị drop khỏi `slots`
- **Fix:** Chuyển `add(13)` lên TRƯỚC bước filter

**Bug 2 — `_padSlots()` chen tab khác vào slot cuối:** (fix kỳ này)
- Khi `rawSlots = [0, 1, 6, 13]` mà storeRoles server không cấp tab `1` (pos) cho nhân viên → `1` bị filter → `slots = [0, 6, 13]` (3 items)
- `_padSlots` pad thêm tab từ `navBarTabs` (ví dụ tab `7` = Bàn) → `displaySlots = [0, 6, 13, 7]`
- Tab 13 ở vị trí thứ 3 (slot index 2), slot cuối là tab `7`
- Nhấn "Vận Hành" (slot 4) thực ra gọi `_setTab(7)` → BanScreen

**Bug 3 — Toạ độ ADB `input tap` sai:** (phát hiện trong quá trình debug)
- Dùng `y=1450` nhưng bottom bar của Pixel 6 (1080×2400, 420dpi) ở `y≈2290`
- Tất cả các "tap Vận Hành" trước đây không chạm vào bottom bar

### Giải pháp

**`lib/main.dart` — Overhaul `displaySlots` logic cho staff:**

```dart
// TRƯỚC (dễ bị _padSlots phá vỡ thứ tự)
final slots = rawSlots.where((t) => navBarTabs.contains(t)).toList();
final displaySlots = _padSlots(slots, navBarTabs);

// SAU (deterministic, staff luôn có tab 13 ở cuối)
final isStaff = !(session?.isOwner ?? false) &&
    session?.role != 'owner' && session?.role != 'manager';
final List<int> displaySlots;

if (isStaff) {
  // Lấy module đầu tiên được phép (trừ 0, 6, 13), pin 13 vào cuối
  final staffAllowed = navBarTabs
      .where((t) => t != 0 && t != 6 && t != 13)
      .toList()..sort();
  final mid = staffAllowed.isNotEmpty ? staffAllowed.first : 6;
  displaySlots = [0, 6, mid, 13];
} else {
  final slots = rawSlots.where((t) => navBarTabs.contains(t)).toList();
  displaySlots = _padSlots(slots, navBarTabs);
}
```

### Kết quả (Pixel 6 — role `nhan vien`)

| Slot | Tab | Module |
|------|-----|--------|
| 1 | 0 | Trang chủ |
| 2 | 6 | Cài đặt |
| 3 | 1 | Bán hàng (first allowed) |
| **4** | **13** | **Vận Hành** ✅ |

- ✅ `OpsStaffScreen` load đúng: **0/8 nhiệm vụ, 0%**
- ✅ Task cards hiển thị theo timeline 08:30 / 08:45 / 09:00...
- ✅ Bottom bar: "Vận Hành" active indicator hiển thị

### Bài học kỹ thuật

1. **`adb input tap` dùng physical pixels** — Pixel 6 (420dpi): `1dp = 2.625px`. Bottom bar ở y≈2290, không phải y=1450
2. **Đừng để `_padSlots` quyết định thứ tự slot** — Với staff, nên build `displaySlots` deterministic thay vì pad tự động
3. **Debug bằng `adb logcat | grep flutter`** — Log `[NavTabs]` cho thấy exact tabs được assign
4. **`storeRoles` load async** — First build có `storeRoles=[]`, chỉ sau ~4s mới có data đầy đủ → logic phải robust với cả 2 trạng thái

### Files đã sửa

| File | Thay đổi |
|------|----------|
| `lib/main.dart` | Overhaul `displaySlots` logic, pin tab 13 cuối cho staff |
| `lib/screens/nhan_vien_screen.dart` | Auto-dismiss MaterialBanner sau 3s |

### Trạng thái
- ✅ **RESOLVED** — Staff tap "Vận Hành" → OpsStaffScreen đúng
- ✅ **VERIFIED** trên Pixel 6 emulator (API 34), account `aaacc`

### Tiếp theo
- ➡️ Refine task completion flow trong `OpsStaffScreen` (expand/collapse state)
- ➡️ `opsMyLogsProvider` — invalidate/refresh tự động sau khi mark task done
- ➡️ Test với các account nhân viên khác để verify không bị regression

---

## 2026-05-25 — Tối ưu hóa Trải nghiệm Gọi món Giờ cao điểm (Module Bàn - _AddItemsSheet)

### Bối cảnh
Khi quán đông khách (giờ cao điểm), nhân viên gọi món cần thao tác cực nhanh. Thiết kế cũ của `_AddItemsSheet` có một số bất cập lớn gây cản trở:
1. Thẻ món ăn phình to từ 90px lên 400px do tự động mở rộng Toppings, Hương vị, Ghi chú nhanh khi chọn món (qty > 0) -> Gây mỏi tay khi phải cuộn dài.
2. Không có nút xóa nhanh ký tự trong ô tìm kiếm.
3. Không có sự khác biệt rõ rệt về màu sắc cho món đã chọn.
4. Không có nơi tập trung xem nhanh danh sách món đã chọn dưới dạng giỏ hàng nháp để đối chiếu nhanh với khách trước khi gửi bếp.

### Đã làm
- ✅ **Nút xóa nhanh ô tìm kiếm ("X" Clear Button):** Gắn `_searchCtrl` vào `TextField` và tích hợp `Icons.cancel_rounded` tại `suffixIcon` khi `_search.isNotEmpty`. Xóa sạch từ khóa chỉ với 1 chạm.
- ✅ **Cơ chế Thu gọn/Mở rộng tùy chọn (Collapsible Options):**
  - Mặc định khi chọn món (`qty > 0`), các phần Toppings, hương vị, ghi chú sẽ **ẩn đi** để tiết kiệm 70% diện tích thẻ món.
  - Bọc phần Column chi tiết món bằng `GestureDetector` (behavior opaque) để khi tap vào sẽ toggle mở rộng/thu gọn.
  - Bổ sung nút capsule **"Tùy chọn" / "Thu gọn"** (icon `tune_rounded`/`expand_less_rounded`) nằm cạnh Pill Counter để toggle trạng thái mở rộng/thu gọn.
  - Sửa đổi các điều kiện hiển thị của Topping, Hương vị và Ghi chú nhanh: chỉ hiển thị khi `qty > 0 && _expandedProductIds.contains(p.id)`.
- ✅ **Tông nền nổi bật cho món đã chọn (Selected Item Highlight):** Đổi màu nền Container món ăn từ trắng sang xanh Navy mờ nhạt (`_kNavy.withValues(alpha: 0.03)`) khi `qty > 0`. Giúp nhân viên quét mắt định vị siêu tốc khi cuộn nhanh.
- ✅ **Xem nhanh giỏ hàng nháp (Draft Cart Preview):**
  - Thêm nút capsule **"Xem chi tiết"** màu cam mờ xinh xắn ở góc trái Row tổng hợp dưới cùng.
  - Triển khai phương thức `_showDraftCartPreview(List<ProductModel> products)` mở ra Bottom Sheet hiển thị gọn gàng chỉ các món đã chọn cùng toppings/notes chi tiết và nút xóa nhanh món khỏi giỏ nháp.
- ✅ **Đã kiểm thử phân tích tĩnh:** Chạy `flutter analyze` xác nhận không có lỗi cú pháp hay phân tích tĩnh phát sinh do code mới.
- ✅ **Hot Restart thành công:** Kích hoạt thành công lệnh Hot Restart (gửi tín hiệu `USR2` cho cả 2 máy ảo `emulator-5554` và `emulator-5556`) để áp dụng giao diện tối ưu ngay lập tức.

### Files đã sửa
| File | Thay đổi |
|------|----------|
| `lib/screens/ban_screen.dart` | Gắn search controller + nút xóa 'X'; Đổi nền card; Thêm GestureDetector toggle và nút Tùy chọn; Ẩn/hiện tùy chọn theo trạng thái mở rộng; Thêm nút Xem chi tiết và popup preview giỏ nháp. |

### Tiếp theo
- ➡️ Nhận phản hồi từ người dùng sau khi trải nghiệm thực tế trên máy ảo.
- ➡️ Bật lại RLS an toàn trên Supabase khi dự án chuyển sang giai đoạn Production.

---

## 2026-05-30 — Sửa Lỗi Nhân Đôi Món Ăn (Duplicate Items Fix)

### Bối cảnh
Phát hiện lỗi nghiêm trọng khi gọi món nháp (Chưa gửi bếp):
- Các món ăn nháp bị tách thành nhiều dòng trùng lặp trên hóa đơn bàn (ví dụ 2 dòng Cơm tấm, 2 dòng Bún bò) thay vì được cộng dồn (gộp) số lượng, dẫn đến hóa đơn tính tiền bị nhân đôi vô lý.
- Badge trạng thái món vẫn hiển thị "Chưa gửi" bình thường nhưng không thể gộp số lượng.

### Root Cause Analysis

1. **Lệch Lọc Trạng Thái NULL từ DB (PostgREST inFilter Limit)**:
   * Trong Supabase database, cột `kitchen_status` của một số dòng nháp mang giá trị `null` hoặc `'pending'`.
   * Khi thêm món, hàm gộp trùng món nháp `addSessionItems(...)` lọc danh sách các món cũ bằng:
     ```dart
     .inFilter('kitchen_status', ['chua_gui', 'pending'])
     ```
   * Trong cơ chế của Postgres / PostgREST, bộ lọc `.in` không khớp với giá trị `NULL`.
   * Do đó, bản ghi cũ có `kitchen_status = null` bị bỏ sót hoàn toàn khỏi `existingRows`. Hàm gộp món tưởng là món mới nên chèn dòng mới với trạng thái `'chua_gui'`.
   * Ở tầng UI hiển thị, do `fromMap` tự động chuyển đổi cả `null` thành nhãn `'chua_gui'` ("Chưa gửi"), dẫn đến việc người dùng nhìn thấy nhiều dòng trùng lặp cùng ghi "Chưa gửi" và hóa đơn bị tăng gấp đôi tiền.

2. **Lỗi Race Condition do vuốt/nhấn đóng Bottom Sheet khi đang xử lý (Dismissible Async Gap)**:
   * Khi bấm "Xác nhận", hệ thống gửi API lưu món ăn xuống Supabase. Quá trình này mất khoảng 1-2 giây tùy thuộc vào chất lượng mạng.
   * Do `showModalBottomSheet` thiếu cơ chế ngăn chặn pop, người dùng có thể vuốt xuống đóng sheet hoặc tap ra ngoài khi tiến trình đang chạy ngầm, sau đó mở lại ngay lập tức và nhấn "Xác nhận" lần hai, tạo ra hai tiến trình chèn song song ghi đè trùng lặp dữ liệu vào database.

---

### Giải pháp

1. **Đồng bộ gộp trùng thông minh tại Repository**:
   * **Tệp sửa đổi**: [ban_repository.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/repositories/ban_repository.dart)
   * **Chi tiết**: Thay đổi cơ chế truy vấn trong `addSessionItems(...)`: tải toàn bộ session items bằng `.eq('session_id', sessionId)` và tiến hành lọc các món nháp (`null`, `'chua_gui'`, `'pending'`) trực tiếp trong bộ nhớ Dart. Điều này đảm bảo gộp số lượng chính xác 100% vào dòng cũ dù database có lưu giá trị nào.

2. **Chặn đóng màn hình khi đang thực thi API (Tầng UX/UI)**:
   * **Tệp sửa đổi**: [ban_screen.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/screens/ban_screen.dart)
   * **Chi tiết**: Bao bọc toàn bộ Bottom Sheet Gọi món `_AddItemsSheet` trong widget `PopScope` với thuộc tính `canPop: !_isConfirming` để chặn vuốt xuống hoặc chạm ra ngoài khi đang lưu database, triệt tiêu hoàn toàn race condition.

3. **Hot Restart**:
   * Đã gửi tín hiệu Hot Restart thành công trên cả 2 thiết bị mô phỏng để cập nhật và chạy thử nghiệm luồng mã nguồn mới nhất.

### Files đã sửa
| File | Thay đổi |
|------|----------|
| `lib/core/repositories/ban_repository.dart` | Thay đổi truy vấn existingRows thành lấy allRows và lọc trong bộ nhớ Dart để nhận diện toàn bộ các dòng null/chua_gui/pending. |
| `lib/screens/ban_screen.dart` | Bao bọc Bottom Sheet `_AddItemsSheet` bằng widget `PopScope` với `canPop: !_isConfirming`. |

### Tiếp theo
- ➡️ Nhận phản hồi thực tế từ người dùng khi thao tác gọi món.
- ➡️ Theo dõi các hoạt động lưu trữ hóa đơn khác để đảm bảo tính đồng bộ của database.

---

## 2026-06-14 — Cấu Hình Tài Khoản Google Play Review & Đăng Nhập Offline

### Đã làm
- ✅ **Bypass đăng nhập offline cho tài khoản Google Play Review**:
  - Hỗ trợ tài khoản kiểm duyệt của Google (`9999996666` / mật khẩu `112233`) tự động chuyển sang chế độ offline với một cửa hàng mẫu Demo cục bộ nếu thiết bị kiểm duyệt không kết nối được internet/DNS Supabase.
  - Sửa đổi trong [user_auth_service.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/user_auth_service.dart).
- ✅ **Khởi chạy máy ảo Pixel 7 (`Pixel7_API34`)**:
  - Khởi chạy thành công thiết bị ảo Pixel 7 thông qua lệnh `flutter emulators`.
- ✅ **Ghi nhận tài khoản kiểm thử (Test Account)**:
  - Tên: `test`
  - SĐT: `+8490112233`
  - Mật khẩu: `112233`

### Files đã sửa
| File | Thay đổi |
|------|----------|
| `lib/core/services/user_auth_service.dart` | Bổ sung logic bypass local login khi thông tin đăng nhập khớp với tài khoản demo Google Play Review. |
| `.docs/nhat-ky.md` | Ghi nhận tài khoản kiểm thử và nhật ký cập nhật hôm nay. |

---

## 2026-06-20 & 2026-06-21 — Đóng Gói Windows & Phân Trạm In Bếp

### Đã làm
- ✅ **Đóng gói Windows & Cấu hình C++ Runtime**:
  - Sửa lỗi cú pháp trong `installer.iss` và workflows của GitHub Actions.
  - Tích hợp tự động tải và cài đặt ngầm Microsoft VC++ Redistributable (`vc_redist.x64.exe`) khi cài đặt trên Windows.
  - Merge khôi phục thành công giao diện Tablet Sidebar UI.
- ✅ **Phân chia và điều hướng in cho từng bếp**:
  - Cập nhật Giao diện Sửa/Thêm sản phẩm cho phép cấu hình "Bộ phận chế biến": **Bếp Nóng** (`bep_nong`), **Bếp Bar** (`bep_bar`), và **Thu Ngân** (`thu_ngan`).
  - Lưu trữ cấu hình máy in trạm riêng biệt cho từng vai trò (Thu ngân, Bếp nóng, Bếp bar, Tem dán ly) qua SharedPreferences.
  - Hỗ trợ 2 kiểu kết nối máy in: **Máy in Hệ thống** (OS Printer) và **Mạng IP LAN/Wifi**.
  - Tự động tách đơn hàng gốc thành các phiếu in riêng biệt và đẩy thẳng tới máy in tương ứng khi thanh toán thành công hoặc in thủ công.
  - Xây dựng template in tem dán ly (Bar Label) kích thước nhỏ `50x30mm` (in lẻ từng ly) phục vụ đóng cốc quầy Bar.

### Files đã sửa
| File | Thay đổi |
|------|----------|
| `lib/screens/inventory_screen.dart` | Thêm selector chọn trạm chế biến (`stationCode`) cho sản phẩm. |
| `lib/modules/kho/repository/kho_repository.dart` | Thêm `stationCode` vào model `StockItem`. |
| `lib/modules/pos/repository/pos_repository.dart` | Thêm `stationCode` vào model `CartLine`. |
| `lib/modules/pos/providers/pos_providers.dart` | Gán `stationCode` khi tạo `CartLine`. |
| `lib/modules/bill_printer/screens/bill_preview_screen.dart` | Thêm logic tạo tem dán ly `generateBarLabels` và bộ điều phối in `StationPrinterDispatcher.printBill`. |
| `lib/modules/pos/screens/checkout_sheet.dart` | Tự động in phân trạm khi thanh toán thành công và in trực tiếp khi bấm nút thủ công. |
| `lib/modules/bill_printer/providers/printer_settings_provider.dart` | [NEW] Provider lưu trữ cấu hình máy in trạm và quét máy in hệ thống. |
| `lib/modules/bill_printer/screens/bill_printer_hub.dart` | Thêm card và sheet giao diện cấu hình máy in trạm, in thử nghiệm. |
| `windows/installer.iss` | Cấu hình cài đặt C++ Runtime và cập nhật đường dẫn đầu ra. |
| `.github/workflows/windows-release.yml` | Cập nhật đường dẫn lưu trữ đầu ra build Windows. |

### Tiếp theo
- ✅ Bàn giao cho người dùng Push mã nguồn sạch lên GitHub.
- ✅ Chạy build bản phát hành Windows trên GitHub Actions và tải bản cài đặt mới về trải nghiệm.

---

## 2026-06-22 — Thiết Kế Lại Giao Diện In Bill Responsive & Tự Động Cập Nhật

### Đã làm
- ✅ **Thiết kế lại giao diện cấu hình in ấn thích ứng (Responsive)**:
  - Chuyển đổi hộp thoại cấu hình máy in cũ thành một màn hình độc lập [printer_settings_screen.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/bill_printer/screens/printer_settings_screen.dart).
  - Bố cục 2 cột trên Tablet/PC: cột trái hiển thị danh sách trạm in và các nút chức năng; cột phải hiển thị cấu hình chi tiết & Live Preview thời gian thực của hoá đơn/tem dán ly tương ứng giúp dễ dàng căn chỉnh.
  - Thiết lập các nút bấm và Switch điều hướng với chiều cao chuẩn tối thiểu `52px` tối ưu cho cảm ứng và bấm chuột.
- ✅ **Tự động dò tìm máy in IP trong mạng nội bộ (LAN Scan)**:
  - Tạo [network_printer_search_service.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/network_printer_search_service.dart) tự động nhận diện IP của máy và quét dải IP subnet song song trên cổng `9100`.
  - Tích hợp cơ chế Hard Timeout (400ms ở cấp độ Future) để tránh kẹt thanh tiến trình tại 99%.
- ✅ **Lối vào cấu hình & Tích hợp**:
  - Thêm mục **"Cài đặt máy in & Tem nhãn"** trực tiếp trên tab Cài đặt chính [settings_screen.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/screens/settings_screen.dart).
  - Cập nhật [bill_printer_hub.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/modules/bill_printer/screens/bill_printer_hub.dart) chuyển hướng đến màn hình cấu hình responsive mới.
- ✅ **Tự động cập nhật ứng dụng Windows (Auto-update)**:
  - Tạo [auto_update_service.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/services/auto_update_service.dart) tự động kiểm tra phiên bản mới từ GitHub Release API (`PaChiaBun/quannho-pos`).
  - Cho phép tải xuống và cài đặt ngầm file setup ghi đè phiên bản cũ cực kỳ an toàn, sau đó tự tắt ứng dụng để nâng cấp.
  - Tích hợp kiểm tra cập nhật khi ứng dụng khởi chạy (`initState` ở [dashboard_screen.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/screens/dashboard_screen.dart)) và thêm nút kiểm tra cập nhật thủ công trong màn hình Cài đặt.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `lib/core/services/network_printer_search_service.dart` | [NEW] Service dò tìm máy in IP trong mạng nội bộ port 9100 với hard timeout. |
| `lib/modules/bill_printer/screens/printer_settings_screen.dart` | [NEW] Màn hình cấu hình máy in độc lập và responsive cho Tablet/PC & Mobile. |
| `lib/core/services/auto_update_service.dart` | [NEW] Service kiểm tra phiên bản mới trên GitHub và tải về, cài đặt đè tự động. |
| `lib/screens/settings_screen.dart` | Thêm lối vào cài đặt in ấn và nút kiểm tra cập nhật thủ công. |
| `lib/screens/dashboard_screen.dart` | Thêm lời gọi tự động kiểm tra cập nhật khi ứng dụng khởi chạy thành công. |
| `lib/modules/bill_printer/screens/bill_printer_hub.dart` | Cập nhật chuyển hướng đến màn hình cấu hình responsive mới. |

### Tiếp theo
- ➡️ Đẩy mã nguồn sạch lên GitHub qua GitHub Desktop.
- ➡️ Chờ GitHub Actions build hoàn tất, chạy thử ứng dụng Windows để trải nghiệm tính năng in ấn mới và cơ chế tự động cập nhật.

---

## 2026-06-23 — Sửa Triệt Để Lỗi Nhân Đôi (x2) Món Module Bàn

### Đã làm
- ✅ **Khắc phục triệt để tranh chấp (race condition) gây x2 món**:
  - Viết file SQL Migration `/Users/banhbao/Quan Nho/quan_nho/.docs/sql_fix_x2_ban_items.sql` tạo hàm RPC `add_session_items` và Partial Unique Index nhằm khóa hàng (`FOR UPDATE`) và ngăn chặn trùng lặp ở tầng database.
  - Sửa đổi [ban_repository.dart](file:///Users/banhbao/Quan%20Nho/quan_nho/lib/core/repositories/ban_repository.dart) thực hiện gọi hàm RPC gộp món nguyên tử trên Supabase trước, nếu chưa chạy migration thì tự động fallback về luồng so khớp client-side cũ để đảm bảo tính liên tục của hệ thống.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `.docs/sql_fix_x2_ban_items.sql` | [NEW] Migration script tạo RPC `add_session_items` và partial unique index. |
| `lib/core/repositories/ban_repository.dart` | Tích hợp gọi RPC `add_session_items` với cơ chế fallback client-side. |

---

## 2026-07-06 — Thống Kê Số Bàn Theo Phục Vụ, Bộ Lọc Trạng Thái Bàn & Bảo Mật RLS

### Đã làm
- ✅ **Đếm số bàn phục vụ theo nhân viên (Tab Báo Cáo)**:
  - Thêm tệp SQL di cư [add_waiter_tracking.sql](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/add_waiter_tracking.sql) để bổ sung cột `waiter_id` (tham chiếu đến bảng nhân viên `staff_members`) vào bảng `ban_sessions` và `orders`.
  - Cập nhật `BanRepository` và logic checkout bàn tự động đọc thông tin đăng nhập từ bộ nhớ đệm `SharedPreferences` (`auth_user_id`) để gán chính xác `waiter_id` và `staff_id` cho phiên và hóa đơn.
  - Tinh chỉnh `DashboardRepository` và `report_screen.dart` hiển thị bảng xếp hạng số bàn phục vụ dạng thanh tiến trình màu tím trực quan, cân đối 3 cột trên màn hình rộng PC/Tablet.
- ✅ **Bộ lọc trạng thái bàn & Gỡ bỏ giới hạn số khách (Màn hình Bàn)**:
  - Thêm thanh lọc trạng thái (Tất cả bàn, Đang có khách 🔴, Bàn trống 🟢) giúp thu ngân dễ dàng kiểm soát các bàn ăn đang hoạt động.
  - Sửa đổi logic mở bàn cho phép cộng tăng số lượng khách không giới hạn (gỡ bỏ chặn giới hạn số ghế tiêu chuẩn của bàn), cập nhật nhãn phụ thành "Sức chứa tiêu chuẩn".
- ✅ **Nâng cấp bảo mật cách ly quán tuyệt đối (Row Level Security)**:
  - Tự động gắn động HTTP Header `x-store-id` tại `session_provider.dart` cho mọi truy vấn database dựa theo phiên đăng nhập hoạt động.
  - Viết tệp di cư SQL [apply_rls_policies.sql](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/apply_rls_policies.sql) tạo hàm SQL an toàn `public.current_store_id()` đọc Header và thiết lập chính sách RLS phân ngăn cách biệt vật lý tuyệt đối giữa các quán.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `supabase/add_waiter_tracking.sql` | [NEW] Script SQL thêm cột waiter_id và tạo index tối ưu hóa thống kê. |
| `supabase/apply_rls_policies.sql` | [NEW] Script SQL tạo hàm đọc header và thiết lập chính sách cách ly RLS cho các bảng chính. |
| `lib/core/repositories/dashboard_repository.dart` | Cấu trúc lại DashboardStats để thu thập và ánh xạ tên nhân viên phục vụ dựa theo số bàn. |
| `lib/core/repositories/ban_repository.dart` | Sửa logic lấy ID nhân viên từ bộ nhớ đệm SharedPreferences khi mở bàn. |
| `lib/screens/ban_screen.dart` | Sửa logic checkout để đồng bộ ID, tích hợp thanh lọc trạng thái bàn và gỡ bỏ giới hạn khách khi mở bàn. |
| `lib/screens/report_screen.dart` | Thiết kế giao diện báo cáo phục vụ theo nhân viên dạng cột responsive. |
| `lib/core/providers/session_provider.dart` | Tự động chèn/gỡ bỏ Header x-store-id động khi thay đổi trạng thái đăng nhập. |
| `.docs/qn.md` | Cập nhật tóm tắt công việc và hướng dẫn bảo mật mới. |

### Tiếp theo
- ➡️ Đẩy toàn bộ thay đổi mã nguồn lên GitHub.
- ➡️ Đóng gói bản dựng App mới để trải nghiệm đồng bộ trên mọi thiết bị.

---

## 2026-07-07 — Phân Tách Quỹ Tiền Mặt & Tiền Gửi (Chuẩn CUKCUK), Xuất Excel/CSV Kế Toán & Deploy VPS

### Đã làm
- ✅ **Phân Tách Quỹ Tiền Mặt & Tiền Gửi**:
  - Tạo tệp SQL di cư [add_fund_type_to_finance.sql](file:///Users/banhbao/Quan%20Nho/quan_nho/supabase/add_fund_type_to_finance.sql) thêm cột `fund_type` (`cash` hoặc `bank`) vào bảng `finance_records`.
  - Cập nhật model và `FinanceRepository` để hỗ trợ lọc và lấy thống kê độc lập theo quỹ.
  - Phân bổ dòng tiền tự động: Hóa đơn POS & Bàn (Tiền mặt $\rightarrow$ Quỹ `cash`, Chuyển khoản/Thẻ $\rightarrow$ Quỹ `bank`), Lương (mặc định Quỹ `bank`), Chi nhập kho (lưu theo quỹ thực tế, tự động hoàn trả đúng quỹ khi hủy đơn).
- ✅ **Nâng Cấp Giao Diện Thu Chi & Nhập Liệu**:
  - Thiết kế bộ lọc 3 Tab: **Tất cả**, **Tiền mặt**, và **Tiền gửi** để quản lý độc lập.
  - Tích hợp tự động định dạng phân tách hàng nghìn bằng dấu phẩy (ví dụ: `150,000`) trực tiếp khi nhập số tiền trong popup tạo phiếu.
- ✅ **Xuất Excel/CSV Kế Toán (Running Balance)**:
  - Tích hợp nút xuất báo cáo dòng tiền của từng quỹ dưới dạng CSV UTF-8 tương thích tốt với Excel/Google Sheets.
  - Tính năng tự động truy vấn tính **Số dư đầu kỳ** và hiển thị cột **Tồn quỹ chạy lũy kế** theo từng dòng giao dịch chuẩn nghiệp vụ kế toán.
- ✅ **Triển khai Web Lên VPS (`quannho.lpm.vn/pos`)**:
  - Build bản production Flutter Web với cấu hình con `/pos/`: `flutter build web --release --base-href "/pos/" --no-tree-shake-icons`.
  - Nén và upload code tĩnh lên VPS `45.32.104.228` tại thư mục `/var/www/quannho/pos`.
  - Cấu hình lại Nginx `/etc/nginx/sites-available/lpm.vn` để tách biệt định tuyến SSL subdomain `quannho.lpm.vn`, trỏ riêng biệt thư mục `/pos` hỗ trợ SPA (Single Page Application) reload mà không bị lỗi 404.
- ✅ **Khắc Phục & Tối Ưu In Ấn & Đồng Bộ Cấu Hình**:
  - **Khung Báo Cáo:** Loại bỏ `ConstrainedBox(maxWidth: 1200)` trong `report_screen.dart` giúp trang Báo Cáo co giãn 100% chiều rộng màn hình PC/Tablet.
  - **Phân tách In Ấn:** Tách lệnh in bill POS và bàn (Chỉ in hóa đơn thu ngân `onlyReceipt: true`), tự động in hóa đơn khi thanh toán Bàn (nếu bật cấu hình) và phân loại in bếp/bar chính xác dựa theo cấu hình thiết lập.
  - **Môi trường Web Browser:** Chuyển hướng toàn bộ cuộc gọi in trên Flutter Web (`kIsWeb`) sang hộp thoại in mặc định của Trình duyệt (`layoutPdf`) để tránh lỗi do sandbox trình duyệt chặn cổng máy in.
  - **Đồng bộ Đám mây (Cloud Sync):** Nâng cấp `printer_settings_provider.dart`, `bill_block_template.dart`, `kitchen_ticket_template_provider.dart` để tự động đồng bộ (lưu/tải) mọi cấu hình máy in và thiết kế mẫu hóa đơn, mẫu bếp lên bảng `app_settings` của Supabase, giúp đồng bộ hóa tức thì giữa App Windows và Web.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `supabase/add_fund_type_to_finance.sql` | [NEW] SQL di cư thêm cột fund_type và backfill hóa đơn chuyển khoản cũ. |
| `lib/modules/finance/repository/finance_repository.dart` | Cập nhật CRUD và hàm query watchRecords, getStats hỗ trợ fund_type. |
| `lib/modules/finance/providers/finance_providers.dart` | Cập nhật selectedFundProvider mặc định là 'all' và tối ưu hóa reactive streams. |
| `lib/screens/finance_screen.dart` | Thiết kế lại 3 Tab lọc quỹ, tích h�- ✅ **Khắc phục lỗi Module Nhân Viên & Tự Động Tạo Tài Khoản Nhân Viên**:
  - Sửa hàm `StaffService.getStaffList` ưu tiên tra cứu trực tiếp từ bảng chuẩn `staff_members`.
  - Khởi tạo 5 vai trò mặc định (`owner`, `Quản Lý`, `Thu ngân`, `Phục Vụ`, `Barista`) vào bảng `store_roles`.
  - Cập nhật `StaffService.addStaffByPhone` và form `_AddStaffSheet` cho phép Quản lý nhập **Họ tên + SĐT + Vai trò** để tự động khởi tạo nhân viên mới trực tiếp vào `staff_members`, `user_accounts`, và `store_members` mà không bắt nhân viên phải tự mở app tạo tài khoản trước.
- ✅ **Khởi tạo Bảng Khuyến Mãi & Hủy Bill (`coupons`, `void_audit_logs`)**:
  - Tạo bảng `public.coupons` và `public.void_audit_logs` trên Supabase PostgreSQL. Chèn voucher mẫu `KHAI_TRUONG` (Giảm 10%). Kiểm tra API REST qua HTTPS đạt HTTP/2 200 OK.
iders/kitchen_ticket_template_provider.dart` | Bổ sung cơ chế Cloud Sync cấu hình và mẫu thiết kế lên Supabase app_settings. |
| `web/index.html` | Cập nhật placeholder `$FLUTTER_BASE_HREF` hỗ trợ build subfolder. |
| `.docs/qn.md` | Cập nhật hướng dẫn tính năng phân tách quỹ và deploy VPS. |

### Tiếp theo
- ➡️ Bàn giao tài liệu hướng dẫn nghiệm thu và link kiểm thử live cho chủ quán.
- ➡️ Chuẩn bị nâng cấp các tính năng quản lý chuỗi nếu chủ quán có yêu cầu thêm.

---

## 2026-07-14 — Sửa Lỗi Phân Quyền Thu Ngân & Tối Ưu Hóa Giao Diện Điện Thoại (Mobile)

### Đã làm
- ✅ **Sửa lỗi Phân quyền & Khóa thanh toán (Thu ngân)**:
  - Khắc phục triệt để lỗi đọc đồng bộ `ref.read(userActionPermsProvider).value` bị trả về `null` lúc khởi động trong `ban_screen.dart` bằng cách sử dụng `await ref.read(userActionPermsProvider.future)` bất đồng bộ và thêm `ref.watch(userActionPermsProvider)` để tải quyền sớm.
  - Tích hợp cơ chế **tự động di cư quyền (Auto-Migration)** trong `StaffService.getActionPermissions`: Tự động cấp quyền thanh toán `pos.checkout` cho vai trò `Thu ngân` nếu phát hiện bị thiếu trên database Supabase cũ, sau đó đồng bộ ngược lên Cloud.
- ✅ **Tối ưu hóa Giao diện Điện thoại (Mobile Overflow Fixes)**:
  - **Module Grid (Trang chủ)**: Sửa lỗi sọc vàng đen tràn viền dọc bằng cách đổi `childAspectRatio` từ `1.35` thành `1.15` trên Mobile và giảm padding/cỡ chữ/icon của `ModuleTile` một cách thông minh khi màn hình dọc nhỏ hơn `450px`.
  - **Bộ lọc Log (Nhật ký hoạt động)**: Tách hàng lọc `Row` thành dạng xếp chồng dọc `Column` trên Mobile và dạng hàng ngang trên Tablet/PC, tránh sọc vàng đen tràn màn hình.
  - **Sơ đồ bàn & Chip bộ lọc (`ban_screen.dart`)**: Cho phép cuộn ngang `SingleChildScrollView` cho thanh lọc/toggle size bàn trên Mobile. Đồng thời, kéo dài thẻ bàn bằng cách giảm `childAspectRatio` trên Mobile (`nho: 0.9`, `vua: 0.96`, `to: 1.0`) để hiển thị đầy đủ thông tin món ăn và số tiền khi bàn có khách mà không bị tràn chữ.
- ✅ **Sửa lỗi SQL PostgrestException (Báo cáo)**:
  - Khắc phục lỗi ambiguity (PGRST201) khi query `orders` kết hợp `staff_members` do bảng orders hiện có 2 khóa ngoại (`staff_id` và `waiter_id`) trỏ sang `staff_members`. Sửa câu select thành `staff_members!orders_staff_id_fkey(name)` trong `report_screen.dart`.
- ✅ **Deploy Web lên VPS**:
  - Build bản production Flutter Web (`/pos/`) và upload đồng bộ đè lên VPS (`45.32.104.228`) tại thư mục `/var/www/quannho/pos`.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `lib/core/services/staff_service.dart` | Thêm logic auto-migration cấp quyền `pos.checkout` cho vai trò `cashier`. |
| `lib/screens/ban_screen.dart` | Sửa cơ chế đọc quyền `userActionPermsProvider` sang bất đồng bộ hoàn toàn (`await ... .future`), watch chủ động ở build, cuộn ngang thanh bộ lọc và điều chỉnh `childAspectRatio` linh hoạt trên Mobile. |
| `lib/screens/dashboard_screen.dart` | Điều chỉnh `childAspectRatio` module grid khi hiển thị 2 cột trên Mobile. |
| `lib/shared/widgets/module_tile.dart` | Bổ sung logic `Builder` tự động thích ứng kích thước icon, padding, cỡ chữ của module tile theo chiều rộng màn hình Mobile. |
| `lib/screens/log_viewer_screen.dart` | Thiết kế giao diện bộ lọc log responsive xếp chồng Column trên Mobile và Row trên PC/Tablet. |
| `lib/screens/report_screen.dart` | Khắc phục lỗi SQL bằng cách chỉ định rõ ràng khóa ngoại liên kết `staff_members!orders_staff_id_fkey` khi select. |
| `nhật ký.md` | Cập nhật nhật ký thay đổi vĩ mô ở thư mục gốc. |
| `nhat_ky.md` | Cập nhật bản sao nhật ký thay đổi vĩ mô. |
| `.docs/nhat-ky.md` | Cập nhật nhật ký tiến độ chi tiết. |

### Tiếp theo
- ➡️ Bàn giao mã nguồn sạch và đóng gói bản Windows mới để cập nhật hoàn chỉnh cho máy Thu ngân.
- ➡️ Theo dõi các phản hồi vận hành thực tế tại quán.

---

## 2026-07-14 — Ẩn Doanh Thu Nhân Viên, Hiện Tên Quán Thực Tế & Mở Khóa Cài Đặt Không Cần Chấm Công

### Đã làm
- ✅ **Ẩn Doanh Thu Hôm Nay Cho Nhân Viên**:
  - Ẩn hoàn toàn bảng doanh thu hôm nay, số đơn và khách hàng đối với các vai trò nhân sự thông thường (không phải chủ quán hay quản lý). Thay thế bằng lời chúc ngày làm việc vui vẻ thân thiện.
- ✅ **Hiển Thị Tên Quán Thực Tế**:
  - Cập nhật ô hiển thị loại quán ("Quán ăn" hoặc text tĩnh "Quán Nhỏ · POS") để lấy chính xác tên quán thực tế đã thiết lập thông qua `shopNameProvider` cho cả chủ quán và nhân viên.
- ✅ **Mở Khóa Tab Cài Đặt (Settings)**:
  - Cho phép nhân viên truy cập thẳng vào tab Cài đặt (index `6`) để xem/cài đặt thiết bị mà không bị chặn bởi màn hình yêu cầu chấm công (`_buildClockInRequiredScreen`).
- ✅ **Đồng Bộ & Deploy**:
  - Build bản production Flutter Web và upload thành công lên VPS `45.32.104.228`.
  - Thực hiện Hot Reload / Hot Restart đồng bộ trên cả 2 máy giả lập Pixel 6 và Pixel 7.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `lib/screens/dashboard_screen.dart` | Cập nhật bộ lọc ẩn doanh thu nhân viên, nạp `shopNameProvider` để hiển thị tên quán thực tế của thẻ shop. |
| `lib/main.dart` | Thêm ngoại lệ tab Cài đặt (index `6`) khỏi bộ lọc Clock-in bắt buộc. |
| `nhat_ky.md` | Ghi chép tiến độ ngày hôm nay. |

---

## 2026-07-22 — Tối Ưu Hóa Hiệu Năng Truy Vấn, Sửa Lỗi Giao Diện Co Giãn & Dọn Rác Nhật Ký Log

### Đã làm
- ✅ **Cải Tiến Module Thu Chi (`finance_screen.dart`)**:
  - Chuyển layout trang Thu Chi sang dạng cuộn trượt đồng bộ `SingleChildScrollView` kết hợp `shrinkWrap: true` và `NeverScrollableScrollPhysics` cho `ListView.builder`, khắc phục lỗi màn hình trắng và bỏ thanh ghim cố định gây khuất tầm nhìn trên điện thoại.
  - Tích hợp Bottom Sheet chọn thời gian linh hoạt: Hôm nay, Hôm qua, 7 ngày qua, 30 ngày qua, Tháng này, Tuỳ chọn ngày (Custom Date Range Picker) khi bấm nút "Đổi ngày" hoặc banner thời gian.
- ✅ **Tối Ưu Hóa & Sửa Lỗi Module Báo Cáo (`report_screen.dart`)**:
  - **Biểu đồ Doanh Thu Theo Giờ**: Mở rộng trục Y lên 68px và căn phải `TextAlign.end`, khắc phục triệt để lỗi bị mất chữ/cắt số tiền lớn (như `500.000 Đ`). Tự động ẩn các khung giờ từ 0h đến 6h sáng khi không có doanh thu (`revenue == 0`).
  - **Tối ưu tốc độ tải Tab Sản Phẩm**: Chuyển các truy vấn Supabase sang chạy song song bằng `Future.wait`, chia nhỏ danh sách `order_id` thành các lô 100 ID (`Batching chunks of 100`) tránh lỗi Postgrest URI quá dài và giảm 90% thời gian chờ tải. Tích hợp cache danh mục giúp chuyển tab danh mục sản phẩm tức thì.
  - **Tab Voucher**: Bổ sung thanh điều hướng thời gian ngày/tuần/tháng (`_ReportNavBar.day`, `.week`, `.month`) và bộ chọn ngày quá khứ bất kỳ đồng bộ với các tab Báo cáo khác.
- ✅ **Nâng Cấp & Xóa Rác Module Nhật Ký Hoạt Động (`log_viewer_screen.dart` & `printer_settings_provider.dart`)**:
  - **Cuộn trượt đồng bộ**: Đổi layout sang `SingleChildScrollView` giúp cuộn trôi khung bộ lọc 6 ô lên trên khi lướt xem danh sách log trên điện thoại. Tự động tải nhật ký ngay khi mở màn hình (`auto-fetch`).
  - **Tắt log quét ngầm định kỳ**: Loại bỏ hoàn toàn các câu lệnh `writePrintLog('[Polling Orders]')` và `writePrintLog('[Polling Tickets]')` chạy ngầm 2s/lần làm rác database Supabase. Tích hợp bộ lọc 2 lớp tại logger và màn hình hiển thị.
  - **Xóa log khối lượng lớn an toàn**: Đổi cơ chế xóa sạch log `_clearLogs` sang xóa theo từng lô 500 bản ghi (`batch delete chunks of 500`), khắc phục triệt đẻ lỗi `PostgrestException statement_timeout (57014)`.
- ✅ **Triển Khai Web Lên VPS (`quannho.lpm.vn/pos`)**:
  - Build bản Flutter Web release với cấu hình base href `/pos/`.
  - Đồng bộ và upload code tĩnh lên VPS `45.32.104.228` tại thư mục `/var/www/quannho/pos`.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `lib/screens/finance_screen.dart` | Chuyển layout sang cuộn trượt đồng bộ, tích hợp Bottom Sheet chọn khoảng thời gian đa dạng. |
| `lib/modules/finance/repository/finance_repository.dart` & `finance_providers.dart` | Thêm static constructors cho `DateRange` và method tương ứng trong `PeriodNotifier`. |
| `lib/screens/report_screen.dart` | Mở rộng trục Y & ẩn giờ 0h-6h rỗng trên biểu đồ doanh thu; bổ sung thanh điều hướng thời gian cho Tab Voucher; tối ưu hóa truy vấn song song batching 100 ID cho Tab Sản phẩm. |
| `lib/core/repositories/dashboard_repository.dart` | Batching `order_ids` theo lô 100 ID song song trong `getTopProductsForRange` và `getProductCategoriesSold`. |
| `lib/screens/log_viewer_screen.dart` | Layout cuộn trượt đồng bộ, auto-fetch log, xóa log khối lượng lớn theo lô 500 bản ghi và bổ sung bộ lọc ẩn log polling rác. |
| `lib/modules/bill_printer/providers/printer_settings_provider.dart` | Bỏ ghi log định kỳ `[Polling Orders]` / `[Polling Tickets]` mỗi 2s và chặn log polling rác tại `writePrintLog`. |
| `nhat_ky.md` | Cập nhật nhật ký phát triển ngày 2026-07-22. |

---

## 2026-07-23 — Triển Khai Self-Hosted Supabase, Nginx SSL Dedicated Subdomain, Khắc Phục Lỗi Báo Cáo Nhân Viên & Audit Dữ Liệu

### Đã làm
- ✅ **Chuyển Đổi Hạ Tầng Self-Hosted Supabase & Tên Miền Riêng**:
  - Cấu hình Nginx SSL Dedicated Subdomain **`https://quannho-db.lpm.vn`** proxy thẳng tới Supabase Studio container (`http://127.0.0.1:3003`), giải quyết triệt để vấn đề dùng IP thô thiếu chuyên nghiệp.
  - Cấu hình Nginx Proxy ưu tiên **`location ^~ /supabase/`** chuyển hướng trực tiếp API REST sang Kong API Gateway (`http://127.0.0.1:8000/`), đảm bảo toàn bộ request HTTPS API từ POS Web trả về `HTTP/2 200 OK`.
- ✅ **Khắc Phục Lỗi Báo Cáo "Nhân Viên Ẩn"**:
  - Chuyển đổi toàn bộ logic tra cứu nhân viên trong `DashboardRepository`, `ReportScreen`, `PosRepository` và `BanRepository` từ tên bảng cũ `store_members` sang bảng chuẩn **`public.staff_members`** (`id`, `name`, `role`).
  - Hiển thị đầy đủ 100% tên nhân viên thực tế (*Phan Thị Thuỳ Dung, Tô Vũ Yên Khuê, GIANG, Nguyễn Hữu Phúc...*) trong báo cáo thu ngân và số bàn phục vụ.
- ✅ **Bổ Sung Bảng Nhật Ký Hoạt Động (`app_logs`)**:
  - Khởi tạo bảng **`public.app_logs`** trên PostgreSQL kèm phân quyền RLS `app_logs_all` và thực hiện `NOTIFY pgrst, 'reload schema'`. Sửa dứt điểm lỗi thông báo banner màu đỏ `Could not find the table 'public.app_logs'` ở màn hình POS.
- ✅ **Dọn Dẹp Dữ Liệu Thử Nghiệm & Audit Chất Lượng Sâu (10/10 An Toàn)**:
  - Xóa 100% dữ liệu test rác trong giai đoạn thử nghiệm (từ `06/07/2026` đến `12/07/2026`): 88 đơn hàng, 88 lượt bàn, 65 phiếu bếp, 116 thu chi, 255 thẻ kho theo đúng quy trình Foreign Key CASCADE (`kitchen_tickets` $\rightarrow$ `ban_sessions` $\rightarrow$ `orders` $\rightarrow$ `finance_records` $\rightarrow$ `stock_movements`).
  - Chạy kịch bản QC Audit toàn diện 10 tiêu chí: 0 món ăn mồ côi, 0 hóa đơn mồ côi, 0 đơn thiếu `store_id`. Bảo vệ nguyên vẹn 100% hơn 730 đơn hàng thực tế từ `13/07/2026` trở đi.
- ✅ **Biên Dịch & Deploy Bản Web POS Mới Lên VPS**:
  - Build bản Flutter Web release với `--base-href "/pos/"` và deploy trực tiếp lên `/var/www/quannho/pos` trên VPS `45.32.104.228`.
- ✅ **Cập Nhật Tài Liệu Dự Án**:
  - Ghi chép chi tiết cấu trúc dữ liệu, đường tuyến gateway và quy chuẩn tra cứu nhân viên vào `qn.md`, `.docs/qn.md` và `nhat_ky.md`.

### Files đã sửa/tạo mới
| File | Thay đổi |
|------|----------|
| `lib/core/repositories/dashboard_repository.dart` | Refactor truy vấn tra cứu nhân viên từ `store_members` sang `staff_members` (`id, name`). |
| `lib/screens/report_screen.dart` | Refactor truy vấn danh sách nhân viên từ `store_members` sang `staff_members`. |
| `lib/modules/pos/repository/pos_repository.dart` | Cập nhật tra cứu ưu tiên `staff_members` trực tiếp khi tạo đơn hàng. |
| `lib/core/repositories/ban_repository.dart` | Cập nhật tra cứu ưu tiên `staff_members` trực tiếp khi mở phiên bàn. |
| `/etc/nginx/sites-available/lpm.vn` (VPS) | Thêm quy tắc proxy ưu tiên `location ^~ /supabase/` tới Kong Gateway (port 8000). |
| `/etc/nginx/sites-available/quannho-db` (VPS) | Tạo server block Nginx Dedicated Domain cho `quannho-db.lpm.vn` (port 3003 Studio). |
| `qn.md` & `.docs/qn.md` | Thêm mục 4 & 12 về hạ tầng Self-Hosted Supabase, cấu trúc `staff_members`, `app_logs` và quy trình Audit Dữ liệu. |
| `nhat_ky.md` | Cập nhật nhật ký phát triển ngày 2026-07-23. |





