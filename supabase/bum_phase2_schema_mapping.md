# Mapping Schema Kỳ Vọng & Phân Quyền Codebase POS Cho AI Bum Phase 2 (Cập Nhật V2)

> **Tệp**: `supabase/bum_phase2_schema_mapping.md`  
> **Mục đích**: Đối chiếu nguồn permission chính thức và tên cột thực tế từ codebase POS sang 10 RPC read-only của AI Bum.  
> **Trạng thái**: DRAFT FOR REVIEW ONLY.  
>
> **LƯU Ý BẮT BUỘC**:  
> Chưa được thiết kế migration/RPC cho tới khi script preflight (`supabase/preflight_bum_phase2.sql`) được chạy trực tiếp trên môi trường Staging và kết quả thực tế được đưa lại để review. All column variants listed below are marked as **Candidates** until proven by preflight.

---

## 1. Ma Trận Phân Quyền Mã Nguồn POS (Official Permission IDs)

| Phân Quyền Nghiệp Vụ | Official Permission IDs | Bảng Nghiệp Vụ Liên Quan | Candidate RPC Tool | Ghi Chú & Xử Lý Fallback |
|---|---|---|---|---|
| **Báo Cáo Doanh Thu** | `report` + `report.view` | `public.orders`, `public.order_items`, `public.products` | `bum_get_today_sales_summary`<br>`bum_compare_sales_periods`<br>`bum_get_top_products`<br>`bum_get_slow_products` | Lọc đơn hoàn thành. `bum_get_slow_products` dùng LEFT JOIN từ `products` đang `is_active = true`. |
| **Kho & Quản Lý Kho Pro** | `kho` hoặc `kho_pro` | `public.materials`, `public.recipes`, `public.production_orders`, `public.stock_movements`, `public.stock_movements_sync` | `bum_get_low_stock_items`<br>`bum_get_stock_forecast_inputs` | So sánh tồn hiện tại với định mức tồn tối thiểu (`min_stock` hoặc `reorder_point`). *(Không dùng inventory/warehouse làm permission ID chính thức)*. |
| **Chấm Công & Ca Làm** | `chamcong` | `public.staff_shifts`, `public.staff_members`, `public.staff_profiles` | `bum_get_staff_on_shift` | Loại bỏ PII (SĐT, PIN, Selfie, GPS). Trả tên nhân viên, ca làm, giờ `clock_in`/`clock_out`. |
| **Vận Hành Hàng Ngày** | `kay_ops` | `public.ops_daily_logs`, `public.ops_task_templates` | `bum_get_pending_operations_tasks` | Lọc công việc chưa hoàn thành trong ngày theo múi giờ quán. *(Không dùng ops làm permission ID chính thức)*. |
| **Tài Chính Thu - Chi** | `finance` + `finance.view_all` | `public.finance_records`, `public.finance_categories` | `bum_get_finance_summary` | Tính tổng thu, tổng chi và **dòng tiền ròng (net_cash_flow)**. *(KHÔNG gọi là lợi nhuận thuần/profit vì chưa tính giá vốn và điều chỉnh kế toán)*. |
| **Ngữ Cảnh Cửa Hàng** | Mọi thành viên cửa hàng | `public.stores`, `public.app_settings` | `bum_get_store_context_for_bum` | Trả tên cửa hàng, địa chỉ và các trí nhớ/fact đã được duyệt (`status = 'approved'`). |

---

## 2. Chi Tiết Tên Cột Đã Thấy Trong Codebase & Các Ứng Viên (Candidates)

Mọi tên cột bên dưới là **Candidate Columns** cho tới khi script preflight được chạy và trả về bằng chứng thực nghiệm từ database:

### 1. `public.orders`
- **Candidate Columns**: `total`, `status`, `created_at`
- **Fallback Candidates**: `final_amount`, `paid_amount`, `grand_total`, `store_id`

### 2. `public.order_items`
- **Candidate Columns**: `qty`, `unit_price`
- **Fallback Candidates**: `quantity`, `price`, `total_price`, `order_id`, `product_id`

### 3. `public.products`
- **Candidate Columns**: `id`, `store_id`, `name`, `sell_price`, `is_active`

### 4. `public.materials` & `public.stock_movements_sync`
- **Candidate Columns**: `id`, `store_id`, `name`, `unit`, `current_stock`, `min_stock`
- **Fallback Candidates**: `stock_movements`, `recipes`, `production_orders`

### 5. `public.finance_records` & `public.finance_categories`
- **Candidate Columns**: `recorded_at`, `amount`, `type`, `category_id`, `store_id`
- **Fallback Candidates**: `created_at`, `is_auto`
- **Thuật ngữ chuẩn**: Kết quả tính toán `tổng_thu - tổng_chi` được gọi là **dòng tiền ròng (net_cash_flow)**, không gọi là lợi nhuận thuần (net profit).

### 6. `public.staff_members` & `public.staff_profiles`
- **Candidate Columns**: `id`, `store_id`, `user_id`, `name`, `role`, `is_active`, `modules`, `actions`

### 7. `public.store_members`
- **Candidate Columns**: `id`, `store_id`, `user_id`, `role`, `is_owner`, `actions`, `permissions`
- **Lưu ý**: `is_owner` được đưa vào danh sách cần preflight kiểm tra trực tiếp.

### 8. `public.staff_shifts`
- **Candidate Columns**: `user_id`, `clock_in`, `clock_out`, `staff_id`, `status`, `store_id`
- **Fallback Candidates**: `start_time`, `end_time`, `shift_name`

### 9. `public.ops_daily_logs` & `public.ops_task_templates`
- **Candidate Columns**: `template_id`, `log_date`, `staff_id`, `staff_name`, `status`, `store_id`

### 10. `public.app_settings`
- **Candidate Columns**: `store_id`, `key`, `value`
- **Timezone Keys kiểm tra chính xác**: `timezone`, `store_timezone`, `time_zone` (Không tra cứu từ khoá rộng `%time%`).

---

## 3. Tuyên Bố Quy Trình (Process Enforcement Statement)

> [!WARNING]
> Thiết kế Migration SQL và hàm RPC chỉ được thực hiện sau khi script `supabase/preflight_bum_phase2.sql` được chạy trên môi trường Staging DB và kết quả thực tế được gửi lại để kiểm tra.
