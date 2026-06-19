# 🧠 Kiến Trúc Memory System của Bum

---

## Vấn Đề: Memory Dài Hạn Tốn Token

Gửi toàn bộ lịch sử chat mỗi lần → rất nặng token, chậm, tốn tiền.

**Giải pháp: Compressed Memory Pattern**

---

## Kiến Trúc 3 Tầng

```
┌─────────────────────────────────────────────────┐
│  TẦNG 1: System Context (inject mỗi request)    │
│  - Ai_Bum.md (tổng quan modules)               │
│  - tinh-cach-bum.md (tính cách)                │
│  - xu-ly-data.md (data quán hiện tại)          │
│  → ~1,500 tokens                               │
├─────────────────────────────────────────────────┤
│  TẦNG 2: Long-term Memory Snippets              │
│  - Tóm tắt từ các cuộc hội thoại cũ           │
│  - Milestone quán đã đạt                       │
│  - Vấn đề thường gặp của quán này              │
│  → ~500 tokens (tối đa)                        │
├─────────────────────────────────────────────────┤
│  TẦNG 3: Recent Context (full messages)         │
│  - 15 tin nhắn gần nhất (7-8 lượt hỏi đáp)    │
│  → ~1,000–2,000 tokens                         │
└─────────────────────────────────────────────────┘
Tổng: ~3,000–4,000 tokens/request (tiết kiệm 70% so với full history)
```

---

## Cách Tạo Memory Snippets

Sau mỗi cuộc hội thoại kết thúc (user đóng chat hoặc sau 30 phút không hoạt động):

1. Gửi toàn bộ cuộc hội thoại cho GPT với prompt:
   > *"Tóm tắt cuộc hội thoại này thành tối đa 5 điểm quan trọng mà Bum cần nhớ về quán này. Chỉ giữ thông tin có giá trị dài hạn."*

2. Lưu kết quả vào database (Supabase) với `store_id` + `created_at`

3. Lần sau khi user mở chat → load 10 snippets gần nhất → inject vào system prompt

---

## Cấu Trúc Database Memory

```sql
-- Bảng lưu memory snippets
bum_memories (
  id          uuid PRIMARY KEY,
  store_id    uuid REFERENCES stores(id),
  user_id     uuid,             -- null = memory của cả quán
  content     text,             -- nội dung snippet
  category    text,             -- 'milestone' | 'issue' | 'preference' | 'general'
  created_at  timestamptz,
  importance  int DEFAULT 5     -- 1-10, dùng để filter khi quá nhiều
)
```

---

## Loại Memory Cần Lưu

| Category | Ví dụ |
|----------|-------|
| `milestone` | "Quán đạt 500 đơn vào 15/03/2026" |
| `issue` | "Chủ quán hay hỏi về báo cáo cuối tháng" |
| `preference` | "Chủ quán thích xem data theo tuần, không theo ngày" |
| `general` | "Quán có 5 nhân viên, 3 khu vực bàn" |

---

## Token Budget Ước Tính (GPT-4o-mini)

| Thành phần | Tokens | Chi phí/request |
|-----------|--------|-----------------|
| System context | ~1,500 | $0.0002 |
| Memory snippets | ~500 | $0.00007 |
| Recent messages | ~1,500 | $0.0002 |
| Response | ~500 | $0.0002 |
| **Tổng** | **~4,000** | **~$0.0007** |

> 1,000 lượt chat/tháng ≈ $0.7 — rất tiết kiệm với GPT-4o-mini.

---

## Thứ Tự Inject Vào System Prompt

```
[SYSTEM PROMPT]
{nội dung Ai_Bum.md}
{nội dung tinh-cach-bum.md}

[DATA QUÁN HÔM NAY]
{nội dung từ xu-ly-data.md với data thực}

[KÝ ỨC BUM VỀ QUÁN NÀY]
{10 memory snippets gần nhất, theo importance}

[LỊCH SỬ HỘI THOẠI GẦN ĐÂY]
{15 tin nhắn cuối}
```
