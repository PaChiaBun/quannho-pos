# KẾ HOẠCH CÀI UBUNTU BẰNG USB CHO SERVER AI BUM

> **Ngày lập:** 06/08/2026  
> **Máy đích:** `DESKTOP-U1VAD6F`  
> **Trạng thái:** Kế hoạch để review — chưa được phép cài đặt hoặc format ổ đĩa  
> **Mục tiêu:** Chuyển máy Windows 10 gần như trống thành server Ubuntu phục vụ AI Bum, đồng thời giữ đường quay lui về Windows cho tới khi Ubuntu được nghiệm thu.

---

## 1. Bối cảnh phần cứng đã xác nhận

- Mainboard: ASUS Z10PA-D8 Series.
- CPU: 2 × Intel Xeon E5-2680 v4, tổng khoảng 28 nhân/56 luồng.
- RAM: 128 GB.
- GPU: NVIDIA GeForce RTX 2060 6 GB.
- GPU audit: driver Windows 560.94, CUDA 12.6, `nvidia-smi` hoạt động.
- Ổ đĩa:
  - Samsung SSD 970 EVO Plus 1 TB NVMe.
  - Kingston SA400S3 khoảng 447 GB SATA SSD.
- Hai card mạng Intel I210 Gigabit; hiện chỉ một cổng được kết nối.
- Virtualization đã bật trong firmware; CPU hỗ trợ VM Monitor Mode, SLAT và DEP.
- Hệ điều hành hiện tại: Windows 10 Pro 22H2, build 19045.6456.

Thông số trên chỉ dùng để nhận diện máy. Không lưu Device ID, Product ID, địa chỉ IP, email, mật khẩu hoặc khóa truy cập vào tài liệu/repository.

---

## 2. Quyết định kiến trúc

### Hệ điều hành mục tiêu

- Ưu tiên **Ubuntu Desktop 24.04 LTS 64-bit** để chủ dự án vẫn có giao diện đồ họa và Remote Desktop.
- Docker, Supabase Staging, AI Gateway, Classification, RAG và Qwen local sẽ chạy native trên Ubuntu.
- RTX 2060 được dùng qua NVIDIA Linux Driver và NVIDIA Container Toolkit.

### Chiến lược hai ổ đĩa

- Không xóa Windows trong lần cài đầu.
- Ưu tiên cài Ubuntu lên một ổ vật lý riêng sau khi xác minh ổ đó không chứa dữ liệu cần giữ.
- Giữ nguyên ổ Windows tối thiểu 14 ngày sau khi Ubuntu được nghiệm thu để làm phương án rollback.
- Không được giả định Windows nằm trên Samsung hay Kingston chỉ dựa vào tên/dung lượng.

### Điều khiển từ xa

- Quản trị chính: Tailscale + SSH.
- Giao diện đồ họa: Remote Login/RDP của Ubuntu Desktop qua mạng Tailscale.
- Không public trực tiếp port `22`, `3389`, Docker API, Supabase Studio hoặc AI Gateway ra Internet.
- Chrome Remote Desktop có thể dùng làm đường dự phòng sau khi Ubuntu đã hoạt động ổn định.

---

## 3. Nguyên tắc bắt buộc cho Antigravity

1. Làm từng phase, báo cáo rồi dừng chờ duyệt.
2. Không tự khởi động lại máy.
3. Không tự thay đổi BIOS/UEFI hoặc boot order.
4. Không tự tắt Secure Boot, TPM hoặc tính năng bảo mật.
5. Không tự format, repartition, erase hoặc ghi image lên bất kỳ ổ nào.
6. Trước mọi thao tác ghi USB/ổ đĩa, phải hiển thị model, dung lượng và serial đã che một phần, sau đó chờ chủ dự án xác nhận đúng thiết bị.
7. Không được chọn `Erase disk and install Ubuntu` khi chưa có phê duyệt cụ thể cho đúng ổ.
8. Không lưu secret trong Markdown, ảnh chụp, terminal history hoặc Git.
9. Không triển khai Supabase/AI Bum trong kế hoạch này; chỉ chuẩn bị host Ubuntu và kiểm thử nền tảng.
10. Nếu mất Remote Desktop, dừng và hướng dẫn người đang đứng cạnh máy; không đoán thao tác BIOS/installer.

---

## 4. Phân phase thực hiện

## PHASE U0 — Audit trước cài đặt

### Mục tiêu

Chốt dữ liệu cần giữ, nhận diện chính xác hai SSD và bảo đảm có đường rollback.

### Việc cần làm trên Windows — chỉ đọc

- Kiểm tra partition, EFI, Recovery và ổ đang chứa Windows.
- Kiểm tra BitLocker trên từng volume.
- Kiểm tra health/SMART của hai SSD.
- Ghi lại model, bus type, dung lượng và mapping disk/volume.
- Kiểm tra boot mode UEFI, Secure Boot và BIOS version.
- Kiểm tra driver/card mạng đang dùng.
- Kiểm tra máy có dữ liệu nào cần backup ngoài repository hay không.

