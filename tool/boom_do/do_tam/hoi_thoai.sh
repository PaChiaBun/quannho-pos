# hoi_thoai.sh <nhãn> <bộ...> : đo hội thoại 2 lượt
S="$(cd "$(dirname "$0")/.." && pwd)"
cd "$S/../.."; T=test/features/ai_assistant; nh=$1; shift
cp "$S"/do_tam/zz_hoi_thoai_tam_test.dart $T/
for b in "$@"; do BO_CAU="$S"/$b/bo_cau.json KET_QUA="$S"/$b/kq_$nh.jsonl flutter test $T/zz_hoi_thoai_tam_test.dart 2>&1 | tail -1; python3 "$S"/do_tam/cham_l2.py $nh $b; done
rm $T/zz_hoi_thoai_tam_test.dart
