# Kế hoạch: Module Tính giờ và đặt trước (bi da, phòng karaoke, sân)

Lập 23/11/2026. Chủ Quán duyệt 23/11. Trạng thái: **giai đoạn 1 ĐÃ ÁP lên máy chủ thật 23/11 14:34** (chưa commit). Giai đoạn 2 trở đi chưa làm. Xem mục 8.

## 1. Mục tiêu

Quán bi da, karaoke, sân thể thao dùng được Quán Nhỏ: mở bàn / phòng / sân là đồng hồ chạy, khách gọi đồ ăn uống như quán thường, lúc tính tiền hoá đơn có thêm dòng tiền giờ.

Ràng buộc đã chốt với Chủ Quán: tiền giờ là **một dòng trong hoá đơn**, **không sửa báo cáo**.

Chủ Quán chốt thêm 23/11: **một module chung** cho các ngành, **tên và biểu tượng đổi theo ngành**, và **có đặt sân / đặt bàn hẹn giờ trước**.

## 2. Quyết định chính: module riêng "Tính giờ", bật / tắt như mọi module, chạy trên nền module Bàn

Chủ Quán chốt 23/11: **tách thành module riêng**, vì module là thứ quán bật và tắt. Quán cà phê không bật thì không thấy gì liên quan đến tính giờ.

Module mới mã `tinh_gio`, mặc định TẮT, cần module Bàn đang bật. Khi bật:

- Trang chủ có ô "Tính giờ". Ô này mở màn Bàn (cùng sơ đồ, cùng phiên bàn).
- Trong sửa bàn / sửa khu vực mới hiện ô "Tính tiền giờ theo".
- Thẻ bàn có gắn giá giờ mới hiện đồng hồ.

Khi tắt: ba thứ trên ẩn hết. Bàn đang gắn giá giờ vẫn giữ cấu hình, bật lại là dùng tiếp. Không tắt được khi còn bàn tính giờ đang mở (đang có khách).

Phần "tách" là ở chỗ bật / tắt và phân quyền. Phần dữ liệu và thanh toán vẫn dùng chung với Bàn, vì một bàn bi da, một phòng hát, một sân đều là "một chỗ có khách đang dùng, có đồ gọi kèm, cuối cùng tính tiền một lần". Làm bảng và màn thanh toán riêng nghĩa là viết lại sơ đồ, gọi món, gửi bếp, chuyển bàn, thanh toán, in bill thêm một lần, và báo cáo phải sửa để đọc thêm nguồn thứ hai.

### Tên và biểu tượng theo ngành

Khi bật module, Chủ Quán chọn **loại hình**: Bi da, Karaoke, Cầu lông, Tennis, Pickleball, Bóng bàn, Khác. Một lần chọn đổi ba thứ:

- tên và biểu tượng của ô module ở Trang chủ (ví dụ ô "Bi da" thay cho "Tính giờ");
- cách gọi trong màn hình: "bàn" / "phòng" / "sân";
- biểu tượng mặc định trên thẻ bàn có tính giờ.

Quán có hai loại hình (bi da kèm phòng hát): chọn loại hình chính cho ô module, còn từng khu vực đã có sẵn ô chọn biểu tượng (`_kZoneIconCodes` trong `ban_screen.dart`), chỉ cần thêm các biểu tượng ngành vào danh sách đó.

Loại hình lưu thành một dòng trong `app_settings` (như danh sách module), không cần cột mới.

App đang vẽ biểu tượng bằng bộ Material có sẵn. Bộ này có vợt tennis và micro; hình bi da và cầu lông nhiều khả năng không có, phải kiểm khi làm. Thiếu hình nào thì vẽ thêm hình đó vào `assets/icons/`, cùng nét với bộ đang dùng.

Bản thân việc thêm một module **không cần cột mới** trong cơ sở dữ liệu: danh sách module đang bật của quán là một mảng mã nằm trong một dòng có sẵn (`app_settings`, khoá `module_config_v2`), quyền theo vai trò cũng là mảng mã (`store_roles.modules`). Ba cột mới ở giai đoạn 1 là để lưu giá giờ và giờ vào / giờ ra, làm cách nào cũng phải có.

## 3. Những gì đã kiểm (23/11, mã hiện tại và máy chủ thật, chỉ đọc)

