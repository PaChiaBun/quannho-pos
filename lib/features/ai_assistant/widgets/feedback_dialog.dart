import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedbackDialogResult {
  final String rating;
  final String? reasonCode;
  final String? proposedAnswer;

  FeedbackDialogResult({
    required this.rating,
    this.reasonCode,
    this.proposedAnswer,
  });
}

class FeedbackDialog extends StatefulWidget {
  final String initialRating; // 'thumbs_up', 'thumbs_down', or 'edit'
  final String currentAnswer;

  const FeedbackDialog({
    super.key,
    required this.initialRating,
    required this.currentAnswer,
  });

  static Future<FeedbackDialogResult?> show(
    BuildContext context, {
    required String initialRating,
    required String currentAnswer,
  }) {
    return showDialog<FeedbackDialogResult>(
      context: context,
      builder: (context) => FeedbackDialog(
        initialRating: initialRating,
        currentAnswer: currentAnswer,
      ),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  late String _selectedRating;
  String? _selectedReason;
  late TextEditingController _proposedAnswerController;

  static const kNavy = Color(0xFF1C2151);
  static const kRed = Color(0xFFE53935);

  final List<Map<String, String>> _reasons = [
    {'code': 'incorrect_data', 'label': 'Dữ liệu không chính xác'},
    {'code': 'misunderstood_question', 'label': 'Hiểu sai câu hỏi'},
    {'code': 'unsuitable_suggestion', 'label': 'Gợi ý chưa phù hợp'},
    {'code': 'unclear_answer', 'label': 'Câu trả lời chưa rõ ràng'},
    {'code': 'missing_information', 'label': 'Thiếu thông tin'},
    {'code': 'other', 'label': 'Lý do khác'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialRating == 'thumbs_up'
        ? 'thumbs_up'
        : 'thumbs_down';
    _selectedReason = _reasons.first['code'];
    _proposedAnswerController = TextEditingController();
  }

  @override
  void dispose() {
    _proposedAnswerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _selectedRating == 'thumbs_up'
                ? Icons.thumb_up_rounded
                : Icons.thumb_down_rounded,
            color: _selectedRating == 'thumbs_up' ? Colors.green : kRed,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Gửi phản hồi cho AI Bum',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kNavy,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đánh giá câu trả lời:',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: Text(
                    '👍 Hài lòng',
                    style: GoogleFonts.outfit(fontSize: 13),
                  ),
                  selected: _selectedRating == 'thumbs_up',
                  selectedColor: Colors.green.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRating = 'thumbs_up');
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    '👎 Chưa tốt',
                    style: GoogleFonts.outfit(fontSize: 13),
                  ),
                  selected: _selectedRating == 'thumbs_down',
                  selectedColor: kRed.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRating = 'thumbs_down');
                    }
                  },
                ),
              ],
            ),
            if (_selectedRating == 'thumbs_down') ...[
              const SizedBox(height: 16),
              Text(
                'Lý do chưa hài lòng:',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedReason,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: _reasons
                    .map(
                      (r) => DropdownMenuItem(
                        value: r['code'],
                        child: Text(
                          r['label']!,
                          style: GoogleFonts.outfit(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedReason = val);
                },
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Đề xuất câu trả lời đúng (nếu có):',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _proposedAnswerController,
              maxLines: 3,
              style: GoogleFonts.outfit(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Nhập nội dung bạn đề xuất Bum nên trả lời...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Hủy',
            style: GoogleFonts.outfit(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            final proposed = _proposedAnswerController.text.trim();
            Navigator.of(context).pop(
              FeedbackDialogResult(
                rating: _selectedRating,
                reasonCode: _selectedRating == 'thumbs_down'
                    ? _selectedReason
                    : null,
                proposedAnswer: proposed.isNotEmpty ? proposed : null,
              ),
            );
          },
          child: Text(
            'Gửi phản hồi',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class PairingDialog extends StatefulWidget {
  const PairingDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (context) => const PairingDialog(),
    );
  }

  @override
  State<PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<PairingDialog> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('pairing_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.link_rounded, color: Color(0xFF1C2151), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kết nối thiết bị với AI Bum',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C2151),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nhập mã ghép nối 6 chữ số được cấp cho quán:',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('pairing_code_input'),
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '842910',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Hủy',
            style: GoogleFonts.outfit(color: Colors.grey[600]),
          ),
        ),
        ElevatedButton(
          key: const Key('pairing_submit_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1C2151),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            final code = _codeController.text.trim();
            if (code.isNotEmpty) {
              Navigator.of(context).pop(code);
            }
          },
          child: Text(
            'Ghép nối',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
