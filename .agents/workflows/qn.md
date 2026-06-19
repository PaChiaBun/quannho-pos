---
description: Nạp toàn bộ context dự án Quán Nhỏ POS vào đầu hội thoại
---

# Workflow: /qn — Context Quán Nhỏ POS

Khi user gọi `/qn`, thực hiện các bước sau **theo thứ tự**:

## Bước 1 — Đọc tổng quan dự án
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/tong-quan.md`

## Bước 2 — Đọc kiến trúc kỹ thuật
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/kien-truc.md`

## Bước 3 — Đọc kiến trúc data toàn hệ thống
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/kien-truc-data.md`
Đây là tài liệu quan trọng nhất về luồng data — đọc kỹ trước khi dev bất kỳ module nào.
Bao gồm: schema Supabase, luồng từng module, quy tắc vàng, thông tin kết nối.

> **⚠️ Lưu ý kiến trúc (cập nhật 2026-05-02):**
> Toàn bộ UI layer đã migration **100% sang Supabase** — không còn Drift/SQLite trong screens.
> - `pos_screen`, `ban_screen`, `inventory_screen` → dùng Repository pattern (Supabase)
> - Timestamp: **ISO 8601 String** (không phải epoch int) — luôn dùng `DateTime.parse()`
> - Các file dead code: `ban_sync_service.dart`, `product_sync_service.dart`, `app_event_bus.dart` — đã deprecated, có thể xóa

## Bước 4 — Đọc tính năng & modules
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/tinh-nang.md`

## Bước 5 — Đọc phong cách làm việc & thiết kế
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/lam-viec.md`
Sau khi đọc, ghi nhớ và áp dụng các nguyên tắc này trong suốt hội thoại.
Bao gồm: quy tắc làm việc, nguyên tắc code, thiết kế UI, responsive rules.

## Bước 6 — Đọc nhật ký công việc
Đọc file: `/Users/banhbao/Quan Nho/quan_nho/.docs/nhat-ky.md`
Ghi nhớ mục **"Tiếp theo"** của ngày gần nhất — đây là context quan trọng nhất.

## Bước 7 — Báo cáo
Sau khi đọc xong, tóm tắt ngắn gọn cho user biết:
- Đang làm dự án gì
- Các module chính
- Ngày làm gần nhất đang ở đâu (từ nhật ký)
- Trạng thái kiến trúc hiện tại (Supabase migration status)
- Hỏi user muốn làm gì tiếp theo
