// Trời GIẢ cho đo và kiểm thử (09/11, kế hoạch tư vấn thời tiết): viết tay theo dạng ThoiTiet, KHÔNG phải dữ liệu Apple.
import type { ThoiTiet } from '../../thoi_tiet.ts';
type Ngay = { cao: number; thap: number; mua: number; troi: string; muaGio?: [number, number, number] }; // [từ, đến, % đỉnh]
export function troiGia(tu: string, ds: Ngay[], nhietNay = 31): ThoiTiet {
  const t0 = Date.parse(`${tu}T00:00:00Z`);
  const ngay = ds.map((d, i) => ({ ngay: new Date(t0 + i * 86_400_000).toISOString().slice(0, 10), cao: d.cao, thap: d.thap, mua: d.mua, troi: d.troi }));
  const gio_tuan = ds.flatMap((d, i) => Array.from({ length: 24 }, (_, g) => {
    const [a, b, p] = d.muaGio ?? [0, 0, 0];
    const mua = g >= a && g < b ? Math.max(20, p - Math.abs(g - (a + b - 1) / 2) * 12) : 5;
    const nhiet = Math.round(d.thap + (d.cao - d.thap) * (g < 5 || g > 21 ? 0 : g <= 14 ? (g - 5) / 9 : (21 - g) / 7));
    return { ngay: ngay[i].ngay, gio: g, nhiet, mua: Math.round(mua), troi: mua >= 40 ? 'mưa' : 'nhiều mây' };
  }));
  return { luc: `${tu}T02:00:00.000Z`, nhiet: nhietNay, troi: 'nhiều mây', gio: gio_tuan.slice(9, 21).map(({ ngay: _, ...h }) => h), ngay, gio_tuan };
}
// 3 kiểu trời, tuần bắt đầu Thứ Tư 28/10/2026 (NOW của bộ đo: 28/10 9h)
const NANG = { cao: 33, thap: 25, mua: 15, troi: 'nhiều mây' };
export const TROI: Record<string, ThoiTiet> = {
  mua_chieu: troiGia('2026-10-28', [
    { cao: 33, thap: 25, mua: 30, troi: 'nhiều mây', muaGio: [16, 18, 35] },
    { cao: 31, thap: 25, mua: 80, troi: 'mưa', muaGio: [15, 20, 75] },
    { cao: 32, thap: 25, mua: 55, troi: 'mưa', muaGio: [17, 21, 60] },
    { cao: 31, thap: 25, mua: 70, troi: 'dông', muaGio: [17, 21, 70] },
    { cao: 32, thap: 25, mua: 65, troi: 'mưa', muaGio: [16, 21, 65] },
    NANG,
    NANG,
  ]),
  mua_sang: troiGia('2026-10-28', [
    { cao: 30, thap: 24, mua: 60, troi: 'mưa', muaGio: [5, 10, 70] },
    { cao: 29, thap: 24, mua: 85, troi: 'mưa to', muaGio: [6, 12, 85] },
    { cao: 29, thap: 24, mua: 75, troi: 'mưa', muaGio: [6, 11, 75] },
    { cao: 30, thap: 24, mua: 70, troi: 'mưa', muaGio: [10, 14, 70] },
    { cao: 30, thap: 24, mua: 65, troi: 'mưa', muaGio: [6, 10, 65] },
    { cao: 31, thap: 25, mua: 60, troi: 'mưa', muaGio: [11, 14, 60] },
    { cao: 31, thap: 25, mua: 50, troi: 'mưa', muaGio: [7, 10, 50] },
  ], 27),
  nang_nong: troiGia('2026-10-28', Array.from({ length: 7 }, (_, i) => ({ cao: 35 + (i % 3), thap: 27, mua: 5, troi: 'nắng nóng' })), 34),
};
