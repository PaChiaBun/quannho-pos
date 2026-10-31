# hoi_quy.sh <nhãn> : đo lại các bộ câu một lượt (bo_so, bo_so_d, bo_so_e, 100 câu ngược) + chạy test Boom
S="$(cd "$(dirname "$0")/.." && pwd)"
cd "$S/../.."; T=test/features/ai_assistant
cp "$S"/do_tam/zz_do_duong_di_tam_test.dart "$S"/do_tam/zz_qc2_do_tam_test.dart $T/
for b in bo_so bo_so_d bo_so_e; do BO_CAU="$S"/$b/bo_cau.json KET_QUA="$S"/$b/duong_${1:-moi}.jsonl flutter test $T/zz_do_duong_di_tam_test.dart 2>&1 | tail -1; done
CAU="$S"/qc_so2/cau.json flutter test $T/zz_qc2_do_tam_test.dart 2>&1 | grep -v "^[0-9][0-9]:" > "$S"/qc_so2/out_${1:-moi}.txt
rm $T/zz_do_duong_di_tam_test.dart $T/zz_qc2_do_tam_test.dart
flutter test $T test/features/ai_assistant 2>&1 | tail -3 > "$S"/do_tam/test_${1:-moi}.txt
echo XONG
