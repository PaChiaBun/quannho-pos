import io
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "services"))

try:
    from PIL import Image
    import image_optimizer as io_mod
except ImportError:  # môi trường test không có Pillow
    Image = None


@unittest.skipIf(Image is None, "cần Pillow")
class OptimizeImageTest(unittest.TestCase):
    def _noise_jpeg(self, w, h, q=95):
        im = Image.effect_noise((w, h), 80).convert("RGB")
        buf = io.BytesIO()
        im.save(buf, format="JPEG", quality=q)
        return buf.getvalue()

    def test_big_jpeg_gets_smaller_and_resized(self):
        data = self._noise_jpeg(3000, 2000)
        out, ctype = io_mod.optimize_image(data, "a.jpg")
        im = Image.open(io.BytesIO(out))
        self.assertEqual(ctype, "image/jpeg")
        self.assertLessEqual(max(im.size), 1024)
        self.assertLess(len(out), len(data) * 0.5)

    def test_png_without_alpha_becomes_jpeg_bytes_keeping_name(self):
        im = Image.effect_noise((2000, 1500), 60).convert("RGB")
        buf = io.BytesIO()
        im.save(buf, format="PNG")
        out, ctype = io_mod.optimize_image(buf.getvalue(), "b.png")
        self.assertEqual(ctype, "image/jpeg")
        self.assertLess(len(out), len(buf.getvalue()) * 0.3)

    def test_png_with_alpha_stays_png(self):
        im = Image.new("RGBA", (1500, 1500), (255, 0, 0, 80))
        buf = io.BytesIO()
        im.save(buf, format="PNG")
        out, ctype = io_mod.optimize_image(buf.getvalue(), "c.png")
        self.assertEqual(ctype, "image/png")
        self.assertEqual(Image.open(io.BytesIO(out)).mode, "RGBA")

    def test_alpha_in_jpg_name_is_flattened_on_white(self):
        im = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
        buf = io.BytesIO()
        im.save(buf, format="PNG")
        out, ctype = io_mod.optimize_image(buf.getvalue(), "d.jpg")
        px = Image.open(io.BytesIO(out)).getpixel((10, 10))
        self.assertEqual(ctype, "image/jpeg")
        self.assertGreater(min(px), 240)  # nền trắng, không đen

    def test_webp_stays_webp(self):
        im = Image.effect_noise((2000, 1200), 70).convert("RGB")
        buf = io.BytesIO()
        im.save(buf, format="WEBP", quality=100)
        out, ctype = io_mod.optimize_image(buf.getvalue(), "e.webp")
        self.assertEqual(ctype, "image/webp")
        self.assertLessEqual(max(Image.open(io.BytesIO(out)).size), 1024)

    def test_exif_orientation_applied(self):
        im = Image.new("RGB", (400, 200), (10, 200, 10))
        exif = Image.Exif()
        exif[0x0112] = 6  # xoay 90°
        buf = io.BytesIO()
        im.save(buf, format="JPEG", exif=exif)
        out, _ = io_mod.optimize_image(buf.getvalue(), "f.jpg")
        w, h = Image.open(io.BytesIO(out)).size
        self.assertGreater(h, w)  # đã xoay đứng

    def test_corrupt_data_returns_none(self):
        self.assertIsNone(io_mod.optimize_image(b"khong phai anh", "g.jpg"))

    def test_managed_name_rule(self):
        ok = "c0b3ca0d-a19b-4cfe-901b-7319a5770c5a"
        for ext in ("jpg", "jpeg", "png", "webp", "JPG"):
            self.assertTrue(io_mod.is_managed_name("%s.%s" % (ok, ext)))
        for bad in ("logo.png", "../x.jpg", ok, ok + ".gif", "a/" + ok + ".jpg", "", None, ok + ".jpg.bak"):
            self.assertFalse(io_mod.is_managed_name(bad), bad)

    def test_gc_only_deletes_managed_unreferenced_old_objects(self):
        import datetime as dt
        old = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=100)).isoformat()
        new = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=1)).isoformat()
        u = lambda n: "%08d-0000-0000-0000-000000000000.jpg" % n
        objs = [
            {"name": u(1), "id": "1", "created_at": old, "metadata": {"size": 100}},       # rác thật → xóa
            {"name": u(2), "id": "2", "created_at": old, "metadata": {"size": 100}},       # đang được món dùng → giữ
            {"name": u(3), "id": "3", "created_at": new, "metadata": {"size": 100}},       # còn mới (<48h) → giữ
            {"name": "logo.png", "id": "4", "created_at": old, "metadata": {"size": 100}}, # tên lạ → giữ
        ]
        deleted = []

        class Fake:
            def list_objects(self): return objs
            def rest_rows(self, table, select):
                return [{"image_url": "https://x/storage/v1/object/public/product-images/" + u(2), "image_path": None}] if table == "products" else []
            def delete(self, names): deleted.extend(names)

        old_log = io_mod.DELETED_LOG
        io_mod.DELETED_LOG = os.path.join(os.environ.get("TMPDIR", "/tmp"), "qn_deleted_test.log")
        try:
            self.assertEqual(io_mod.cmd_gc(Fake(), delete=True), 0)
        finally:
            io_mod.DELETED_LOG = old_log
        self.assertEqual(deleted, [u(1)])

    def test_gc_refuses_when_products_empty(self):
        class Fake:
            def list_objects(self): return [{"name": "00000001-0000-0000-0000-000000000000.jpg", "id": "1", "created_at": "2020-01-01T00:00:00Z", "metadata": {"size": 1}}]
            def rest_rows(self, table, select): return []
            def delete(self, names): raise AssertionError("không được xóa khi không xác minh được")
        self.assertEqual(io_mod.cmd_gc(Fake(), delete=True), 2)

    def test_basename_and_state_helpers(self):
        self.assertEqual(io_mod._basename("https://x/storage/v1/object/public/product-images/abc.jpg?t=1"), "abc.jpg")
        self.assertIsNone(io_mod._basename(None))


if __name__ == "__main__":
    unittest.main()
