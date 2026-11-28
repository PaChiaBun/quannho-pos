#!/usr/bin/env python3
"""Bộ nén ảnh món + dọn ảnh rác cho kho Supabase Storage `product-images`.

Thiết kế (Chủ Quán, 13/10/2026): cho phép tải lên ảnh bất kỳ kích thước, SAU ĐÓ tự nén nhỏ lại và dọn ảnh
không còn được món/công thức nào dùng, để kho không phình ra khi kinh doanh sinh ra rất nhiều ảnh.

  compress : tìm ảnh lớn hơn ngưỡng (mặc định 200 KB), thu nhỏ cạnh dài tối đa 1024 px, nén lại và GHI ĐÈ
             lên đúng tên cũ (đường link công khai KHÔNG đổi). Chỉ ghi đè khi nhỏ hơn rõ rệt.
  gc       : dọn ảnh rác. Mặc định chỉ BÁO CÁO; thêm --delete mới xóa thật.
             LUẬT XÓA (một tệp chỉ bị xóa khi THỎA TẤT CẢ):
               1. Nằm trong kho product-images (không bao giờ đụng kho khác).
               2. Tên đúng dạng <uuid>.(jpg|jpeg|png|webp) — tức do app sinh; tệp lạ tên khác KHÔNG xóa.
               3. Không món nào (KỂ CẢ món đã xóa mềm) và không công thức nào đang tham chiếu
                  (products.image_url / products.image_path / recipes.image_url).
               4. Đã tồn tại quá GC_GRACE_HOURS (mặc định 48 giờ) — ảnh vừa tải, người dùng còn đang sửa món thì giữ.
               5. Phải đọc được danh sách tham chiếu VÀ bảng products không rỗng; nếu không → dừng, không xóa gì.
               6. Mỗi lần xóa tối đa 30% số tệp trong kho (tối thiểu 20) — chốt chặn nếu logic sai.
               7. Mỗi tệp đã xóa được ghi vào DELETED_LOG (tên, dung lượng, ngày tải) để truy vết.

Cấu hình qua biến môi trường (dùng chung /etc/pos-jwt-gateway/gateway.env):
  SUPABASE_INTERNAL_URL | SUPABASE_URL , SUPABASE_SERVICE_ROLE_KEY
Tùy chọn: IMG_BUCKET, IMG_MAX_SIDE, IMG_JPEG_QUALITY, IMG_THRESHOLD_BYTES, IMG_MAX_PER_RUN, GC_GRACE_HOURS, IMG_STATE_FILE
"""
import io
import json
import re
import logging
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

log = logging.getLogger("image_optimizer")

BUCKET = os.environ.get("IMG_BUCKET", "product-images")
MAX_SIDE = int(os.environ.get("IMG_MAX_SIDE", "1024"))
JPEG_QUALITY = int(os.environ.get("IMG_JPEG_QUALITY", "78"))
THRESHOLD = int(os.environ.get("IMG_THRESHOLD_BYTES", "200000"))
MAX_PER_RUN = int(os.environ.get("IMG_MAX_PER_RUN", "50"))
GC_GRACE_HOURS = float(os.environ.get("GC_GRACE_HOURS", "48"))
MIN_AGE_SECONDS = int(os.environ.get("IMG_MIN_AGE_SECONDS", "20"))
STATE_FILE = os.environ.get("IMG_STATE_FILE", "/var/lib/quannho-image-optimizer/state.json")
DELETED_LOG = os.environ.get("IMG_DELETED_LOG", "/var/lib/quannho-image-optimizer/deleted.log")
MIN_SAVING_RATIO = 0.9  # chỉ ghi đè khi ảnh mới nhỏ hơn ít nhất 10%


# ───────────────────────── Xử lý ảnh (thuần, kiểm thử được) ─────────────────────────
def optimize_image(data, name, max_side=None, quality=None):
    """Trả (bytes_mới, content_type) hoặc None nếu không đọc được ảnh."""
    from PIL import Image, ImageOps

    max_side = max_side or MAX_SIDE
    quality = quality or JPEG_QUALITY
    try:
        im = Image.open(io.BytesIO(data))
        im.load()
    except Exception as exc:  # tệp hỏng / không phải ảnh / quá lớn
        log.warning("Không đọc được ảnh %s: %s", name, exc)
        return None

    try:
        im = ImageOps.exif_transpose(im)  # xoay đúng chiều theo EXIF (ảnh chụp điện thoại)
    except Exception:
        pass

    ext = name.rsplit(".", 1)[-1].lower() if "." in name else "jpg"
    has_alpha = im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info)

    w, h = im.size
    if max(w, h) > max_side:
        im.thumbnail((max_side, max_side), Image.LANCZOS)

    out = io.BytesIO()
    if ext == "png" and has_alpha:
        # Ảnh có nền trong suốt: giữ PNG (đã thu nhỏ + tối ưu)
        im.convert("RGBA").save(out, format="PNG", optimize=True)
        return out.getvalue(), "image/png"
    if has_alpha:
        bg = Image.new("RGB", im.size, (255, 255, 255))
        rgba = im.convert("RGBA")
        bg.paste(rgba, mask=rgba.split()[-1])
        im = bg
    elif im.mode != "RGB":
        im = im.convert("RGB")

    if ext == "webp":
        im.save(out, format="WEBP", quality=quality, method=6)
        return out.getvalue(), "image/webp"
    # jpg / jpeg / png không trong suốt → JPEG (tên tệp giữ nguyên để link không đổi)
    im.save(out, format="JPEG", quality=quality, optimize=True, progressive=True)
    return out.getvalue(), "image/jpeg"