| Điều đã kiểm | Kết quả | Hệ quả cho thiết kế |
|---|---|---|
| Thanh toán bàn (`settle_ban_session_v5`) lấy tổng tiền từ đâu | Cộng các dòng món của phiên bàn trên máy chủ, bỏ dòng đã huỷ | Chỉ cần chèn dòng tiền giờ vào phiên trước khi thanh toán. **Không phải sửa hàm thanh toán.** |
| Tab Sản phẩm của báo cáo gom theo gì | Gom theo mã món; dòng **không có mã món bị bỏ qua** | Dòng tiền giờ phải gắn với một món thật trong Menu, nếu không sẽ không hiện ở tab Sản phẩm |
| Lọc theo danh mục ở tab Sản phẩm | Theo danh mục của món | Món giá giờ đặt vào danh mục "Tiền giờ" là tách được với đồ ăn uống, không cần mã mới |
| Số lượng trong hoá đơn | Có hai cột, một cột là số nguyên | Không ghi "1,5 giờ" làm số lượng. Ghi số lượng 1, đơn giá = tiền giờ đã tính |
| Trừ kho khi thanh toán | Món nào không có công thức cũng bị trừ tồn 1 mỗi lần bán | Món giá giờ sẽ có tồn âm dần, giống mọi món không công thức hiện nay. Không gây lỗi |
| Chốt chặn khi thêm món vào bàn | App chỉ được thêm món ở trạng thái "chưa gửi" / "đã gửi bếp" | Dòng tiền giờ do **hàm máy chủ** ghi với trạng thái "xong", nên không lên phiếu bếp |
| Chuyển bàn | App tự đổi mã bàn của phiên, máy chủ không kiểm | Phải thêm hàm máy chủ cho chuyển bàn có tính giờ (mục 5, giai đoạn 1) |
| Giờ mở bàn | Do máy của nhân viên ghi | Mốc tính giờ phải do máy chủ đặt, tránh máy sai giờ làm sai tiền |
| Doanh thu thuộc ngày nào | Ngày mở hoá đơn | Phòng mở 23 giờ, tính tiền 1 giờ sáng: tiền nằm ở ngày hôm trước. Giữ nguyên như bàn ăn |

## 4. Cách chạy, nhìn từ phía quán

1. **Cài một lần.** Chủ Quán vào Menu tạo món, ví dụ "Giờ bàn lỗ", giá bán = giá một giờ, danh mục "Tiền giờ". Rồi vào sửa bàn (hoặc sửa khu vực để áp cho cả khu), chọn "Tính tiền giờ theo: Giờ bàn lỗ".
2. **Mở bàn.** Nhân viên mở bàn như thường. Thẻ bàn trên sơ đồ hiện đồng hồ đang chạy và tiền giờ tạm tính.
3. **Gọi đồ.** Như quán thường, vẫn gửi bếp / quầy bar.
4. **Tính tiền.** Bấm Tính tiền: máy chủ chốt giờ, thêm dòng "Giờ bàn lỗ · Bàn 3 · 14:05–15:35" vào bàn, rồi mở màn thanh toán như cũ. Mã giảm giá, điểm, in bill, Thu Chi, báo cáo chạy như một hoá đơn bình thường.
5. **Khách chơi tiếp sau khi đã chốt.** Đóng màn thanh toán, lúc sau bấm Tính tiền lại: dòng tiền giờ được tính lại, không sinh dòng thứ hai.
6. **Chuyển bàn.** Giờ ở bàn cũ được chốt thành một dòng theo giá bàn cũ, đồng hồ chạy tiếp ở bàn mới theo giá bàn mới.
7. **Bỏ tiền giờ** (khách khiếu nại, máy tính sai): Quản lý huỷ dòng đó như huỷ món đã gửi bếp, có lý do và có nhật ký.

Cách tính bản đầu: **theo phút thực tế, một giá cho mỗi bàn, làm tròn lên 1.000đ.**

## 5. Các giai đoạn

### Giai đoạn 1 — Máy chủ (một migration, có tệp hoàn tác và test)

Thêm ba cột, đều cho phép để trống nên app đang chạy không bị ảnh hưởng:

