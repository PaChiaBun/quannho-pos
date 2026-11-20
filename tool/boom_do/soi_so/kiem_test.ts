// Tự kiểm bộ bất biến bằng số dựng lại của Bò Đen 18/11 (không đọc mạng). Chạy: deno test kiem_test.ts
import { assert, assertEquals } from 'jsr:@std/assert@1';
import { kiem, type Thuc } from './kiem.ts';

const gio = Array(24).fill(0);
Object.entries({ 11: 117000, 12: 150000, 14: 1381000, 16: 404000, 17: 387000, 18: 3431000, 19: 10896600, 20: 15829500, 21: 13472000, 22: 9215300, 23: 1964000 }).forEach(([h, v]) => (gio[+h] = v));
const ngay = ([['01', 3636333], ['02', 3481000], ['03', 4019000], ['04', 3532300], ['05', 4176750], ['06', 4191150], ['07', 5043000], ['08', 3636333], ['11', 3532300], ['12', 4176750], ['13', 4191150], ['14', 5043000], ['15', 3636334], ['16', 3102000], ['17', 1850000]] as [string, number][])
  .map(([d, revenue]) => ({ d: `2026-11-${d}`, revenue, orders: 38 }));
const T: Thuc = { revenue: 57247400, orders: 576, by_hour: gio, by_weekday: [6583000, 5869000, 7064600, 8353500, 8382300, 10086000, 10909000], ngay, homNay: '2026-11-18', truocDon: 0,
  nhom: [{ ten: 'Đồ uống', mon: 9, chuaBan: 0 }, { ten: 'Nguyên liệu', mon: 13, chuaBan: 13 }] };
const ma = (xs: string[]) => [...new Set(xs.map((x) => x.split(' ')[0]))].sort().join(' ');

Deno.test('khối số kiểu bản cũ: bắt đủ các lỗi lần 250–254', () => {
  const cu = [
    'HỒ SƠ QUÁN (tự suy từ số liệu): khoảng 32 đơn mỗi ngày mở bán',
    'Menu đang bán 34 món, 13 món chưa bán phần nào trong kỳ.',
    'Doanh thu theo giờ trong kỳ (chỉ giờ có bán): 11h 117.000đ; 20h 15.829.500đ. Đông nhất: 20h, 21h, 19h; vắng nhất (trong giờ có bán): 11h, 12h, 17h.',
    'Doanh thu theo thứ (tổng trong kỳ): Thứ 2 6.583.000đ (3 ngày, trung bình 2.194.333đ/ngày); Thứ 3 5.869.000đ (3 ngày, trung bình 1.956.333đ/ngày); Thứ 5 8.353.500đ (2 ngày, trung bình 4.176.750đ/ngày).',
    'Bất thường (tính sẵn): Thứ 3 trung bình 1.956.333đ/ngày, chỉ bằng 50% một ngày bình thường (3.906.542đ).',
    'Dự báo cả tháng (tính sẵn theo trung bình từng thứ, còn 12 ngày: 2 Thứ 2 (trung bình 2.194.333đ/ngày), Thứ 4 (trung bình 2.354.867đ/ngày)): khoảng 104.751.467đ (đã có 57.247.400đ + ước 47.504.067đ).',
    'Món bán chạy theo khung giờ (số phần CẢ KỲ 18 ngày mở bán, không phải số một ngày): tối: Trà sữa 400.',
  ].join('\n');
  assertEquals(ma(kiem({ q: 'so tháng trước', soSanh: true, canGia: true, mongKy: /^Tháng này/ }, 'Tuần này (từ thứ Hai 16/11)', cu, T)), 'K10 K2 K3 K4 K5 K6 K7 K8 K9');
});

Deno.test('khối số đúng: không cảnh báo; giờ vắng nằm trong giờ bán chính không bị bắt', () => {
  const moi = [
    'HỒ SƠ QUÁN (tự suy từ số liệu): khoảng 38 đơn mỗi ngày mở bán',
    'Menu đang bán 21 món, 0 món chưa bán phần nào trong kỳ.',
    'KỲ SO SÁNH KHÔNG CÓ ĐƠN (số thật từ sổ bán hàng): cùng kỳ tháng trước (1/10–18/10) quán có 0 đơn, 0đ.',
    'Doanh thu theo giờ trong kỳ (chỉ giờ có bán): 20h 15.829.500đ. Đông nhất: 20h, 21h, 19h; vắng nhất (trong giờ bán chính): 23h, 18h, 22h.',
    'Doanh thu theo thứ (tổng trong kỳ): Thứ 2 6.583.000đ (2 ngày, trung bình 3.291.500đ/ngày); Thứ 3 5.869.000đ (2 ngày, trung bình 2.934.500đ/ngày); Thứ 4 7.064.600đ (3 ngày, trung bình 2 ngày đã trọn 3.532.300đ/ngày, chưa tính hôm nay).',
    'Dự báo cả tháng (tính sẵn theo trung bình từng thứ, còn 12 ngày: 2 Thứ 2 (trung bình 3.291.500đ/ngày), Thứ 4 (trung bình 3.532.300đ/ngày)): khoảng 107.923.967đ (đã có 57.247.400đ + ước 50.676.567đ).',
    'KỊCH BẢN TĂNG GIÁ (tính sẵn): món "Trà Sữa Hong Kong Truyền Thống (Đá/Nóng)" bán 415 phần trong kỳ.',
    'Món bán chạy theo khung giờ (số phần CẢ KỲ 15 ngày mở bán, không phải số một ngày): tối: Trà sữa 400.',
  ].join('\n');
  assertEquals(kiem({ q: 'so tháng trước', soSanh: true, canGia: true, mongKy: /^Tháng này/ }, 'Tháng này (1/11–18/11)', moi, T), []);
  // tên gọi tắt ứng 2 món trong menu mà khối số tự chọn một món → cảnh báo
  assert(kiem({ q: 'tăng giá trà sữa', trungTen: 2 }, 'Tháng này (1/11–18/11)', moi, T).some((x) => x.startsWith('K9')));
  // nguồn số lệch nhau
  assert(kiem({ q: 'x' }, 'Tháng này', '', { ...T, by_hour: gio.map((v) => v / 2) }).some((x) => x.startsWith('K1')));
});
