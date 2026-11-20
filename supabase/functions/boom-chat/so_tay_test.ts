import { assertEquals, assertStringIncludes } from 'jsr:@std/assert@1';
import * as S from './so_tay.ts';

Deno.test('sổ tay: chọn bài theo câu hỏi trước, hồ sơ sau, tối đa 2', () => {
  assertEquals(S.chonBai('gan truong thcs lam sao hut may em hoc sinh buoi trua').map((b) => b.ma)[0], 'hoc_sinh');
  assertEquals(S.chonBai('làm sao tăng doanh thu', 'Xe ki-ốt cà phê cạnh toà văn phòng').map((b) => b.ma), ['van_phong']);
  assertEquals(S.chonBai('viết bài facebook khuyến mãi tuần này').map((b) => b.ma), ['ma_giam', 'bai_dang']);
  assertEquals(S.chonBai('máy in bếp không ra phiếu'), []);
  // 08/11: chỉ câu tiếp thị mới mở bài
  assertEquals(S.chonBai('món nào bán chạy nhất', 'Xe ki-ốt cà phê cạnh toà văn phòng'), []);
  assertEquals(S.chonBai('doanh thu tháng này giảm vì sao', 'quán gần trường'), []);
  assertEquals(S.chonBai('cơm tấm bán giá vậy có lời không'), []);
  assertEquals(S.chonBai('làm sao kéo thêm khách', 'quán gần chợ').map((b) => b.ma), ['cho_cong_trinh']);
  // từ ngắn bỏ dấu không được lọt trong từ khác ("hẻm" trong "thêm", "sàn" trong "sáng")
  assertEquals(S.chonBai('buổi sáng vắng, kéo thêm khách thế nào').map((b) => b.ma).includes('dan_cu'), false);
  assertEquals(S.chonBai('buổi sáng vắng, kéo thêm khách thế nào').map((b) => b.ma).includes('mang_ve'), false);
  assertEquals(S.chonBai('giảm giá cà phê có kéo khách không').map((b) => b.ma).includes('don_tut'), false);
  assertEquals(S.chonBai('chiều vắng, ưu đãi cuối tuần sao cho đông, giữ khách quen').length, 2);
  assertStringIncludes(S.soTayChoBoom(S.chonBai('mã giảm giá')), 'KHÔNG giới hạn theo giờ');
  assertEquals(S.soTayChoBoom([]), '');
});

Deno.test('sổ tay: không khuyên việc app không làm được như việc trong app', () => {
  for (const b of S.SO_TAY) {
    const t = b.noi_dung.toLowerCase();
    if (/nhân đôi điểm|x2 điểm/.test(t)) throw new Error(`${b.ma}: nhân đôi điểm`);
    if (/app (?:gửi|nhắn) tin/.test(t) && !/không gửi/.test(t)) throw new Error(`${b.ma}: app gửi tin`);
  }
});
