# Kế hoạch: /admin theo dõi tăng trưởng — Đợt 2

Ngày lập: 05/11/2026. Trạng thái: **DB + /admin ĐÃ ÁP production 05/11 07:28 VN (TS 20261105_072717). Web /pos và app CHƯA đưa nên chưa có số nhịp, lỗi văng, nguồn khách.** Q2, Q3 chưa chốt. Mọi bước đụng production đều hỏi trước.

## 1. Mục tiêu

Trả lời được 4 câu mà dữ liệu hiện có không trả lời được:

1. Bao nhiêu máy, bao nhiêu quán thật sự mở app mỗi ngày?
2. Máy đang chạy bản nào, nền tảng nào? Còn bao nhiêu máy kẹt bản cũ?
3. App có lỗi nhiều lên sau một bản phát hành không?
4. Quán mới biết Quán Nhỏ từ đâu?

## 2. Hiện trạng đã kiểm trong mã

| Điểm | Thực tế |
|---|---|
| `stores.last_active_at` | `StoreAuthService.pingActive()` ghi cột này nhưng **không nơi nào gọi**, nên không dùng được làm số hoạt động |
| Bảng `devices` | Trống (ghi nhận 26/10); /admin đếm máy qua `app_logs.device_id` |
| Mã máy trong log | `AppLogger.setDeviceId` chỉ được gọi ở `printer_settings_provider.dart:1951`, nên số máy phụ thuộc phần in |
| Lỗi không bắt được | `lib/` không có `FlutterError.onError` hay `PlatformDispatcher.onError`: lỗi văng không về máy chủ |
| Lỗi đã bắt | `AppLogger.error` ghi `app_logs`, /admin chỉ xem theo từng quán, không có số toàn hệ thống |
| Phiên bản | Chỉ có trong "Gửi phản hồi" (`bug_reports.app_version`); không biết phân bổ |
| Nguồn khách | Migration không có cột nguồn. Website đã có Google Analytics (`G-58PWFYJWG3`) nhưng chỉ đo lượt vào trang, không nối được tới quán tạo ra |
| Trang quyền riêng tư | `/privacy` đã nêu dữ liệu thiết bị và mã thiết bị |

## 3. Quyết định cần chốt

| # | Câu hỏi | Mặc định nếu không chốt khác |
|---|---|---|
| Q1 | Làm Đợt 2 ngay hay sau khi có tài khoản nhận tiền và gọi các quán đang bán? | **Sau.** Đợt 2 không làm tăng tiền thu; mốc 25/11 gấp hơn. Nhưng nên kịp ghép vào bản 1.0.7 |
| Q2 | Có hỏi "Biết Quán Nhỏ từ đâu?" khi tạo quán không? | **Có, một ô chọn không bắt buộc**, chỉ trên Web, Android, Windows (iOS không có tạo quán) |
| Q3 | Có ghép vào bản 1.0.7 đang chờ phát hành (chặn dòng bị đổi số ly) không? | **Có**, đỡ một vòng duyệt Apple |

## 4. Thay đổi

### 4.1 Nhịp app: một bảng, một hàm

Migration `20261107_admin_nhip_app_v1.sql` (+ `_ROLLBACK`):

- Bảng `app_device_days (day, store_id, device_id, platform, app_version, build, last_seen)`, khoá chính `(day, store_id, device_id)`. Khoá hẳn RLS, không ai đọc thẳng. Một bảng này cho ra cả số dùng mỗi ngày lẫn phân bổ phiên bản.
- Hàm `app_heartbeat_v1(p_store, p_device, p_platform, p_version, p_build)`: chỉ vé `authenticated`, kiểm `qn_is_member(p_store)`, nền tảng theo danh sách cho phép, giới hạn độ dài, ghi đè trong ngày. **Không lưu IP, tên, số điện thoại.**
- `shortcut:` chưa dọn dòng cũ (ước tính dưới 100.000 dòng/năm); khi quá 1 triệu dòng thì thêm lịch dọn.

App (`lib/core/services/`):

- Dùng lại mã máy đang đưa vào `AppLogger.setDeviceId`; lúc làm phải tách phần lấy mã khỏi provider máy in để gọi được ở mọi màn.
- Gọi lúc vào quán, khi app trở lại từ nền, và mỗi giờ (máy để mở nhiều ngày không có sự kiện trở lại); tự chống gửi trùng trong ngày. Hỏng thì 10 phút sau mới thử lại. **Lỗi mạng bỏ qua im lặng, không chặn gì.**
- Xoá `pingActive()` vì không ai gọi; sau khi kiểm không còn gì đọc `last_active_at` thì mới bỏ cột này khỏi danh sách quán.

### 4.2 Bắt lỗi văng

Trong `main()`: `FlutterError.onError` + `PlatformDispatcher.instance.onError` → `AppLogger.error('uncaught', …)`, vẫn gọi xử lý mặc định.

- Chống ngập: cùng một lỗi (bỏ qua phần số) tối đa 1 dòng/phút, tổng tối đa 30 dòng/phút trên mỗi máy, gửi theo lô.
- Che dữ liệu khách: bỏ truy vấn của URL, dòng dữ liệu của lỗi Postgres, dãy từ 9 chữ số. Mẫu lỗi trên /admin cũng che dãy số.
- Không dùng dịch vụ ngoài (Sentry, Crashlytics). `shortcut:` không bắt được lỗi native làm chết app và lỗi trước khi vào quán; khi cần thì mới cân nhắc.