### Đầu ra

- Bảng `Disk 0/Disk 1 → model → partition → volume → dữ liệu`.
- Xác định ổ Windows cần giữ nguyên.
- Đề xuất ổ cài Ubuntu nhưng chưa được phép chọn thay chủ dự án.
- Danh sách dữ liệu cần backup.

### Điểm dừng bắt buộc

Dừng để chủ dự án xác nhận bằng văn bản:

```text
Tôi xác nhận ổ cài Ubuntu là: <MODEL + DUNG LƯỢNG + DISK NUMBER>.
Tôi hiểu mọi dữ liệu trên đúng ổ này có thể bị xóa.
```

Chưa có câu xác nhận này thì không sang Phase U1.

---

## PHASE U1 — Chuẩn bị USB cài đặt

### Yêu cầu USB

- USB tối thiểu 16 GB.
- USB không chứa dữ liệu cần giữ.
- ISO lấy từ trang chính thức của Ubuntu.
- Bắt buộc dùng **Ubuntu Desktop 24.04 LTS `amd64`/`x86_64`** cho server dual Xeon. Dù USB được tạo trên Mac Apple Silicon, tuyệt đối không tải hoặc ghi ISO `arm64`.
- Kiểm tra checksum SHA-256 của ISO trước khi ghi.
- Công cụ ghi USB phải lấy từ nguồn chính thức; có thể dùng Rufus trên Windows hoặc balenaEtcher trên Mac.

### Quy trình

1. Liệt kê toàn bộ USB/ổ ngoài đang gắn.
2. Xác định USB theo model và dung lượng.
   - Tên `/dev/diskN` chỉ có giá trị tại thời điểm kiểm tra và có thể thay đổi sau khi tháo/cắm lại.
   - Phải chạy lại `diskutil list external physical` ngay trước khi ghi.
3. Dừng để chủ dự án xác nhận đúng USB.
4. Chỉ sau xác nhận mới ghi ISO lên USB.
5. Kiểm tra USB boot được nhưng chưa thay đổi boot order.

### Điểm dừng bắt buộc

- Việc ghi USB sẽ xóa dữ liệu trên USB, nên người dùng phải tự xác nhận thiết bị đích ngay trước nút `Start/Flash`.
- Antigravity không được bấm thay nếu giao diện không thể chứng minh chắc chắn đúng USB.

---

## PHASE U2 — Cửa sổ bảo trì và cài Ubuntu tại máy

### Điều kiện bắt đầu

- Có người đứng cạnh server với màn hình và bàn phím.
- Có USB Ubuntu đã xác minh checksum.
- Đã backup dữ liệu cần thiết.
- Đã xác nhận chính xác ổ cài Ubuntu.
- Chủ dự án chấp nhận Chrome Remote Desktop sẽ mất kết nối khi reboot.

### Trình tự

1. Khởi động lại và mở Boot Menu thủ công.
2. Boot USB ở chế độ UEFI.
3. Chọn `Try Ubuntu` trước, chưa cài ngay.
4. Trong Live Session, kiểm tra:
   - Nhận đủ CPU và RAM.
   - Nhận hai SSD đúng model.
   - Card mạng có Internet.
   - Bàn phím, chuột và màn hình hoạt động.
   - GPU xuất hình bình thường.
5. Chụp/báo lại mapping ổ đĩa lần cuối.
6. Chỉ cài Ubuntu lên đúng ổ đã được duyệt.
7. Không sửa hoặc format ổ Windows.
8. Tạo tài khoản quản trị không dùng tên `root`; mật khẩu do chủ dự án tự nhập và không gửi vào chat.
9. Hoàn thành cài đặt và boot Ubuntu.

### Điểm dừng khẩn cấp

Dừng ngay nếu:

- Installer hiển thị dung lượng/model khác kế hoạch.
- Chỉ thấy một SSD.
- Không xác định được EFI partition thuộc ổ nào.
- Installer yêu cầu tắt Secure Boot/RAID/RST ngoài kế hoạch.
- Có cảnh báo xóa cả hai ổ.

---

## PHASE U3 — Khôi phục quản trị từ xa

### Mục tiêu

Đảm bảo có ít nhất hai đường quản trị trước khi rời máy.

### Việc cần làm

1. Cập nhật Ubuntu từ repository chính thức.
2. Cài OpenSSH Server.
3. Cài Tailscale từ nguồn chính thức.
4. Thiết lập SSH key; sau khi kiểm thử thành công mới tắt đăng nhập SSH bằng mật khẩu.
5. Bật Remote Login/RDP trên Ubuntu Desktop.
6. Chỉ cho phép SSH/RDP qua LAN hoặc Tailscale.
7. Từ Mac, kiểm thử:
   - SSH vào được.
   - RDP vào được.
   - Reboot xong máy tự lên mạng và kết nối lại được.
