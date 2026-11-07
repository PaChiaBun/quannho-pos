// Sổ tay tiếp thị theo tình huống (07/11/2026, .docs/ke-hoach-boom-bo-nho-thoi-tiet.md giai đoạn 6). THỬ NGHIỆM, chưa dùng ở Boom đang chạy.
// Mỗi bài ngắn, chỉ mở đúng bài hợp câu hỏi và hồ sơ quán. Việc trong bài phải làm được bằng app hoặc làm tay ngoài app;
// app KHÔNG có: thẻ tích ly điện tử, nhân đôi điểm, gửi tin nhắn, lọc khách lâu chưa ghé, mã giới hạn theo giờ / món / khách.
// Không ghi số tiền cụ thể của quán (số lấy từ số liệu thật); không ghi giá app.

export type BaiSoTay = { ma: string; ten: string; khi: RegExp; noi_dung: string };

const bd = (x: string) => x.normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[đĐ]/g, 'd').toLowerCase();

export const SO_TAY: BaiSoTay[] = [
  {
    ma: 'hoc_sinh', ten: 'Quán gần trường, kéo học sinh',
    khi: /hoc sinh|sinh vien|gan truong|truong (?:hoc|thcs|thpt|cap)|tan truong/,
    noi_dung: [
      'Học sinh chỉ rảnh giờ ra về, nghỉ trưa, sau giờ học thêm; đừng đặt ưu đãi lúc các em đang trong lớp. Hỏi chủ quán giờ tan trường nếu chưa biết.',
      'Tiền ít, đi theo nhóm bạn: hợp suất nhỏ giá tròn, "đi 3 người tặng 1 ly trà đá / món rẻ", không hợp giảm % trên món đắt.',
      'Món tặng phải là món giá vốn thấp; món giá vốn cao không tặng, không giảm.',
      'Nghỉ hè, nghỉ Tết lượng học sinh tụt: đừng so tháng có kỳ nghỉ với tháng đi học.',
      'Cách đo: số đơn trong khung giờ tan trường, so cùng thứ tuần trước.',
    ].join('\n'),
  },
  {
    ma: 'van_phong', ten: 'Quán gần văn phòng, khách đi làm',
    khi: /van phong|cong ty|toa nha|di lam|cong so|nhan vien van phong/,
    noi_dung: [
      'Khách chỉ đi làm ngày thường; Thứ 7, Chủ nhật vắng là bình thường, ưu đãi cuối tuần khó kéo. Ngày yếu cần lo là ngày thường yếu nhất.',
      'Họ cần nhanh: đặt trước, lấy liền, mang về; giờ cao điểm 7–9h, 11–13h. Rút thời gian chờ thường đáng tiền hơn giảm giá.',
      'Hợp: nhận đặt theo nhóm cho cả phòng (gom đơn trước 10h), giao tận tầng nếu có người; làm tay ngoài app, ghi đơn vào app như đơn thường.',
      'Buổi chiều 14–16h: đồ uống mang về cho cả phòng, mời theo nhóm.',
      'Cách đo: số đơn ngày thường, giá trị mỗi đơn giờ trưa.',
    ].join('\n'),
  },
  {
    ma: 'dan_cu', ten: 'Quán trong khu dân cư, khách gia đình',
    khi: /dan cu|khu pho|\bhem\b|gia dinh|hang xom|chung cu/,
    noi_dung: [
      'Khách quen chiếm phần lớn; giữ khách cũ đáng hơn kéo khách lạ. Cuối tuần, tối thường đông hơn ngày thường.',
      'Hợp: phần gia đình (2–4 người), món mang về cho bữa tối, nhận đặt trước qua điện thoại / Zalo làm tay.',
      'Tích điểm của app: bật "Điểm thưởng" để khách quen được trừ tiền khi thanh toán; thẻ tích ly thì dùng thẻ giấy.',
      'Cách đo: số đơn tối và cuối tuần, giá trị mỗi đơn.',
    ].join('\n'),
  },
  {
    ma: 'cho_cong_trinh', ten: 'Quán gần chợ, công trình, khách lao động',
    khi: /\bcho\b|cong trinh|tieu thuong|lao dong|binh dan|cong nhan/,
    noi_dung: [
      'Khách nhạy giá, ăn no là chính, giờ rất sớm và trưa; ít quay lại vì ưu đãi nhỏ, quay lại vì đều đặn và nhanh.',
      'Hợp: suất cố định giá tròn, thêm cơm / thêm rau không tính tiền nếu giá vốn cho phép, trà đá miễn phí; không hợp mã giảm %.',
      'Bán theo xuất cho cả nhóm thợ: nhận đặt trước buổi sáng, giao tận công trình nếu gần (làm tay).',
      'Cách đo: số đơn 6–8h và 11–13h, số suất mỗi ngày.',
    ].join('\n'),
  },
  {
    ma: 'it_don', ten: 'Quán mới hoặc kỳ rất ít đơn',
    khi: /quan moi|moi mo|it don|vang qua|khong co khach|\be am\b/,
    noi_dung: [
      'Ít đơn thì chưa kết luận được giờ, thứ, món nào yếu; xem kỳ dài hơn (30 ngày qua) trước khi chọn giờ hay món.',
      'Việc đầu là cho khách biết quán: bảng hiệu, ảnh món trên Google Maps / Facebook, mời người quen thử và xin đánh giá.',
      'Giữ khách đầu tiên: nhớ mặt, hỏi góp ý, mời quay lại kèm một món nhỏ lần sau (ghi tay hoặc thẻ giấy).',
      'Không giảm giá toàn menu khi chưa biết giá vốn.',
    ].join('\n'),
  },
  {
    ma: 'don_tut', ten: 'Số đơn đang tụt so với kỳ trước',
    khi: /(?:doanh thu|doanh so|so don|don|khach) (?:\S+ ){0,2}(?:giam|tut|sut|xuong)\b|it hon truoc|khong bang (?:truoc|thang truoc)/,
    noi_dung: [
      'Tách trước: tụt do số đơn (ít khách) hay do giá trị mỗi đơn (khách chi ít hơn); hai việc chữa khác nhau.',
      'Ít khách: tìm giờ / thứ mất nhiều nhất so kỳ trước, kéo khách cũ quay lại đúng giờ đó; hỏi chủ quán có gì đổi (đối thủ mới, sửa đường, nghỉ hè).',
      'Đơn đang tụt thì KHÔNG tăng giá; cũng đừng giảm giá đại trà khi chưa biết lý do.',
      'Khách chi ít: mời thêm món nhỏ giá vốn thấp, sửa combo đắt hơn mua lẻ.',
    ].join('\n'),
  },
  {
    ma: 'gio_vang', ten: 'Giờ vắng trong ngày',
    khi: /gio vang|buoi (?:chieu|toi|sang) vang|khung vang|chieu vang|toi vang/,
    noi_dung: [
      'Chỉ chọn giờ quán đang mở; giờ không có đơn chưa chắc là giờ vắng (có thể quán đóng).',
      'Giờ vắng thường là do không ai đi qua, không phải do giá: món hợp giờ đó (đồ uống chiều, món nhẹ tối) quan trọng hơn giảm giá.',
      'Mã trong app không giới hạn theo giờ: muốn ưu đãi theo giờ thì tạo mã riêng và dặn nhân viên chỉ áp đúng giờ.',
      'Nếu buổi đó lỗ cả tiền người và điện, tính có nên rút giờ hay không thay vì cố kéo khách.',
    ].join('\n'),
  },
  {
    ma: 'giu_khach', ten: 'Giữ khách quen, kéo khách cũ quay lại',
    khi: /khach quen|khach cu|quay lai|giu khach|trung thanh|tich diem/,
    noi_dung: [
      'App có "Điểm thưởng": khách được trừ tiền bằng điểm khi thanh toán. App KHÔNG biết khách nào lâu chưa ghé, KHÔNG gửi tin; muốn nhắn thì quán tự nhắn ngoài app từ danh sách khách.',
      'Thẻ tích ly dùng thẻ giấy; mức tặng chọn món giá vốn thấp.',
      'Rẻ nhất mà hiệu quả: nhớ tên, nhớ món quen của khách, phục vụ nhanh.',
      'Cách đo: số khách đã lưu quay lại từ 2 lần, số đơn giờ khách quen hay đến.',
    ].join('\n'),
  },
  {
    ma: 'gia_tri_don', ten: 'Tăng giá trị mỗi đơn',
    khi: /gia tri (?:moi )?don|mua them|goi them|ban them|ban kem|upsell|combo/,
    noi_dung: [
      'Mời thêm món nhỏ, rẻ, giá vốn thấp, hợp món chính (đồ uống với đồ ăn, topping với trà sữa); không mời thêm một món chính nữa.',
      'Combo phải rẻ hơn mua lẻ 5–10% và không ghép món giá vốn trên 45%; combo đang đắt hơn mua lẻ thì sửa trước.',
      'Câu mời ngắn cho nhân viên, đúng lúc gọi món; đo số phần món mời thêm mỗi ngày.',
      '"Tăng số đơn" và "tăng giá trị mỗi đơn" là hai việc khác nhau, đừng lấy cái này thay cái kia.',
    ].join('\n'),
  },
  {
    ma: 'ma_giam', ten: 'Mã giảm giá, khuyến mãi',
    khi: /ma giam|voucher|khuyen mai|giam gia|uu dai|mua \d tang \d/,
    noi_dung: [
      'Mã trong app có đơn tối thiểu, mức giảm tối đa, ngày hết hạn; KHÔNG giới hạn theo giờ, theo món, theo khách hay số lần.',
      'Đặt đơn tối thiểu cao hơn đơn trung bình để kéo đơn lớn lên; mức giảm không vượt phần lời thêm từ phần khách mua thêm.',
      'Tiền giảm là chi phí; mã bớt nhiều nhất là mã tốn nhất, chưa chắc hiệu quả nhất. Muốn biết thì tắt thử 1–2 tuần rồi so.',
      '"Mua 1 tặng 1" là giảm 50%: tính kỹ giá vốn trước, thường chỉ hợp món giá vốn thấp và giới hạn món.',
      'Không đề xuất mã trùng mã đang chạy.',
    ].join('\n'),
  },
  {
    ma: 'mang_ve', ten: 'Mang về, giao hàng, bán qua sàn',
    khi: /mang ve|giao hang|grab|shopee|be ?food|\bship|ban online|\bsan\b/,
    noi_dung: [
      'App chưa có báo cáo theo kênh bán; muốn so kênh thì ghi tay hoặc xem trên trang của sàn.',
      'Sàn ăn chiết khấu lớn: tính phần còn lại sau giá vốn + chiết khấu + bao bì cho từng món trước khi đẩy món đó lên sàn.',
      'Món bán sàn nên là món giá vốn thấp, đóng gói không hỏng; món giá vốn cao thì nâng giá trên sàn hoặc không bán.',
      'Kéo khách sàn về mua tại quán: thẻ nhỏ trong túi kèm ưu đãi khi đến quán (làm tay), kiểm tra điều khoản sàn trước.',
    ].join('\n'),
  },
  {
    ma: 'ngay_le', ten: 'Ngày lễ, dịp đặc biệt',
    khi: /\ble\b|\btet\b|20\/11|8\/3|20\/10|14\/2|trung thu|giang sinh|noel|\bdip\b/,
    noi_dung: [
      'Xem dịp đó có hợp khách chính không; không hợp thì chỉ làm nhẹ, rẻ, có điều kiện.',
      'Chia 3 mốc: trước dịp 3–7 ngày (chuẩn bị, báo khách), đúng ngày (làm gì), 1–2 ngày sau (đo).',
      'Không tặng món chính miễn phí, không giảm toàn menu, không chạy quảng cáo tốn tiền cho dịp không hợp.',
      'Đo: số đơn ngày đó so cùng thứ tuần trước.',
    ].join('\n'),
  },
  {
    ma: 'bai_dang', ten: 'Viết bài đăng, tin nhắn',
    khi: /viet bai|bai dang|facebook|zalo|tiktok|caption|to roi|tin nhan/,
    noi_dung: [
      'Bài chỉ ghi ưu đãi đang chạy thật và giá đang bán thật; giá hay ưu đãi đề xuất để sau chữ "Đề xuất:".',
      'Ngắn: một ý chính, món chủ lực, giờ mở, địa chỉ; chỗ chưa biết thì để [địa chỉ], [giờ mở].',
      'Ảnh món thật quan trọng hơn chữ; gợi ý chụp món bán chạy nhất.',
    ].join('\n'),
  },
  {
    ma: 'cuoi_tuan', ten: 'Cuối tuần',
    khi: /cuoi tuan|thu 7|chu nhat/,
    noi_dung: [
      'So cuối tuần với ngày thường trước: quán văn phòng cuối tuần vắng là bình thường; quán khu dân cư, quán đi chơi thì cuối tuần là ngày chính.',
      'Cuối tuần đã đông thì đừng giảm giá (bớt tiền khách vốn đã đến); lo phục vụ nhanh, đủ người.',
      'Cân nhắc mở thêm hay nghỉ cuối tuần: tính doanh thu ngày đó so tiền người + điện + nguyên liệu, thử nửa buổi vài lần rồi quyết.',
    ].join('\n'),
  },
];

