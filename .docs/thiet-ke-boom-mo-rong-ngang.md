# Thiết kế: Boom mở rộng theo chiều ngang — 03/11/2026

Hai nghĩa của "mở rộng ngang", Boom cần cả hai:
- **Nhiều quán / nhiều câu hỏi hơn** → chạy thêm bản hàm, thêm máy, không phải viết lại.
- **Thêm khả năng mới** (mục số liệu mới, loại câu mới, kênh mới như bản tin / cảnh báo) → thêm một phần riêng, không sửa chồng lên phần cũ.

## Hiện trạng (sau lần 106)

| | Tốt | Chỗ nghẽn |
|---|---|---|
| Hàm `boom-chat` | Không giữ trạng thái quan trọng trong bộ nhớ: sổ hỏi đáp, hạn mức, chi phí đều ở Postgres → chạy nhiều bản song song vẫn đúng | Bộ nhớ đệm số liệu (`DEM` trong `hoi.ts`) nằm riêng từng bản → nhiều bản thì trúng ít hơn (đúng, chỉ tốn đọc DB hơn) |
| Máy chủ | — | MỘT VPS 2 CPU / 3 GB RAM chạy chung database, hàm, web. Mỗi câu "ask" đọc 2 lần RPC số bán + tới 5 mục → tải DB tăng theo số câu |
| Chi phí | Hạn mức theo người / giờ, quán / ngày, quán / tháng, trần cả hệ thống / tháng (`BOOM_*` trong `boom-ai.env`) | Trần CẢ HỆ THỐNG / tháng là con số cố định → nhiều quán sẽ chạm trần, Boom ngừng cho mọi quán |
| Mã | Đọc số tách tệp (`ky.ts`, `lay_so.ts`, `ban_hang.ts`, `hoi.ts`) | `logic.ts` 2.200 dòng: mọi dòng tính sẵn, luật, lời nhắc, kiểm bằng code gộp một tệp → thêm mục mới dễ đụng nhau |
| Mô hình | Đổi bằng biến môi trường (`BOOM_OPENAI_MODEL`, `BOOM_REASONING`) | Một nhà cung cấp, không có mô hình dự phòng khi OpenAI lỗi |
| Đo | Bộ đề 60 câu, chấm kín Claude | 3 quán mẫu (cà phê, trà sữa, bún) → không đại diện khi có thêm loại quán |

## Thiết kế đích — 4 tầng, mỗi tầng thêm "ngang" được

```
câu hỏi ─▶ [1 Đọc kỳ + quyền] ─▶ [2 Nguồn số: mỗi mục 1 tệp] ─▶ [3 Tính sẵn: mỗi mục 1 tệp] ─▶ [4 Lời nhắc + mô hình] ─▶ [5 Kiểm bằng code] ─▶ trả lời
                                                                                                         │
                                                       sổ hỏi đáp / hạn mức / chi phí / việc đã gợi ý ──┘ (Postgres, dùng chung mọi bản)
```

1. **Nguồn số theo mục** (đã gần đúng): mỗi mục (bán hàng, thu chi, kho, khách, chấm công, khuyến mãi; sau này hoá đơn điện tử, giao hàng…)
   là một tệp có 3 phần: đọc (bằng vé người hỏi), quyền xem, gói số. Thêm mục mới = thêm 1 tệp + 1 dòng đăng ký.
2. **Tính sẵn theo mục**: tách `logic.ts` thành `tinh_ban_hang.ts`, `tinh_kho.ts`, `tinh_nhan_su.ts`, `tinh_thu_chi.ts`, `tinh_khach.ts`…;
   mỗi tệp xuất các "dòng tính sẵn" + test riêng. Lời nhắc lõi (`ADVICE_PROMPT`) giữ cố định để OpenAI tính nửa giá phần đầu.
3. **Mô hình có dự phòng**: mô hình chính + mô hình dự phòng (vd gpt-4o-mini) khi lỗi / quá giờ; ghi mô hình đã dùng vào sổ.
4. **Kiểm bằng code** (`loiLapLuan`, `kiemTraLoi`) tách tệp riêng, thêm luật = thêm 1 hàm + test.
5. **Việc định kỳ** (bản tin thứ Hai, cảnh báo — chặng 5) chạy bằng hàng đợi / lịch rải theo giờ, không dồn vào giờ cao điểm bán hàng.

## Hạ tầng — làm khi có số đo, không làm trước

| Mốc (đo bằng sổ `boom_qa_log`, tải máy chủ) | Việc |
|---|---|
| Chi phí tháng chạm ~70% trần cả hệ thống | Đổi trần: tính theo số quán đang dùng / gói thay vì một con số cố định |
| CPU VPS thường > 70% giờ cao điểm, hoặc câu "ask" > 8 giây | Tách hàm Boom sang máy riêng (hàm đọc DB qua mạng, vẫn bằng vé người hỏi) |
| Postgres chậm vì đọc số cho Boom | Bản đọc (read replica) cho Boom; giữ cache 10 phút / 6 giờ dùng chung (bảng hoặc Redis) |
| Nhiều máy chạy hàm | Cân bằng tải trước các bản hàm; cache dùng chung |

## Thứ tự đề xuất

1. **Ngay** (nhỏ, máy chủ, cần duyệt): bảng theo dõi chi phí / số câu / thời gian trả lời theo ngày trên trang /admin; đặt mốc cảnh báo 70% trần.
2. **Khi làm chặng 5** (trước khi thêm tính năng mới): tách `logic.ts` theo mục — không đổi hành vi, test giữ nguyên làm lưới an toàn.
3. **Mô hình dự phòng**: cùng lúc với bước 2.
4. **Hạ tầng**: theo mốc ở bảng trên.
