import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BumTypingIndicator extends StatelessWidget {
  const BumTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    const kOrange = Color(0xFFFF6B35);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: kOrange,
              shape: BoxShape.circle,
            ),
          )
          .animate(onPlay: (controller) => controller.repeat())
          .scaleXY(
            begin: 0.5,
            end: 1.0,
            duration: 400.ms,
            curve: Curves.easeInOutSine,
            delay: (index * 150).ms,
          )
          .then(duration: 400.ms)
          .scaleXY(begin: 1.0, end: 0.5, curve: Curves.easeInOutSine);
        }),
      ),
    );
  }
}
