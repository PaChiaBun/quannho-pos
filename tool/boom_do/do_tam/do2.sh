# do2.sh <bộ> <nhãn> : đo tìm bài + chọn đường một lượt cho một bộ
S="$(cd "$(dirname "$0")/.." && pwd)"
cd "$S/../.."; T=test/features/ai_assistant
cp "$S"/do_tam/zz_tim_bai2_tam_test.dart $T/zz_tim_bai_tam_test.dart; cp "$S"/do_tam/zz_do_duong_di_tam_test.dart $T/
BO_CAU="$S"/$1/bo_cau.json KET_QUA="$S"/$1/tim_$2.jsonl flutter test $T/zz_tim_bai_tam_test.dart 2>&1 | tail -1
BO_CAU="$S"/$1/bo_cau.json KET_QUA="$S"/$1/duong_$2.jsonl flutter test $T/zz_do_duong_di_tam_test.dart 2>&1 | tail -1
rm $T/zz_tim_bai_tam_test.dart $T/zz_do_duong_di_tam_test.dart
