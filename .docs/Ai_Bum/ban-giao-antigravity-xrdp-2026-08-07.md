# Bàn giao Antigravity — hoàn tất truy cập từ xa BunServer

## Mục tiêu

Khôi phục mật khẩu Linux của tài khoản `pachiabun`, xác minh đăng nhập bằng mật khẩu, rồi kiểm tra XRDP từ Mac qua Tailscale. Không cài lại Ubuntu, Tailscale hoặc XRDP nếu chưa có bằng chứng chúng bị lỗi.

## Trạng thái đã xác minh

- Ubuntu Desktop 24.04.4 LTS, máy `BunServer`, user `pachiabun`.
- Tailscale hoạt động:
  - BunServer: `100.113.221.116`
  - Mac: `100.107.1.30`
- SSH key từ Mac hoạt động không cần mật khẩu:

  ```bash
  ssh -i ~/.ssh/ai_bum_pilot_ed25519 pachiabun@100.113.221.116
  ```

- RTX 2060 và driver NVIDIA hoạt động (`nvidia-smi` thành công).
- XRDP và `xrdp-sesman` đã cài, đang chạy; cổng TCP 3389 truy cập được qua Tailscale.
- GNOME Remote Desktop cũ đã tắt để tránh xung đột.
- Windows App trên Mac đã vào được màn hình XRDP. Chọn session `Xorg`, user `pachiabun`, nhưng báo `login failed for user pachiabun`.
- Log xác nhận lỗi PAM authentication; mạng, Tailscale và XRDP không phải nguyên nhân chính.
- Thử SSH cưỡng bức password cũng thất bại:

  ```bash
  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no pachiabun@100.113.221.116
  ```

- `sudo` cũng không chấp nhận mật khẩu người dùng đang nhớ.
- Lần đổi mật khẩu bằng `passwd` trước đó không thành công, báo `password unchanged` do mật khẩu mới gần mật khẩu cũ.

## Kết luận

Người dùng hiện không biết mật khẩu Linux hợp lệ. SSH key vẫn vào được nhưng không có quyền root nếu không nhập đúng mật khẩu sudo. Cần reset mật khẩu trực tiếp bằng Ubuntu Recovery Mode.

## Việc Antigravity cần làm tiếp

1. Hướng dẫn chủ máy từng màn hình, mỗi lần chỉ một bước ngắn.
2. Yêu cầu thao tác trực tiếp tại BunServer:
   - Reboot.
   - Khi khởi động, nhấn `Esc` liên tục để hiện GRUB (máy dùng UEFI).
   - Chọn `Advanced options for Ubuntu`.
   - Chọn kernel mới nhất có `(recovery mode)`; lần gần nhất thấy kernel `7.0.0-28-generic`.
   - Chọn `root — Drop to root shell prompt`.
3. Trong root shell chạy:

   ```bash
   mount -o remount,rw /
   passwd pachiabun
   passwd -u pachiabun
   sync
   reboot
   ```

4. Mật khẩu mới phải hoàn toàn khác mật khẩu cũ; tạm dùng chữ hoa, chữ thường và số, tối thiểu 12 ký tự. Không yêu cầu người dùng gửi/chụp mật khẩu.
5. Sau reboot, kiểm tra từ Mac trước bằng password SSH:

   ```bash
   ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no pachiabun@100.113.221.116
   ```

6. Chỉ khi SSH password thành công mới thử Windows App:
   - PC: `100.113.221.116:3389`
   - Gateway: none
   - Session: `Xorg`
   - Username: `pachiabun`
   - Password: mật khẩu Linux mới
7. Nếu SSH password thành công nhưng XRDP vẫn lỗi, dùng SSH key thu thập read-only evidence trước khi sửa:

   ```bash
   sudo journalctl -u xrdp -u xrdp-sesman -n 150 --no-pager
   sudo tail -n 150 /var/log/auth.log
   ```

## Nguyên tắc an toàn

- Không cài lại hệ điều hành.
- Không format/chia lại ổ.
- Không mở 3389 ra Internet; chỉ dùng qua Tailscale.
- Không xóa SSH key đang hoạt động.
- Không sửa PAM/XRDP trước khi xác minh password SSH.
- Không ghi hoặc hiển thị mật khẩu trong báo cáo/chat.