| Bảng | Cột mới | Ý nghĩa |
|---|---|---|
| `ban_dining_tables` | `gia_gio_product_id` | Món giá giờ của bàn. Trống = bàn thường |
| `ban_sessions` | `gio_bat_dau` | Mốc bắt đầu đoạn đang tính. Máy chủ tự đặt khi mở phiên trên bàn tính giờ |
| `ban_session_items` | `gio_tu`, `gio_den` | Có giá trị = đây là dòng tiền giờ, kèm giờ vào và giờ ra |

Hai hàm máy chủ mới:

- **`ban_chot_gio_v1`** — kiểm người gọi là thành viên quán và có quyền thanh toán (cùng cách `settle_ban_session_v5` đang kiểm), khoá phiên, tính tiền từ `gio_bat_dau` tới lúc gọi, ghi (hoặc ghi đè) đúng một dòng tiền giờ cho đoạn đang chạy. Giá lấy từ món trên máy chủ, app không gửi giá.
- **`ban_chuyen_ban_tinh_gio_v1`** — chốt đoạn ở bàn cũ, đổi bàn, đặt mốc mới, tất cả trong một giao dịch. Bàn đích đang có khách thì thành gộp bàn: dời hết món (kể cả dòng tiền giờ vừa chốt) sang phiên đích rồi đóng phiên nguồn.

Năm chốt chặn (hai chốt cuối thêm lúc viết mã, 23/11):

- App không tự thêm / sửa tiền / xoá / dời được dòng tiền giờ; chỉ hai hàm trên ghi. Huỷ dòng đi qua đường huỷ có duyệt sẵn có (phục vụ cần Quản lý duyệt, có nhật ký).
- App không sửa được `gio_bat_dau`, và không tự đổi bàn của phiên đang tính giờ hoặc sang bàn tính giờ (phải gọi hàm chuyển bàn).
- Phiên có tính giờ mà chưa chốt giờ, hoặc chốt đã quá 15 phút, thì **không đóng được**, kể cả bằng hàm thanh toán. Lý do: máy còn chạy bản app cũ sẽ thanh toán bàn mà không biết có tiền giờ, quán mất tiền mà không ai hay. Thà báo lỗi còn hơn. Mốc 15 phút chặn kiểu chốt sớm rồi cho khách chơi tiếp.
- **Huỷ bàn tính giờ đã mở quá 5 phút phải chốt giờ trước.** Khi đã có dòng tiền giờ, luật huỷ bàn sẵn có đòi Quản lý duyệt. Không có chốt này, nhân viên huỷ một bàn chỉ chơi không gọi đồ là xong, không ai duyệt. Mở nhầm bàn thì huỷ ngay trong 5 phút vẫn được.
- **Chỉ Chủ quán / Quản lý gắn giá giờ cho bàn**; món giá giờ phải của đúng quán; không đổi giá giờ khi bàn đang có khách tính giờ.

Đổi giá bán của món giá giờ trong Menu lúc bàn đang chạy: giá mới áp cho cả đoạn đang tính (tiền tính lúc chốt, không tính dần).

Tệp: `supabase/migrations/2026MMDD_ban_tinh_gio_v1.sql` + bản `_ROLLBACK`, test `supabase/tests/ban_tinh_gio_v1_test.sql`, tệp áp `db-fix/ban_tinh_gio_ap_dung.sh`. Chạy thử trên bản sao bằng `db-fix/chuoi_stage_dryrun.sh` trước khi áp.

Test phải bác bỏ được: bấm chốt hai lần ra hai dòng; hai máy chốt cùng lúc; chốt phiên của quán khác; app tự chèn dòng tiền giờ; chuyển bàn làm mất hoặc tính trùng thời gian; thanh toán khi chưa chốt; phiên bàn thường bị ảnh hưởng.

### Giai đoạn 2 — App

