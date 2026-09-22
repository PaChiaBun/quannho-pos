# Bảng Theo Dõi Tiến Độ QC & Review Đối Kháng (Progress Ledger)

**Vòng lặp**: Reviewer Round 1 (`reviewer@swe_light`, `qa@swe_light`)  
**Thời gian**: 2026-09-13 15:15 (+07)  
**Trạng thái chung**: ✅ Hoàn thành xuất sắc toàn bộ yêu cầu (38/38 Backend tests PASS, 5 lỗ hổng biên đã sửa, migration đa tầng hoàn tất).

---

## Bảng Kiểm Tra Điều Kiện Chấp Thuận (Acceptance Criteria Status)

| Hạng mục | Tiêu chuẩn đánh giá | Trạng thái Implementer | Trạng thái Reviewer R1 | Ghi chú kỹ thuật |
|---|---|:---:|:---:|---|
| **Kong Anon Key** | Phục hồi `supabaseAnonKey` khi reset auth, ngăn chặn Kong 401 | ✅ Pass | ✅ Pass (Đã xác minh) | `applyAuthToSupabase(null)` luôn gán anon key vào `client.rest` và `client.realtime` |
| **Onboarding Auth Application** | Đảm bảo Onboarding JWT luôn được nạp vào client trước RPC | ✅ Pass | ✅ Pass (Đã củng cố) | Bắt buộc `applyAuthToSupabase` trong cả `joinStoreByCode` và `createStore` |
| **Persistent Onboarding Storage** | Lưu trữ Onboarding JWT qua SharedPreferences, dọn sạch khi đổi token / logout | ⚠️ Khiếm khuyết | ✅ Pass (Đã sửa lỗi) | Đã sửa `storeOnboardingJwt` không lưu token hỏng, sửa `getStoredOnboardingJwtFor` tự dọn token hết hạn |
| **Fail-Closed Cleanup** | Mọi lỗi mạng, giải mã, lưu trữ đều từ chối truy cập và dọn dẹp | ⚠️ Khiếm khuyết | ✅ Pass (Đã sửa lỗi) | Bổ sung fail-closed vào `requestOnboardingJwt`, sửa lỗi bỏ sót rollback ở `requestPosJwt` |
| **Resilient RPC Fallback** | RPC đa tầng đọc `auth.uid()` kèm fallback `request.jwt.claims ->> 'sub'` | ⚠️ Thiếu sót | ✅ Pass (Đã hoàn thiện) | Áp dụng cho cả `join_store_by_code_v4` VÀ `create_store_with_owner_v4` |
| **Backend Python Tests** | 37/37 Backend Python tests chạy thực tế OK | ✅ 37/37 PASS | ✅ **38/38 PASS** | Đã bổ sung `test_23` kiểm chứng độc lập TTL 30 ngày |
| **Dev Diary Update** | Cập nhật hồ sơ nghiệm thu QC đối kháng lên `nhat_ky.md` | ⚠️ Có điểm chưa sát | ✅ Pass (Đã chuẩn hóa) | Cập nhật đầy đủ 11 rủi ro biên và phản ánh chính xác trạng thái kiểm thử |

---

## Nhật Ký Các Lần Chạy Kiểm Thử (Verification Runs)

1. **Python Backend Test Suite (37 tests ban đầu)**:
   - Lệnh: `python3 -m unittest test/backend/test_pos_jwt_auth_service.py test/backend/test_pos_gateway_server.py`
   - Kết quả: **37/37 PASS** trong 0.011s.
2. **Python Backend Test Suite (38 tests sau khi bổ sung test_23 TTL 30 ngày)**:
   - Lệnh: `python3 -m unittest test/backend/test_pos_jwt_auth_service.py test/backend/test_pos_gateway_server.py`
   - Kết quả: **38/38 PASS** trong 0.012s.
3. **Python Backend Test Suite (Re-run sau khi hoàn tất sửa code & migration)**:
   - Lệnh: `python3 -m unittest test/backend/test_pos_jwt_auth_service.py test/backend/test_pos_gateway_server.py`
   - Kết quả: **38/38 PASS** trong 0.015s.