### 4.3 Nguồn khách (nếu Q2 = có)

- Cột `stores.signup_source` + hàm riêng `store_signup_source_set_v1` (chỉ chủ quán, chỉ ghi lần đầu). **Không đổi `create_store_with_owner_v4`** vì đó là luồng tạo quán đang chạy.
- Ô chọn trong `create_store_sheet.dart`: Bạn bè giới thiệu / Facebook / Google / Nhân viên bán hàng / Khác. Bỏ qua được, lỗi không chặn tạo quán.

### 4.4 Trang /admin

Hàm chỉ đọc `admin_app_health_v1(p_include_test)`, chỉ `qn_admin`. Thêm khối **"Phiên bản và ổn định"** ở Tổng quan, không thêm tab vì thanh đáy điện thoại đã đủ 6 mục:

- Máy và quán mở app mỗi ngày, 30 ngày.
- Bảng nền tảng × phiên bản: số máy, số quán trong 7 ngày, đánh dấu bản mới nhất theo `app_versions`; nền tảng chưa có dòng (web) thì theo bản cao nhất đang chạy.
- **"Quán có đơn 7 ngày nhưng chưa báo nhịp"**: số này cho biết dữ liệu còn thiếu bao nhiêu, phải hiện rõ vì Android cũ không tự cập nhật.
- Lỗi 7 ngày so với 7 ngày trước, số quán gặp, 10 loại lỗi nhiều nhất, tách riêng `uncaught`.
- Quán mới theo nguồn, 90 ngày (nếu Q2 = có).

## 5. Không làm trong đợt này

- Đo từng màn, từng nút: chưa có câu hỏi nào cần và tốn dữ liệu.
- Bản tin Telegram, cảnh báo, SePay, phân quyền quản trị: Đợt 3.
- Tỷ lệ phiên không lỗi: cần số phiên, chưa cần.

## 6. Kiểm thử

**SQL** (`supabase/tests/admin_nhip_app_v1_test.sql`, cụm tạm **có đủ trigger production** như bài học Đợt 1):

- Khoá công khai bị chặn; vé người ngoài quán bị chặn; quán khoá bị chặn; thành viên ghi được.
- Gọi 2 lần trong ngày chỉ 1 dòng, đổi phiên bản thì cập nhật; qua ngày giờ Việt Nam thì thành dòng mới.
- Nền tảng lạ, chuỗi quá dài bị từ chối; người đăng nhập không đọc được bảng.
- Số máy, phân bổ phiên bản, "chưa báo nhịp", lỗi so kỳ trước đúng; quán thử bị loại.
- `signup_source`: chỉ chủ quán, không ghi đè, nhân viên bị chặn.
- Thử làm sai công thức để chắc test bắt được, như Đợt 1.

**Flutter:** gọi nhịp đúng lúc, lỗi mạng không ném lỗi, không gọi khi chưa vào quán; chống ngập lỗi; tạo quán vẫn xong khi ghi nguồn lỗi; ô chọn không hiện trên iOS.

**Máy thật hoặc máy ảo:** bản release (không cài bản profile lên máy quán), xem đúng 1 dòng nhịp, cố ý gây lỗi xem về `app_logs`, đo thời gian mở app không chậm đi.

**Trang:** 320 / 375 / 768 / 1440 px × sáng / tối; không có dữ liệu thì hiện đúng; lỗi riêng từng khối; Thoát xoá sạch.

**QC độc lập** trước khi áp.

## 7. Thứ tự làm

| Bước | Việc | Ai làm |
|---|---|---|
| 1 | Viết test, migration + rollback, kiểm trên cụm tạm | Claude |
| 2 | Sửa app, test Flutter, rà bài hướng dẫn theo `qn.md` nếu đổi màn tạo quán | Claude |
| 3 | Sửa trang + máy chủ giả, kiểm 4 kích thước | Claude |
| 4 | QC độc lập, sửa lỗi | Claude |
| 5 | Script áp DB + /admin, chạy trước khi phát hành để bảng sẵn sàng | **Chủ Quán duyệt** |
| 6 | Đưa web /pos (có số ngay) | **Chủ Quán duyệt** |
| 7 | Phát hành 1.0.7 Android, Windows, iOS | **Chủ Quán duyệt** |
| 8 | Cập nhật khai báo App Privacy (Apple) và Data safety (Google) nếu cần | Chủ Quán |
| 9 | Sau 7 ngày, đối chiếu "chưa báo nhịp" | Claude + Chủ Quán |

**Hoàn tác:** script trả trang cũ và gỡ bảng, hàm; app đã cài gọi hàm không còn thì lỗi bị bỏ qua im lặng.

## 8. Rủi ro

| Rủi ro | Cách giữ |
|---|---|
| Số thiếu trong thời gian đầu vì máy chưa cập nhật (Android bản 23 trở về trước phải cập nhật tay) | Hiện rõ "chưa báo nhịp"; không đọc số này như tổng người dùng |
| Lỗi bắt mới làm số lỗi tăng đột ngột sau phát hành | Tách riêng `uncaught`, ghi mốc phát hành trong nhật ký |
| Khai báo quyền riêng tư với cửa hàng ứng dụng | `/privacy` đã nêu mã thiết bị; Chủ Quán đối chiếu lại biểu mẫu trước khi gửi duyệt |
| Thư mục `quan_nho` có việc dở của phiên khác | Build từ worktree sạch, commit đúng tệp |
