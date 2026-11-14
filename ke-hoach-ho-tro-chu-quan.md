# Thiết kế phần HỖ TRỢ chủ quán (mật khẩu, PIN, tài khoản nhân viên) — 26/10/2026

> Trạng thái: **H1 + H2 ĐÃ ÁP (26/10 03:01)**; **H3 ĐÃ ÁP (26/10 04:45)** — chủ quán đặt mật khẩu nhân viên đã từng đăng nhập vào quán.
> Ban đầu: Chủ Quán yêu cầu: hỗ trợ chủ quán đổi mật khẩu, đổi mật khẩu nhân viên…
> **Đã chốt 26/10:** chỉ **Chủ quán** đặt lại mật khẩu nhân viên · Chủ quán **tự gõ mật khẩu mới** cho nhân viên (không dùng mật khẩu tạm ở phần app) · xác minh hotline **3 bước** · làm **H1 + H2 ngay**, H3 (app) chờ phiên vá bảo mật.
> Quản trị hỗ trợ chủ quán quên mật khẩu (H2): `/admin` tạo **mật khẩu tạm** (hiện 1 lần, đọc qua điện thoại) → chủ quán đăng nhập rồi tự đổi trong Cài đặt → Đổi mật khẩu (đã có sẵn) — không cần sửa app.
> Phát hiện thêm: kho ảnh `bug-screenshots` cũng không tồn tại → ảnh đính kèm phản hồi mất; H1 làm phần chữ trước, kho ảnh để đợt sau (mở kho cho mọi người tải lên dễ bị lạm dụng).
> Giới hạn có sẵn: đổi mật khẩu chỉ thu hồi vé làm mới (refresh token); vé đang dùng (access token) sống tới 30 ngày → máy cũ chưa bị đá ngay. Không làm nút "Đăng xuất mọi máy" ở H2 vì không có tác dụng thật — xem lại khi làm thời hạn vé ngắn hơn.

## 1. Hiện trạng (đã kiểm production, chỉ đọc)

| Việc | Hiện nay | Vấn đề |
|---|---|---|
| Tự đổi mật khẩu của mình | Có (`change_user_password_v4`, cần mật khẩu cũ) | Quên mật khẩu cũ thì không đổi được |
| Đặt lại mật khẩu cho nhân viên | **Không có** — nhưng màn "Khôi phục / Quên mật khẩu" lại hướng dẫn *"Chủ quán vào Nhân viên → bấm Đặt lại mật khẩu"* | **App hứa tính năng không tồn tại** |
| Hotline hỗ trợ cấp lại mật khẩu | App ghi "kỹ thuật viên xác minh và khôi phục" | Quản trị **không có công cụ** nào để làm việc này |
| "Gửi phản hồi" (kèm yêu cầu cấp lại mật khẩu) | App ghi vào bảng `bug_reports` | **Bảng không tồn tại trên production → mọi phản hồi mất âm thầm** |
| PIN nhanh (`quick_pin`) | 7 / 246 tài khoản đặt | Quên PIN thì chưa có cách xoá |
| Mật khẩu lưu dạng băm | 215 tài khoản bcrypt, **31 tài khoản kiểu cũ** | Nên chuyển dần sang bcrypt khi đặt lại |
| Đổi mật khẩu → đá các máy đang đăng nhập | Có (trigger `qn_trg_revoke_refresh_on_password_change`) | Tốt — dùng lại |

Tài khoản nhân viên dùng chung bảng `user_accounts` (đăng nhập bằng SĐT + mật khẩu) như chủ quán. 3 tài khoản thuộc nhiều quán.

## 2. Mục tiêu

1. **Chủ quán tự lo được cho nhân viên** ngay trong app: đặt lại mật khẩu, xoá PIN nhanh, đăng xuất nhân viên khỏi mọi máy — không phải gọi hỗ trợ.
2. **Quản trị (`/admin`) hỗ trợ chủ quán** khi chính chủ quán quên mật khẩu / mất máy: tra tài khoản, cấp mật khẩu tạm, đăng xuất mọi máy — có quy trình xác minh và nhật ký.
3. **Nhận được yêu cầu hỗ trợ**: sửa "Gửi phản hồi" để yêu cầu về được `/admin`.
4. Sửa câu hướng dẫn trong app cho đúng thực tế.

