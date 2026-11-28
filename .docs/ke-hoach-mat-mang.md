# Đợt 8 lộ trình tính giờ: mất mạng lúc thanh toán — đo trước rồi mới quyết

Lập 28/11/2026 khi Chủ Quán bảo "làm tiếp đi" (đợt 7 đã commit 1e1e9e4). Lộ trình: `lo-trinh-tinh-gio.md`: "đo xem quán bị chặn thanh toán bàn tính giờ bao nhiêu lần, rồi mới quyết có làm chế độ dự phòng".

## Vì sao đo được ngay

- Bàn tính giờ lúc thanh toán cần máy chủ hai lần: chốt giờ (`ban_chot_gio_v1`) rồi thanh toán (`settle_ban_session_v5/v6`). Bàn thường cần một lần (thanh toán). Cả hai **đều không thanh toán được khi mất mạng hẳn**; bàn tính giờ không có chỗ yếu riêng ngoài một lần gọi thêm.
- App giữ nhật ký trên máy khi mất mạng rồi gửi lên `app_logs` khi có mạng lại (tới 24 giờ). Nên đo được thanh toán lúc mạng chập chờn ở **mọi quán thật** (bàn thường), chưa cần phát hành module.

## Kết quả 30 ngày (tới 28/11, chỉ đọc, `tool/do_mat_mang.sh`)

Mạng chập chờn (khung 15 phút có ít nhất một dòng lỗi mạng: không phân giải được tên máy chủ, hết giờ chờ, mất kết nối):

| Quán | Khung 15 phút | Số ngày |
|---|---|---|
| Bò Đen Trà Quán | 130 | 23 |
| A ĐẢNH-Rạch Giá | 110 | 27 |
| Các quán khác | ≤ 13 | ≤ 8 |

Thanh toán bàn (một phiên = một lần mở màn Thu tiền đầu tiên của phiên):

| Khi | Loại | Phiên | Xong | Chưa xong | Trung vị (giây) | Lâu hơn 5 phút |
|---|---|---|---|---|---|---|
| Lúc bình thường | bàn thường | 2.802 | 2.788 | 14 | 40 | 126 |
| Lúc bình thường | bàn tính giờ (Demo) | 10 | 10 | 0 | 21 | 2 |
| Lúc mạng chập chờn | bàn thường | 497 | 496 | 1 | 8 | 19 |

- Lúc mạng chập chờn, **496/497 phiên vẫn thanh toán xong**, không chậm hơn lúc bình thường. Chập chờn ở quán là ngắn (vài giây tới vài phút), app thử lại / nhân viên bấm lại là qua.
- Lỗi thanh toán thật do mạng trong 30 ngày: 2 lần ("Connection reset", "HandshakeException") + vài lần "Chưa xác định được trạng thái thanh toán" (máy chủ đối soát lại được). Không lần nào mất tiền.
- Chốt giờ bàn tính giờ lỗi: 0 (chỉ quán Demo có bàn tính giờ).

## Đề xuất

**Chưa làm chế độ dự phòng mất mạng.** Lý do: tiền giờ do máy chủ chốt; làm dự phòng nghĩa là app tự tính và ghi tiền khi mất mạng rồi đối soát sau — tốn công lớn, rủi ro lệch tiền, trong khi số liệu cho thấy chập chờn không chặn được thanh toán. Sau khi phát hành module, chạy lại `bash tool/do_mat_mang.sh 30` sau 30 ngày: nếu dòng "bàn tính giờ · lúc mạng chập chờn" có phiên chưa xong, hoặc mục 3 có lỗi mạng, thì xem lại.

## Nhật ký

- 28/11: đo 30 ngày, viết `tool/do_mat_mang.sh` (chỉ đọc, giới hạn 60 giây mỗi câu). Một câu đo đầu chạy quá 3 phút đã dừng (kiểm `pg_stat_activity` không còn chạy), viết lại cho nhẹ (~vài giây).