| Việc | Nơi sửa |
|---|---|
| Đăng ký module `tinh_gio` đủ 8 bước trong `.docs/tinh-nang.md` (mục "Checklist khi thêm module mới"); mặc định tắt; chặn bật khi module Bàn đang tắt; chặn tắt khi còn bàn tính giờ đang mở | `main.dart`, `shared/widgets/module_tile.dart`, `core/database/app_database.dart`, `dashboard_screen.dart`, `role_manager_screen.dart` |
| Chọn loại hình khi bật module (đổi lại được trong chế độ Sửa module); ô module đọc tên + biểu tượng theo loại hình; thêm biểu tượng ngành vào ô chọn biểu tượng khu vực | `shared/widgets/module_tile.dart`, `dashboard_screen.dart`, `ban_screen.dart`, `assets/icons/` |
| Mọi phần tính giờ ở màn Bàn chỉ hiện khi module `tinh_gio` đang bật và người dùng có quyền module này | `lib/screens/ban_screen.dart` |
| Ô "Tính tiền giờ theo" trong sửa bàn; "Áp cho cả khu" trong sửa khu vực | `lib/screens/ban_screen.dart` (phần quản lý bàn) |
| Đọc ba cột mới | model bàn / phiên / món trong `lib/core/repositories/ban_repository.dart` |
| Đồng hồ + tiền tạm tính trên thẻ bàn. Một bộ đếm chung cho cả màn, không phải mỗi thẻ một bộ | `ban_screen.dart` |
| Nút Tính tiền: gọi chốt giờ rồi mới mở thanh toán; nút "Tính lại giờ" trong màn thanh toán | `ban_screen.dart` (`_checkout`) |
| Chuyển bàn, gộp bàn: phiên có tính giờ thì gọi hàm máy chủ mới | `BanRepository.transferSession`, `mergeSession` |
| Dòng tiền giờ trong danh sách món của bàn: không có nút sửa số lượng, không có nút gửi bếp | `ban_screen.dart` |

Phải kiểm khi làm, chưa kiểm lúc lập kế hoạch:

- Bill 58mm (Sunmi) in dòng tên dài có xuống dòng gọn không.
- Màn Bếp và dải "món xong" ở Bàn không báo nhầm dòng tiền giờ là món vừa làm xong.
- Thực đơn QR cho khách có đang hiện mọi món không. Nếu có, phải ẩn món giá giờ để khách không tự đặt "Giờ bàn lỗ".
- Bán tại quầy (`complete_pos_sale_v1`) đóng phiên bàn theo đường riêng: phiên có tính giờ phải bị chốt chặn ở giai đoạn 1 bắt lại.

Test Flutter: tiền tạm tính, luồng nút Tính tiền, chuyển bàn. Chụp ảnh thử có nạp phông biểu tượng trước khi gửi Chủ Quán duyệt giao diện.

### Giai đoạn 3 — Đặt trước (đặt sân, đặt bàn, đặt phòng hẹn giờ)

Làm sau giai đoạn 1 và 2 vì nó dựa trên bàn tính giờ. Đặt trước **không tạo ra doanh thu**: tiền chỉ vào báo cáo khi khách đến, chơi và thanh toán như một bàn tính giờ bình thường. Vì vậy báo cáo vẫn không phải sửa.

**Cách chạy phía quán**

1. Mở "Lịch đặt" trong module, chọn ngày. Máy tính bảng / PC: lưới có cột là từng sân, hàng là giờ (bước 30 phút). Điện thoại: danh sách theo từng sân.
2. Bấm ô trống để đặt: tên khách, số điện thoại, từ giờ nào đến giờ nào, ghi chú.
3. Khách đến: bấm lượt đặt, chọn "Nhận sân". App mở bàn và đồng hồ chạy.
4. Khách không đến: bấm "Không đến" hoặc "Huỷ", khung giờ trống lại.
5. Sơ đồ bàn: thẻ bàn hiện lượt đặt kế tiếp trong ngày ("Đặt 18:00 · Anh Nam"). Mở bàn cho khách vãng lai khi sắp tới giờ đã đặt thì app cảnh báo. Bàn đang chơi lấn sang giờ người khác đã đặt thì thẻ đổi màu.

**Nhắc trước 30 phút** (Chủ Quán chốt 23/11)

