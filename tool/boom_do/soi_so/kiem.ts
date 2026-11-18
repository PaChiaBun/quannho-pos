// Bộ kiểm bất biến trên KHỐI SỐ Boom gửi cho mô hình (kế hoạch .docs/ke-hoach-tinh-chinh-boom-18-11.md, giai đoạn 1).
// So các câu chữ trong khối với SỐ THẬT đọc thẳng từ hàm máy chủ; không gọi mô hình, không cần mã Boom.
// Mỗi mã K… ứng một loại lỗi đã gặp thật trên quán Bò Đen 16–18/11 (lần 250–254).

/** Số thật của kỳ đang hỏi. */
export type Thuc = {
  revenue: number;
  orders: number;
  by_hour: number[];
  by_weekday: number[]; // Thứ 2 … Chủ nhật
  ngay: { d: string; revenue: number; orders: number }[]; // chỉ các ngày CÓ đơn
  homNay: string | null; // ngày còn đang dở nếu kỳ kết thúc hôm nay
  truocDon: number | null; // số đơn kỳ so sánh; null = không đọc được
  nhom: { ten: string; mon: number; chuaBan: number }[]; // mỗi nhóm: số món, số món 0 phần
};
/** `trungTen`: số món trong MENU cùng mang tên gọi tắt trong câu (≥ 2 thì khối số không được tự chọn một món). */
export type Cau = { q: string; mongKy?: RegExp; soSanh?: boolean; canGia?: boolean; trungTen?: number };

const so = (x: string) => +x.replace(/\./g, '');
const THU = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
const thuCua = (d: string) => (new Date(`${d}T00:00:00Z`).getUTCDay() + 6) % 7;
const tien = (x: number) => `${Math.round(x).toLocaleString('vi-VN')}đ`;
const lech = (a: number, b: number) => (b > 0 ? Math.abs(a - b) / b : a > 0 ? 1 : 0);

