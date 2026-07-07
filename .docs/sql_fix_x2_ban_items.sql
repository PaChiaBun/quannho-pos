-- 1. Tạo hàm RPC gộp món nguyên tử (Atomic/Safe)
CREATE OR REPLACE FUNCTION add_session_items(
    p_store_id UUID,
    p_session_id UUID,
    p_items JSONB
) RETURNS VOID AS $$
DECLARE
    item RECORD;
    v_existing_id UUID;
    v_clean_note TEXT;
    v_clean_modifiers TEXT;
    v_product_id UUID;
    v_product_name TEXT;
    v_unit_price NUMERIC;
    v_quantity NUMERIC;
BEGIN
    -- Khóa hàng ban_sessions để đồng bộ hóa, loại bỏ race condition xuyên thiết bị
    PERFORM id FROM ban_sessions WHERE id = p_session_id FOR UPDATE;

    -- Lặp qua từng món trong mảng JSONB
    FOR item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
        "productId" UUID,
        "productName" TEXT,
        "price" NUMERIC,
        "quantity" NUMERIC,
        "note" TEXT,
        "modifiersJson" TEXT
    ) LOOP
        v_product_id := item."productId";
        v_product_name := item."productName";
        v_unit_price := item."price";
        v_quantity := item."quantity";
        v_clean_note := NULLIF(TRIM(item."note"), '');
        v_clean_modifiers := NULLIF(TRIM(item."modifiersJson"), '');

        -- Tìm dòng chưa gửi bếp (chua_gui / pending / null) có cùng sản phẩm, đơn giá, ghi chú và modifiers
        SELECT id INTO v_existing_id
        FROM ban_session_items
        WHERE session_id = p_session_id
          AND product_id = v_product_id
          AND ABS(unit_price - v_unit_price) < 0.01
          AND (
            (v_clean_note IS NULL AND (note IS NULL OR TRIM(note) = '')) OR
            (v_clean_note IS NOT NULL AND TRIM(note) = v_clean_note)
          )
          AND (
            (v_clean_modifiers IS NULL AND (modifiers_json IS NULL OR TRIM(modifiers_json) = '')) OR
            (v_clean_modifiers IS NOT NULL AND TRIM(modifiers_json) = v_clean_modifiers)
          )
          AND (kitchen_status = 'chua_gui' OR kitchen_status = 'pending' OR kitchen_status IS NULL)
        LIMIT 1;

        IF v_existing_id IS NOT NULL THEN
            -- Gộp số lượng và cập nhật subtotal
            UPDATE ban_session_items
            SET quantity = quantity + v_quantity,
                subtotal = unit_price * (quantity + v_quantity)
            WHERE id = v_existing_id;
        ELSE
            -- Thêm mới món ăn
            INSERT INTO ban_session_items (
                id, store_id, session_id, product_id, product_name,
                unit_price, quantity, subtotal, note, modifiers_json,
                added_at, kitchen_status
            ) VALUES (
                gen_random_uuid(), p_store_id, p_session_id, v_product_id, v_product_name,
                v_unit_price, v_quantity, v_unit_price * v_quantity, v_clean_note, v_clean_modifiers,
                NOW(), 'chua_gui'
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Cấp quyền thực thi cho anon và authenticated
GRANT EXECUTE ON FUNCTION add_session_items(UUID, UUID, JSONB) TO anon, authenticated;


-- 2. Dọn dẹp: gộp các dòng trùng lặp đang có sẵn trong database
WITH duplicates AS (
    SELECT 
        session_id, 
        product_id, 
        unit_price, 
        COALESCE(TRIM(note), '') as clean_note, 
        COALESCE(TRIM(modifiers_json), '') as clean_mods,
        MIN(id::text)::uuid as keep_id,
        SUM(quantity) as total_qty
    FROM ban_session_items
    WHERE (kitchen_status = 'chua_gui' OR kitchen_status = 'pending' OR kitchen_status IS NULL)
    GROUP BY session_id, product_id, unit_price, COALESCE(TRIM(note), ''), COALESCE(TRIM(modifiers_json), '')
    HAVING COUNT(*) > 1
)
UPDATE ban_session_items b
SET 
    quantity = d.total_qty,
    subtotal = b.unit_price * d.total_qty
FROM duplicates d
WHERE b.id = d.keep_id;

-- Xóa các dòng thừa sau khi đã gộp số lượng vào dòng giữ lại
DELETE FROM ban_session_items b
USING (
    SELECT 
        id,
        session_id, 
        product_id, 
        unit_price, 
        COALESCE(TRIM(note), '') as clean_note, 
        COALESCE(TRIM(modifiers_json), '') as clean_mods,
        (MIN(id::text) OVER (PARTITION BY session_id, product_id, unit_price, COALESCE(TRIM(note), ''), COALESCE(TRIM(modifiers_json), '')))::uuid as keep_id
    FROM ban_session_items
    WHERE (kitchen_status = 'chua_gui' OR kitchen_status = 'pending' OR kitchen_status IS NULL)
) sub
WHERE b.id = sub.id 
  AND b.id <> sub.keep_id
  AND (b.kitchen_status = 'chua_gui' OR b.kitchen_status = 'pending' OR b.kitchen_status IS NULL);


-- 3. Tạo unique index để ngăn chặn trùng lặp ở tầng thấp nhất
CREATE UNIQUE INDEX IF NOT EXISTS unique_session_item_draft_idx
ON ban_session_items (session_id, product_id, unit_price, COALESCE(TRIM(note), ''), COALESCE(TRIM(modifiers_json), ''))
WHERE (kitchen_status = 'chua_gui' OR kitchen_status = 'pending' OR kitchen_status IS NULL);