- Còn 30 phút tới giờ đặt, app bật một hộp nhắc kèm tiếng chuông: "Sắp tới giờ đặt · Sân 2 · 18:00–19:00 · Anh Nam · số điện thoại". Mục đích: quán gọi nhắc khách.
- Ba nút: **Gọi khách** (mở trình gọi điện trên điện thoại; trên máy tính và web thì hiện số để bấm sao chép), **Đã nhắc**, **Đóng**.
- Một người bấm "Đã nhắc" thì hộp nhắc trên các máy khác tự đóng, và lượt đặt trong Lịch đặt hiện dấu "Đã nhắc 17:32 · Lan". Không ai bấm thì mỗi máy chỉ hiện một lần.
- Ai thấy: người có quyền module này (Chủ quán, Quản lý, nhân viên được gán), vì chủ không phải lúc nào cũng ở quán. Xem câu 8 mục 7.
- Lượt vừa đặt khi còn dưới 30 phút thì không nhắc.
- **Giới hạn: chỉ hiện khi app đang mở.** App chưa có thông báo đẩy (loại hiện cả khi app đóng), nên điện thoại của chủ đang tắt app sẽ không nhận được. Máy bán hàng ở quầy mở suốt giờ bán nên vẫn nhắc được. Làm thông báo đẩy là dựng một hạ tầng mới, xem mục 6.

Cách làm: bộ canh giờ đặt ở Trang chủ (màn luôn mở với mọi người đã đăng nhập, cùng chỗ đang nghe đổi quyền), chỉ chạy khi module đang bật. Nó dùng luôn danh sách lượt đặt hôm nay đã tải sẵn, mỗi phút so giờ một lần trên máy, không hỏi thêm máy chủ. Chuông dùng lại bộ phát âm của đơn QR (`qr_sound_service.dart`), nút gọi dùng `url_launcher` đã có trong app. Bảng `ban_dat_truoc` thêm hai ô: nhắc lúc nào, ai nhắc; ghi qua một hàm máy chủ.

**Tính tiền cho lượt đặt** (mặc định, xem mục 7): tính theo khung đã đặt, kể cả khi khách đến trễ; chơi quá giờ thì tính thêm theo phút. Phần tính nằm trong `ban_chot_gio_v1`, app không đổi.

**Máy chủ** (migration thứ hai, có tệp hoàn tác và test)

- Bảng mới `ban_dat_truoc`: quán, bàn, tên khách, số điện thoại, giờ từ, giờ đến, ghi chú, trạng thái (đã đặt / đã nhận / huỷ / không đến), phiên bàn đã gắn, người tạo. Có `store_id`, chỉ thành viên quán đọc được.
- **Chống đặt trùng ở cơ sở dữ liệu**: một ràng buộc không cho hai lượt còn hiệu lực trùng giờ trên cùng một bàn. Hai nhân viên đặt cùng lúc thì một người nhận báo lỗi, không bao giờ có hai lượt chồng nhau.
- Ba hàm: tạo / sửa lượt đặt, huỷ hoặc đánh dấu không đến, nhận sân (gắn lượt đặt với phiên bàn và đặt mốc tính giờ, trong một giao dịch). App không ghi thẳng vào bảng.
- Số điện thoại khách là dữ liệu cá nhân: Boom không đọc bảng này.

**App**

| Việc | Nơi sửa |
|---|---|
| Màn "Lịch đặt" (lưới tự vẽ bằng thành phần có sẵn, không thêm thư viện lịch), bọc `ResponsiveLayout` | màn mới trong `lib/modules/tinh_gio/` |
| Hộp đặt / sửa / huỷ / nhận sân | cùng thư mục |
| Thẻ bàn hiện lượt đặt kế tiếp, cảnh báo khi mở bàn sát giờ đặt, đổi màu khi lấn giờ | `lib/screens/ban_screen.dart` |
| Bộ canh giờ + hộp nhắc trước 30 phút, chuông, nút gọi | `dashboard_screen.dart`, widget mới trong `lib/modules/tinh_gio/` |
| Đọc lượt đặt theo kiểu tải lại khi máy chủ báo đổi (`watchByRefetch`, như món của bàn) | kho dữ liệu mới cạnh `ban_repository.dart` |

Test phải bác bỏ được: hai lượt trùng giờ cùng sân; đặt cho sân của quán khác; nhận sân hai lần; huỷ lượt đã nhận; lượt đặt qua nửa đêm; tiền tính sai khi khách đến trễ hoặc chơi lố; hộp nhắc hiện hai lần trên một máy; nhắc lượt đã huỷ hoặc đã nhận sân; người không có quyền module vẫn thấy hộp nhắc (lộ số điện thoại khách).