# ───────────────────────── Gọi Supabase ─────────────────────────
class Api:
    def __init__(self, base_url, service_key):
        self.base = base_url.rstrip("/")
        self.key = service_key

    def _req(self, method, path, body=None, headers=None, timeout=60, raw=False):
        h = {"apikey": self.key, "Authorization": "Bearer " + self.key}
        if headers:
            h.update(headers)
        req = urllib.request.Request(self.base + path, data=body, method=method, headers=h)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = resp.read()
            if raw:
                return data
            return json.loads(data) if data else None

    def list_objects(self):
        out, offset = [], 0
        while True:
            body = json.dumps({"prefix": "", "limit": 100, "offset": offset,
                               "sortBy": {"column": "created_at", "order": "asc"}}).encode()
            page = self._req("POST", "/storage/v1/object/list/" + BUCKET, body,
                             {"Content-Type": "application/json"})
            if not page:
                break
            out.extend(o for o in page if o.get("name") and o.get("id"))  # bỏ "thư mục"
            if len(page) < 100:
                break
            offset += 100
        return out

    def download(self, name):
        return self._req("GET", "/storage/v1/object/authenticated/%s/%s" % (BUCKET, urllib.parse.quote(name)), raw=True, timeout=120)

    def replace(self, name, data, content_type):
        self._req("POST", "/storage/v1/object/%s/%s" % (BUCKET, urllib.parse.quote(name)), data,
                  {"Content-Type": content_type, "x-upsert": "true", "cache-control": "max-age=31536000"}, timeout=120)

    def delete(self, names):
        body = json.dumps({"prefixes": names}).encode()
        self._req("DELETE", "/storage/v1/object/" + BUCKET, body, {"Content-Type": "application/json"})

    def rest_rows(self, table, select):
        rows, offset, page = [], 0, 1000
        while True:
            q = "/rest/v1/%s?select=%s&limit=%d&offset=%d" % (table, select, page, offset)
            part = self._req("GET", q)
            rows.extend(part)
            if len(part) < page:
                break
            offset += page
        return rows


_MANAGED_NAME = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$", re.IGNORECASE)


def is_managed_name(name):
    """Luật 2: chỉ tệp do app sinh (<uuid>.jpg|jpeg|png|webp) mới được phép bị dọn."""
    return bool(name) and bool(_MANAGED_NAME.match(name))


def _basename(url):
    if not url:
        return None
    return urllib.parse.unquote(str(url).split("?")[0].rstrip("/").split("/")[-1]) or None


def referenced_names(api):
    """Tên tệp trong kho được món/công thức tham chiếu. Lỗi → ném ngoại lệ (không bao giờ đoán)."""
    names = set()
    product_rows = api.rest_rows("products", "image_url,image_path")
    if not product_rows:  # luật 5: bảng products rỗng là bất thường → không đoán
        raise RuntimeError("bảng products trả về 0 dòng")
    for r in product_rows:
        for k in ("image_url", "image_path"):
            if r.get(k) and BUCKET in str(r[k]):
                names.add(_basename(r[k]))
            elif r.get(k) and k == "image_path":
                names.add(_basename(r[k]))
    for r in api.rest_rows("recipes", "image_url"):
        if r.get("image_url") and BUCKET in str(r["image_url"]):
            names.add(_basename(r["image_url"]))
    names.discard(None)
    return names


def _load_state():
    try:
        with open(STATE_FILE) as f:
            s = json.load(f)
            s.setdefault("done", {})
            s.setdefault("failed", {})
            return s
    except Exception:
        return {"done": {}, "failed": {}}


def _save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE_FILE)


def _age_seconds(obj):
    ts = obj.get("created_at") or obj.get("updated_at")
    if not ts:
        return 10 ** 9
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return (datetime.now(timezone.utc) - dt).total_seconds()
    except Exception:
        return 10 ** 9