// 08/11 đo 184 cặp chấm mù: sổ tay giúp rõ ở câu tiếp thị (+1,25 ± 0,58), không giúp ở câu khác (giá món −0,62, phân tích −0,30…)
// khi mở theo hồ sơ cho MỌI câu. Nên chỉ mở khi chính câu hỏi là câu tiếp thị; câu khác lời nhắc giữ y bản cũ.
const TIEP_THI = /tang (?:doanh|don|khach)|keo (?:them )?khach|hut (?:them )?khach|khach (?:quen|cu|quay lai)|giu khach|khuyen mai|uu dai|ma giam|voucher|giam gia|combo|ban them|goi them|mua them|ban kem|viet bai|bai dang|facebook|zalo|tiktok|to roi|quang cao|tiep thi|marketing|dong khach|cho dong|vang khach|gio vang|buoi (?:sang|trua|chieu|toi) vang|ngay le|\btet\b|hoc sinh|sinh vien|mang ve|giao hang|grab|shopee|mua \d tang \d/;
export const laCauTiepThi = (question: string) => TIEP_THI.test(bd(question));

/** Câu tiếp thị: tối đa 2 bài, bài khớp câu hỏi trước, rồi bài vị trí / khách chính theo hồ sơ. Câu khác: không mở bài nào. */
export function chonBai(question: string, hoSo = ''): BaiSoTay[] {
  if (!laCauTiepThi(question)) return [];
  const q = bd(question), h = bd(hoSo);
  const theoCau = SO_TAY.filter((b) => b.khi.test(q));
  const theoHoSo = SO_TAY.filter((b) => !theoCau.includes(b) && ['hoc_sinh', 'van_phong', 'dan_cu', 'cho_cong_trinh'].includes(b.ma) && b.khi.test(h));
  return [...theoCau, ...theoHoSo].slice(0, 2);
}

export function soTayChoBoom(bai: BaiSoTay[]): string {
  if (!bai.length) return '';
  return 'SỔ TAY TIẾP THỊ (kinh nghiệm chung, chỉ dùng phần hợp quán; số liệu thật của quán luôn đúng hơn):\n' +
    bai.map((b) => `[${b.ten}]\n${b.noi_dung}`).join('\n\n');
}