### Giai đoạn 4 — Tài liệu

- Bài hướng dẫn trong `.docs/Huong_dan/` (bài Bàn): thêm mục bàn tính giờ và đặt trước, xuất lại cho Boom, đóng dấu. Đăng cho app đang chạy thì hỏi Chủ Quán trước.
- `.docs/kien-truc-data.md`, `.docs/tinh-nang.md`.
- `codegraph sync .`, `graphify update .`.

### Giai đoạn 5 — Thử và phát hành

1. Thử trọn vòng trên quán Demo: đặt trước, nhận sân, mở bàn vãng lai, gọi đồ, chuyển bàn, chốt, thanh toán, xem tab Doanh thu, tab Sản phẩm (lọc "Tiền giờ"), Thu Chi, bill in.
2. Áp migration lên máy chủ (hỏi Chủ Quán trước khi áp).
3. Phát hành: mặc định một bản có đủ tính giờ và đặt trước. Nếu có quán bi da hoặc karaoke cần sớm thì phát hành sau giai đoạn 2, đặt trước đi bản kế tiếp; hai phần tách được vì đặt trước nằm ở migration riêng.
4. Quán bật bàn tính giờ phải cập nhật **tất cả** máy lên bản mới. Máy còn bản cũ sẽ không thanh toán được bàn tính giờ (chốt chặn ở giai đoạn 1).

## 6. Chưa làm ở bản đầu

| Việc | Lý do để sau |
|---|---|
| Giá theo khung giờ (ngày / tối, giờ cao điểm, cuối tuần) | Karaoke và sân thường cần. Thêm sau bằng một bảng giá theo khung, chỉ đổi phần tính trong `ban_chot_gio_v1`, app và báo cáo không đổi |
| Lịch cố định lặp hàng tuần (khách đặt thứ 3-5-7 cả tháng) | Bản đầu đặt từng lượt. Sân cầu lông hay cần cái này, nên là việc làm ngay sau bản đầu |
| Khách tự đặt qua mạng | Cần trang cho khách, chống phá, xác nhận. Bản đầu nhân viên đặt hộ khi khách gọi điện |
| Nhắc lịch thẳng tới khách (tin nhắn, Zalo) | Cần dịch vụ gửi tin bên ngoài, có phí. Bản đầu app nhắc quán, quán gọi khách |
| Thông báo đẩy khi app đang đóng | App chưa có hạ tầng này: phải đăng ký dịch vụ đẩy cho Android và iOS, xin quyền thông báo, qua duyệt cửa hàng ứng dụng. Windows và web cần cách riêng |
| Chỉnh số phút nhắc trước | Bản đầu cố định 30 phút |
| Tiền cọc tự vào Thu Chi và tự trừ vào hoá đơn | Đụng tới tiền và hoàn tiền khi huỷ. Bản đầu chỉ ghi số tiền đã cọc lên lượt đặt để nhân viên biết |
| Tạm dừng đồng hồ, thời lượng tối thiểu, phụ thu ngày lễ | Chờ quán thật yêu cầu |
| Tab báo cáo công suất (bàn nào kín, khung giờ nào đông) | Giờ vào, giờ ra đã lưu trên từng dòng nên làm sau không phải nhập lại dữ liệu |
| Mỗi ngành một module riêng ("Bi da", "Karaoke", "Sân") | Bản đầu một module "Tính giờ" dùng chung. Tách tên theo ngành khi từng ngành có tính năng riêng (ví dụ đặt sân trước) |

## 7. Chờ Chủ Quán chốt

Nếu không có ý kiến khác, làm theo lựa chọn in đậm.

1. Cách làm tròn: **theo phút, làm tròn lên 1.000đ**, hay theo khối (ví dụ mỗi 15 phút)?
2. Giá theo khung giờ: **để sau bản đầu**, hay phải có ngay? Nếu quán đầu tiên là karaoke thì nên có ngay.
3. Mã giảm giá và điểm thưởng: **áp trên cả tiền giờ** (không phải sửa gì), hay chỉ áp trên đồ ăn uống (phải sửa hàm thanh toán)?
4. Quán nào thử đầu tiên?
5. Lượt đặt trước tính tiền thế nào: **theo khung đã đặt, đến trễ vẫn tính đủ, chơi lố tính thêm theo phút**, hay tính theo giờ chơi thực tế như khách vãng lai?
6. Tiền cọc: **bản đầu chỉ ghi số tiền lên lượt đặt**, hay phải vào Thu Chi và tự trừ vào hoá đơn ngay?
7. Lịch cố định hàng tuần: **làm ngay sau bản đầu**, hay phải có trong bản đầu?
8. Hộp nhắc trước 30 phút hiện cho ai: **mọi người có quyền module này**, hay chỉ tài khoản Chủ quán?