## 3. Nguyên tắc an toàn (bắt buộc)

- **Không ai nhìn thấy hay gõ hộ mật khẩu người khác.** Đặt lại = máy chủ **tự tạo mật khẩu tạm** (8 ký tự dễ đọc, vd `K7M-Q4XP`) → hiện **một lần duy nhất** cho người bấm để đọc / gửi Zalo cho người cần → người đó **bắt buộc đổi mật khẩu mới ngay lần đăng nhập đầu**. Mật khẩu tạm hết hạn sau 24 giờ.
- Đặt lại xong → **đá mọi máy** đang đăng nhập tài khoản đó (dùng trigger sẵn có).
- Mọi thao tác ghi **nhật ký** (ai làm, cho tài khoản nào, lúc nào, lý do) — xem được trên `/admin` (và chủ quán xem được phần của quán mình).
- **Phạm vi:** chủ quán chỉ đặt lại được tài khoản mà **toàn bộ** quán của người đó đều do mình làm chủ (tránh chủ quán A đổi mật khẩu của người cũng làm ở quán B). Không đặt lại được chủ quán khác. Trường hợp vướng → nhờ quản trị.
- Giới hạn số lần (vd 10 lần đặt lại / giờ / quán) chống bấm phá.
- Quản trị đặt lại mật khẩu **chủ quán** phải qua **checklist xác minh** (mục 5).

## 4. Phần chủ quán làm trong app (màn Nhân viên)

Trong thẻ từng nhân viên (chỉ Chủ quán; Quản lý tuỳ quyết định mục 8):

| Nút | Làm gì |
|---|---|
| **Đặt lại mật khẩu** | Hỏi xác nhận → máy chủ tạo mật khẩu tạm → hiện 1 lần + nút sao chép / gửi Zalo → nhân viên đăng nhập bằng mật khẩu tạm, app bắt đặt mật khẩu mới |
| **Xoá PIN nhanh** | Nhân viên quên PIN nhanh → xoá để tự đặt lại |
| **Đăng xuất khỏi mọi máy** | Nhân viên nghỉ việc / mất máy → thu hồi mọi phiên đăng nhập của người đó *tại quán này* |

Ghi chú: thu hồi phiên chỉ áp quán của mình; đổi mật khẩu thì áp toàn tài khoản (nên mới cần điều kiện "mọi quán của người đó đều thuộc mình").

## 5. Phần quản trị trên `/admin` — tab mới **"Hỗ trợ"**

1. **Tra tài khoản theo SĐT hoặc tên:** tên, SĐT, ngày tạo, các quán đang thuộc + vai trò, lần đăng nhập gần nhất, có PIN nhanh không, kiểu mật khẩu (bcrypt / cũ).
2. **Cấp mật khẩu tạm** (cho chủ quán hoặc bất kỳ tài khoản): hộp xác nhận kèm **checklist xác minh bắt buộc tick**:
   - Gọi lại đúng SĐT đăng ký (không gọi số khác người đó đưa).
   - Người gọi nói đúng tên quán + mã quán.
   - Hỏi thêm 1 điều chỉ chủ quán biết (vd món bán chạy / số nhân viên / đơn gần nhất — `/admin` hiện sẵn để đối chiếu).
   - Ô **lý do** bắt buộc.
3. **Xoá PIN nhanh**, **Đăng xuất mọi máy** (toàn tài khoản).
4. **Hàng "Yêu cầu hỗ trợ"**: phản hồi gửi từ app (loại *quên mật khẩu* / *báo lỗi* / *khác*), trạng thái mới / đang xử lý / xong, ghi chú xử lý. Bấm vào → mở thẳng tài khoản / quán liên quan.
5. **Nhật ký hỗ trợ**: mọi lần đặt lại / xoá PIN / đăng xuất do quản trị hoặc chủ quán làm.
6. Hồ sơ quán (đã có) thêm mục "Tài khoản" có nút hỗ trợ cho từng người.