8. Không mở port router/public Internet.

### Điểm dừng

Dừng để nghiệm thu Remote Access. Chưa cài Docker/GPU stack nếu chưa đăng nhập lại thành công sau một lần reboot thử.

---

## PHASE U4 — Driver NVIDIA và nền tảng container

### Việc cần làm

1. Cài NVIDIA driver được Ubuntu khuyến nghị từ repository chính thức.
2. Reboot có kiểm soát.
3. Xác minh `nvidia-smi` nhận RTX 2060 6 GB và không có lỗi.
4. Cài Docker Engine và Docker Compose plugin từ repository chính thức của Docker.
5. Cài NVIDIA Container Toolkit từ repository chính thức của NVIDIA.
6. Kiểm thử:
   - Docker `hello-world`.
   - Container nhìn thấy GPU.
   - Docker tự khởi động lại sau reboot.
7. Không expose Docker socket qua TCP.
8. Không thêm tài khoản không cần thiết vào nhóm `docker` vì nhóm này tương đương quyền quản trị cao.

### Điểm dừng

Xuất báo cáo version, trạng thái service và kết quả test; không triển khai Supabase hoặc model.

---

## PHASE U5 — Chuẩn hóa server trước khi triển khai AI Bum

### Việc cần làm

- Đặt hostname phù hợp, ví dụ `ai-bum-pilot`, sau khi chủ dự án duyệt.
- Thiết lập timezone `Asia/Ho_Chi_Minh` và đồng bộ thời gian.
- Cấu hình không sleep/hibernate.
- Sau khi được duyệt tại BIOS, bật tự khởi động khi có điện trở lại.
- Thiết kế thư mục dữ liệu, backup và log trên đúng SSD.
- Đặt resource limit cho Supabase, AI Gateway và model local.
- Thiết lập firewall fail-closed và chỉ mở dịch vụ cần thiết qua Tailscale/LAN.
- Lập backup/restore test trước khi đưa dữ liệu thật lên máy.

### Điểm dừng cuối

Chỉ khi U0–U5 đạt mới quay lại kế hoạch:

`.docs/Ai_Bum/ke-hoach-giao-viec-antigravity.md`

và tiếp tục phần Supabase Staging/AI Gateway. Không chạy migration Production.

---

## 5. Tiêu chí nghiệm thu host Ubuntu

- Ubuntu nhận đủ 2 CPU, khoảng 28 core/56 thread và 128 GB RAM.
- Hai SSD đúng model, health tốt và không xóa nhầm ổ Windows.
- RTX 2060 6 GB hoạt động qua `nvidia-smi`.
- Docker và NVIDIA Container Toolkit vượt kiểm thử.
- SSH và RDP từ Mac hoạt động qua Tailscale.
- Không có port quản trị mở trực tiếp ra Internet.
- Máy tự khởi động dịch vụ sau reboot có kiểm soát.
- Có tài liệu mapping ổ đĩa, backup và rollback.
- Windows vẫn boot lại được trong thời gian giữ rollback 14 ngày.

---

## 6. Phương án rollback

Nếu Ubuntu chưa đạt nghiệm thu:

1. Không xóa hoặc sửa thêm partition.
2. Chọn lại Windows Boot Manager từ BIOS/Boot Menu.
3. Nếu cần, tháo/ngắt tạm ổ Ubuntu sau khi tắt máy hoàn toàn.
4. Không chạy công cụ sửa boot tự động khi chưa có bản sao EFI và chưa được duyệt.
5. Ghi lại lỗi và quay về phase tương ứng; không tiếp tục triển khai AI Bum.

---

## 7. Lệnh giao việc khởi đầu cho Antigravity

```text
Đọc đầy đủ:
1. .agents/workflows/qn.md
2. .docs/Ai_Bum/ke-hoach-cai-ubuntu-usb-server-ai-bum.md
3. .docs/Ai_Bum/ke-hoach-giao-viec-antigravity.md
4. .docs/Ai_Bum/chien-luoc-chung-cat-mac-mam.md

Chỉ thực hiện PHASE U0 — Audit trước cài đặt trên máy DESKTOP-U1VAD6F.

Không cài phần mềm, không ghi USB, không reboot, không sửa BIOS, không format,
không repartition, không chạy Docker và không thay đổi firewall.

Phải lập mapping chính xác Disk → Model → Partition → Volume → Windows/EFI/Recovery/Data,
kiểm tra BitLocker, SMART/health, UEFI/Secure Boot và dữ liệu cần backup.

Ẩn Device ID, Product ID, IP, email, username, serial và mọi secret.
Viết báo cáo rồi dừng để chủ dự án review. Không tự sang Phase U1.
```