# ───────────────────────── Lệnh ─────────────────────────
def cmd_compress(api):
    state = _load_state()
    objs = api.list_objects()
    todo = []
    for o in objs:
        name = o["name"]
        size = int((o.get("metadata") or {}).get("size") or 0)
        if size <= THRESHOLD or name in state["done"] or name in state["failed"]:
            continue
        if _age_seconds(o) < MIN_AGE_SECONDS:
            continue
        todo.append((name, size))
    log.info("Kho %s: %d tệp, %d tệp cần nén (> %d KB)", BUCKET, len(objs), len(todo), THRESHOLD // 1000)
    saved_total = 0
    for name, size in todo[:MAX_PER_RUN]:
        try:
            data = api.download(name)
            res = optimize_image(data, name)
            if res is None:
                state["failed"][name] = "không đọc được ảnh"
                continue
            new, ctype = res
            if len(new) >= len(data) * MIN_SAVING_RATIO:
                state["done"][name] = len(data)  # đã đủ nhỏ, không nén thêm
                log.info("Giữ nguyên %s (%d KB → %d KB không đáng kể)", name, len(data) // 1000, len(new) // 1000)
                continue
            api.replace(name, new, ctype)
            state["done"][name] = len(new)
            saved_total += len(data) - len(new)
            log.info("Nén %s: %d KB → %d KB", name, len(data) // 1000, len(new) // 1000)
        except Exception as exc:
            state["failed"][name] = str(exc)[:120]
            log.error("Lỗi khi nén %s: %s", name, exc)
    _save_state(state)
    log.info("Xong: tiết kiệm %d KB", saved_total // 1000)
    return 0


def cmd_gc(api, delete):
    objs = api.list_objects()
    try:
        refs = referenced_names(api)
    except Exception as exc:
        log.error("KHÔNG đọc được danh sách ảnh đang dùng (%s) → dừng, không xóa gì", exc)
        return 2
    cutoff = GC_GRACE_HOURS * 3600
    orphans = [o for o in objs
               if is_managed_name(o["name"]) and o["name"] not in refs and _age_seconds(o) > cutoff]
    skipped_foreign = [o["name"] for o in objs if not is_managed_name(o["name"])]
    if skipped_foreign:
        log.info("Bỏ qua %d tệp tên lạ (không do app sinh), không bao giờ xóa: %s", len(skipped_foreign), skipped_foreign[:5])
    total_size = sum(int((o.get("metadata") or {}).get("size") or 0) for o in orphans)
    log.info("Kho %s: %d tệp, %d đang được dùng, %d ảnh rác (> %.0f giờ, tổng %d KB)",
             BUCKET, len(objs), len(refs), len(orphans), GC_GRACE_HOURS, total_size // 1000)
    for o in orphans[:200]:
        log.info("  rác: %s (%d KB, %s)", o["name"], int((o.get("metadata") or {}).get("size") or 0) // 1000, o.get("created_at"))
    if not delete or not orphans:
        if orphans:
            log.info("Chế độ BÁO CÁO: chưa xóa. Thêm --delete để xóa.")
        return 0
    cap = max(20, int(len(objs) * 0.3))  # chốt chặn: mỗi lần không xóa quá 30% kho
    chosen = orphans[:cap]
    batch = [o["name"] for o in chosen]
    api.delete(batch)
    try:
        os.makedirs(os.path.dirname(DELETED_LOG), exist_ok=True)
        with open(DELETED_LOG, "a") as f:
            now = datetime.now(timezone.utc).isoformat(timespec="seconds")
            for o in chosen:
                f.write("%s\t%s\t%s\t%s\n" % (now, o["name"], (o.get("metadata") or {}).get("size", "?"), o.get("created_at")))
    except Exception as exc:
        log.warning("Không ghi được %s: %s", DELETED_LOG, exc)
    log.info("Đã xóa %d ảnh rác (xem %s)", len(batch), DELETED_LOG)
    return 0


def main(argv):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    if len(argv) < 2 or argv[1] not in ("compress", "gc"):
        print(__doc__)
        return 1
    base = os.environ.get("SUPABASE_INTERNAL_URL") or os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not base or not key:
        log.error("Thiếu SUPABASE_INTERNAL_URL/SUPABASE_URL hoặc SUPABASE_SERVICE_ROLE_KEY")
        return 1
    api = Api(base, key)
    try:
        if argv[1] == "compress":
            return cmd_compress(api)
        return cmd_gc(api, delete="--delete" in argv)
    except urllib.error.HTTPError as exc:
        log.error("Lỗi HTTP %s khi gọi Supabase: %s", exc.code, exc.reason)
        return 3
    except Exception as exc:
        log.error("Lỗi: %s", exc)
        return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv))