## 6. Thay đổi máy chủ (migration mới)

| Thành phần | Nội dung |
|---|---|
| `user_accounts` thêm cột | `must_change_password boolean`, `temp_password_expires_at timestamptz` |
| bảng `support_requests` | thay cho `bug_reports` (đang thiếu): quán, người gửi, loại, nội dung, ảnh (tuỳ), trạng thái, ghi chú xử lý — khoá hẳn, chỉ hàm đọc / ghi |
| bảng `support_actions` | nhật ký hỗ trợ (người làm: quản trị / chủ quán, tài khoản bị tác động, loại, lý do, lúc) |
| Hàm chủ quán | `store_staff_reset_password_v1`, `store_staff_clear_quick_pin_v1`, `store_staff_sign_out_v1` (chỉ vé authenticated, kiểm phạm vi mục 3) |
| Hàm quản trị | `admin_account_search_v1`, `admin_account_detail_v1`, `admin_account_reset_password_v1`, `admin_account_clear_pin_v1`, `admin_account_sign_out_v1`, `admin_support_list_v1`, `admin_support_update_v1` |
| Đăng nhập | `verify_user_login_v4` / cổng đăng nhập trả thêm cờ `must_change_password`; mật khẩu tạm quá 24 giờ → từ chối, báo "mật khẩu tạm đã hết hạn" |
| Đổi mật khẩu bắt buộc | hàm `complete_password_change_v1(p_new)` — chỉ dùng được khi đang có cờ, không cần mật khẩu cũ (đã đăng nhập bằng mật khẩu tạm) |

## 7. Thay đổi app

- Màn **Nhân viên**: 3 nút ở mục 4 + hộp hiện mật khẩu tạm 1 lần (sao chép, chia sẻ).
- **Đăng nhập**: gặp cờ `must_change_password` → màn "Đặt mật khẩu mới" bắt buộc trước khi vào app.
- **Khôi phục / Quên mật khẩu**: sửa câu cho đúng (nút có thật; hotline dẫn về quy trình mục 5).
- **Gửi phản hồi**: ghi vào `support_requests` (sửa lỗi mất phản hồi), thêm chọn loại "Quên mật khẩu".

> ⚠️ Phần đăng nhập đụng các file mà **phiên "Vá 2 lỗ hổng bảo mật" đang sửa dở** (`session_provider.dart`, `user_auth_service.dart`, `pos_jwt_auth_service.dart`…). Làm phần app **sau khi phiên đó xong và được áp**, để không ghi đè nhau. Phần máy chủ + `/admin` làm trước được.

## 8. Chia đợt

| Đợt | Nội dung | Phụ thuộc |
|---|---|---|
| H1 | Sửa "Gửi phản hồi" (bảng `support_requests`) + hàng "Yêu cầu hỗ trợ" và tra tài khoản trên `/admin` (chỉ xem) | không — làm ngay được |
| H2 | Máy chủ: mật khẩu tạm + bắt đổi + xoá PIN + đăng xuất; `/admin` cấp mật khẩu tạm có checklist | không |
| H3 | App: nút cho chủ quán ở màn Nhân viên, màn bắt đổi mật khẩu khi đăng nhập, sửa câu hướng dẫn | **chờ phiên vá bảo mật xong** |

Mỗi đợt: test + QC độc lập + chạy thử trên bản sao database, hỏi Chủ Quán trước khi áp production.

## 9. Cần Chủ Quán chốt

1. **Quản lý** có được đặt lại mật khẩu nhân viên không, hay chỉ Chủ quán?
2. Mật khẩu tạm: **máy tự tạo + bắt đổi** (đề xuất) hay chủ quán tự gõ mật khẩu mới cho nhân viên?
3. Checklist xác minh khi chủ quán gọi hotline xin cấp lại mật khẩu — dùng đúng 3 bước mục 5 hay bổ sung?
4. Có cần cho **đổi SĐT đăng nhập** (chủ quán đổi số điện thoại) không? — rủi ro cao, đề xuất để đợt sau.
5. Có cần **chuyển quyền chủ quán** sang người khác (bán quán / đổi người quản lý)? — đề xuất để đợt sau.