## 8. Nhật ký thực hiện

### 23/11 — Giai đoạn 1 (máy chủ): viết xong, ĐÃ ÁP production 14:34

Tệp:

- `supabase/migrations/20261123_ban_tinh_gio_v1.sql` và bản `_ROLLBACK`
- `supabase/tests/ban_tinh_gio_v1_test.sql` (50 mục, tự ROLLBACK)
- `../db-fix/ban_tinh_gio_ap_dung.sh` (backup → áp → test; `DRYRUN=1`, `ROLLBACK=1`)

Chạy thử trên bản sao của máy chủ thật (`chuoi_stage_dryrun.sh`, máy chủ thật chỉ bị đọc, bản sao đã xoá):

- Bộ test mới: 50/50 qua. Có gọi `settle_ban_session_v5` thật và `get_top_products_for_range_v1` thật: hoá đơn có dòng tiền giờ, báo cáo món bán chạy thấy đúng tiền mà không sửa hàm nào.
- Bộ test cũ về bàn chạy sau khi áp: `chan_dong_phien_ban_v1` 16/16, `ops_ban_giao_ca_v1` 16/16, `topping_ban_tru_kho_v1` qua.
- Áp lại lần hai không lỗi. Hoàn tác sạch (0 hàm, 0 trigger, 0 cột còn sót), áp lại sau hoàn tác vẫn 50/50.

Lỗi bắt được nhờ chạy thử: `qn_is_store_manager_v1` không cấp cho vai app, trigger gắn giá giờ gọi thẳng thì báo "permission denied". Đã dời phần kiểm quyền vào hàm phụ chạy bằng quyền máy chủ.

Chưa kiểm được trong một giao dịch test: hai máy bấm chốt đúng cùng một lúc. Hàm khoá phiên bàn trước khi ghi nên về lý thuyết xếp hàng; T6 chỉ chứng minh bấm lại không sinh dòng thứ hai.

Điều cần biết cho giai đoạn 2:

- Giờ in trên dòng bỏ phần giây, còn số phút tính tiền làm tròn lên, nên có thể lệch nhau 1 phút ("13:00–14:29 (1g30)").
- `settle_ban_session_v5` khi bàn chưa chốt giờ sẽ **văng lỗi** `CHUA_CHOT_GIO` / `CHOT_GIO_QUA_CU` (không trả `success:false`). App phải bắt hai mã này, gọi `ban_chot_gio_v1` rồi cho thu ngân xem lại tổng.
- Huỷ bàn tính giờ mở quá 5 phút: app gọi `ban_chot_gio_v1` trước rồi mới đi luồng huỷ bàn có duyệt.
- Chuyển / gộp bàn: khi phiên nguồn có `gio_bat_dau` hoặc bàn đích có `gia_gio_product_id` thì gọi `ban_chuyen_ban_tinh_gio_v1`, còn lại giữ đường cũ.
- Gộp bàn thường VÀO bàn tính giờ vẫn đi đường cũ của app (không có dòng tiền giờ nào phải dời).

**Áp production 23/11 14:34** (Chủ Quán bảo "Áp lên máy chủ"): `bash db-fix/ban_tinh_gio_ap_dung.sh`, mất 11 giây kể cả sao lưu. Mốc hoàn tác: `/root/quannho-backups/quannho_before_ban_tinh_gio_20261123_143355.dump`; nhật ký `db-fix/ban_tinh_gio_log_20261123_143355.txt`. Test chạy lại ngay trên máy chủ thật: 50/50, tự ROLLBACK. Kiểm sau khi áp: 9 hàm, 3 trigger, 4 cột; không sót dữ liệu test; chưa bàn nào gắn giá giờ nên chưa quán nào đổi hành vi.