export function kiem(cau: Cau, nhanKy: string, khoi: string, t: Thuc): string[] {
  const loi: string[] = [];
  const tronNgay = t.ngay.filter((x) => x.d !== t.homNay);
  // trung bình thật của mỗi thứ: chỉ ngày có đơn đã trọn
  const tb = THU.map((_, k) => { const ds = tronNgay.filter((x) => thuCua(x.d) === k); return ds.length ? ds.reduce((a, x) => a + x.revenue, 0) / ds.length : null; });

  // K1: các nguồn số phải khớp nhau (lệch thì mọi dòng tính sẵn phía sau đều đáng ngờ)
  const tongGio = t.by_hour.reduce((a, b) => a + b, 0), tongThu = t.by_weekday.reduce((a, b) => a + b, 0), tongNgay = t.ngay.reduce((a, x) => a + x.revenue, 0);
  if (t.revenue > 0) {
    if (lech(tongGio, t.revenue) > 0.01) loi.push(`K1 nguồn số: tổng theo giờ ${tien(tongGio)} lệch doanh thu ${tien(t.revenue)}`);
    if (lech(tongThu, t.revenue) > 0.01) loi.push(`K1 nguồn số: tổng theo thứ ${tien(tongThu)} lệch doanh thu ${tien(t.revenue)}`);
    if (t.ngay.length && lech(tongNgay, t.revenue) > 0.01) loi.push(`K1 nguồn số: tổng theo ngày ${tien(tongNgay)} lệch doanh thu ${tien(t.revenue)}`);
  }

  // K2: trung bình theo thứ phải là trung bình các ngày CÓ đơn (lần 251: chia cả ngày quán nghỉ → "chỉ bằng 50% ngày thường")
  for (const m of khoi.matchAll(/(Thứ [2-7]|Chủ nhật) [\d.]+đ \((\d+) ngày, trung bình (?:\d+ ngày đã trọn )?([\d.]+)đ\/ngày/g)) {
    const k = THU.indexOf(m[1]), dung = tb[k];
    if (dung !== null && lech(so(m[3]), dung) > 0.03) loi.push(`K2 theo thứ: ${m[1]} ghi trung bình ${m[3]}đ/ngày (${m[2]} ngày), ngày có đơn thật cho ${tien(dung)}/ngày`);
  }
  // K3: gọi một thứ là "bất thường" khi theo ngày có đơn nó không dưới 60% trung vị
  const bt = /Bất thường \(tính sẵn\): ([^\n]*)/.exec(khoi)?.[1];
  if (bt) {
    const co = tb.filter((x): x is number => x !== null).sort((a, b) => a - b), giua = co.length ? (co.length % 2 ? co[co.length >> 1] : (co[(co.length >> 1) - 1] + co[co.length >> 1]) / 2) : 0;
    for (const m of bt.matchAll(/(Thứ [2-7]|Chủ nhật) trung bình/g)) {
      const dung = tb[THU.indexOf(m[1])];
      if (dung !== null && giua > 0 && dung >= giua * 0.6) loi.push(`K3 bất thường: ${m[1]} bị gọi yếu bất thường, nhưng theo ngày có đơn là ${tien(dung)}/ngày = ${Math.round((dung / giua) * 100)}% ngày giữa`);
    }
  }

  // K4: giờ "vắng nhất" không được là giờ đơn lẻ dưới 1% doanh thu (lần 252: 11h có 1 đơn / 18 ngày)
  const vang = /vắng nhất \([^)]*\): ([^.\n]*)\./.exec(khoi)?.[1];
  if (vang && tongGio > 0) {
    for (const m of vang.matchAll(/(\d{1,2})h/g)) {
      const p = (t.by_hour[+m[1]] ?? 0) / tongGio;
      if (p < 0.01) loi.push(`K4 giờ vắng: ${m[1]}h bị xếp vắng nhất nhưng chỉ chiếm ${(p * 100).toFixed(1).replace('.', ',')}% doanh thu (đơn lẻ, không phải giờ bán)`);
    }
  }

  // K5: "N món chưa bán" không được gồm cả một nhóm không bán món nào (lần 250: 13 món nhóm Nguyên liệu)
  const cb = /(\d+) món chưa bán phần nào trong kỳ/.exec(khoi);
  if (cb && +cb[1] > 0) {
    const chet = t.nhom.filter((g) => g.mon >= 3 && g.chuaBan === g.mon), nChet = chet.reduce((a, g) => a + g.chuaBan, 0), nTat = t.nhom.reduce((a, g) => a + g.chuaBan, 0);
    if (nChet > 0 && +cb[1] > nTat - nChet) loi.push(`K5 món chưa bán: ghi ${cb[1]} món, trong đó có cả nhóm ${chet.map((g) => `"${g.ten}" (${g.mon} món, không bán món nào)`).join(', ')} — nhóm này có phải món bán?`);
  }

  // K6: số ngày mở bán không được lớn hơn số ngày có đơn (lần 251, 254: 576 đơn chia 18 rồi 16 ngày, đúng 15)
  const nNgay = t.ngay.length;
  if (nNgay > 0) {
    const mo = /CẢ KỲ (\d+) ngày mở bán/.exec(khoi);
    if (mo && +mo[1] > nNgay) loi.push(`K6 số ngày: ghi ${mo[1]} ngày mở bán, sổ có ${nNgay} ngày có đơn`);
    const dm = /khoảng (\d+) đơn mỗi ngày mở bán/.exec(khoi), dung = Math.round(t.orders / nNgay);
    if (dm && dung - +dm[1] >= 1 && lech(+dm[1], dung) > 0.03) loi.push(`K6 số ngày: ghi khoảng ${dm[1]} đơn mỗi ngày mở bán, ${t.orders} đơn ÷ ${nNgay} ngày có đơn = ${dung}`);
  }

  // K7: câu hỏi mẫu phải ra đúng loại kỳ (lần 251: "ngày nào trong tuần yếu nhất" ra Tuần này)
  if (cau.mongKy && !cau.mongKy.test(nhanKy)) loi.push(`K7 kỳ: câu "${cau.q}" ra kỳ "${nhanKy}", mong ${cau.mongKy}`);

  // K8: kỳ so sánh 0 đơn phải được nói rõ (lần 253: "chưa có doanh thu tuần trước")
  if (cau.soSanh && t.truocDon === 0 && t.orders > 0 && !khoi.includes('KỲ SO SÁNH KHÔNG CÓ ĐƠN')) loi.push('K8 kỳ so sánh: kỳ so sánh có 0 đơn nhưng khối số không nói gì');

  // K9: câu tăng giá gọi tắt tên món phải có dòng kịch bản tính sẵn (lần 253)
  if (cau.canGia && !khoi.includes('KỊCH BẢN TĂNG GIÁ')) loi.push(`K9 tăng giá: câu "${cau.q}" không ra dòng kịch bản tăng giá`);
  const chon = /KỊCH BẢN TĂNG GIÁ[^\n]*?món "([^"]+)"/.exec(khoi)?.[1];
  if ((cau.trungTen ?? 0) >= 2 && chon) loi.push(`K9 tăng giá: câu "${cau.q}" ứng ${cau.trungTen} món trong menu nhưng khối số tự tính cho "${chon}"`);

  // K10: dự báo cả tháng không nhỏ hơn số đã có; nhãn trung bình trong dòng dự báo phải khớp trung bình thật
  const db = /Dự báo cả tháng[^\n]*?: khoảng ([\d.]+)đ \(đã có ([\d.]+)đ/.exec(khoi);
  if (db && so(db[1]) < so(db[2])) loi.push(`K10 dự báo: dự báo ${db[1]}đ nhỏ hơn số đã có ${db[2]}đ`);
  const dongDb = /Dự báo cả tháng \(([^\n]*?)\): khoảng/.exec(khoi)?.[1] ?? '';
  for (const m of dongDb.matchAll(/(Thứ [2-7]|Chủ nhật) \(trung bình ([\d.]+)đ\/ngày\)/g)) {
    const dung = tb[THU.indexOf(m[1])];
    if (dung !== null && lech(so(m[2]), dung) > 0.03) loi.push(`K10 dự báo: nhãn ${m[1]} ghi ${m[2]}đ/ngày, ngày có đơn thật cho ${tien(dung)}/ngày`);
  }
  return loi;
}
