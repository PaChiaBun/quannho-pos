import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/providers/app_providers.dart';
import '../core/theme/app_colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Controller cho logo bounce
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // Controller cho text nảy tưng
  late AnimationController _textController;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;

  // Controller cho tagline
  late AnimationController _tagController;
  late Animation<double> _tagOpacity;
  late Animation<double> _tagSlide;

  @override
  void initState() {
    super.initState();

    // Remove native splash ngay khi Flutter screen ready
    FlutterNativeSplash.remove();

    // 1. Logo bounce in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // 2. Text "Quán Nhỏ POS" nảy lên
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.elasticOut),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // 3. Tagline fade + slide nhẹ
    _tagController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tagOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tagController, curve: Curves.easeIn),
    );
    _tagSlide = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(parent: _tagController, curve: Curves.easeOut),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Logo bounce
    await Future.delayed(const Duration(milliseconds: 100));
    _logoController.forward();

    // Text nảy vào sau logo 400ms
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();

    // Tagline fade sau text 300ms
    await Future.delayed(const Duration(milliseconds: 300));
    _tagController.forward();

    // Chờ rồi check onboarding + PIN + navigate
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      // Check onboarding — dùng SharedPreferences (nhanh hơn)
      final prefs   = await SharedPreferences.getInstance();
      final obDone  = prefs.getBool('onboarding_complete') ?? false;

      // Backward compat: check DB key cũ nếu chưa có SP flag
      final settings    = ref.read(settingsRepositoryProvider);
      final obDoneOld   = await settings.get('onboarding_done');
      final pinEnabled  = await settings.get('pin_enabled');

      final isOnboarded = obDone || obDoneOld == 'true';

      if (!mounted) return;
      if (!isOnboarded) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      } else if (pinEnabled == 'true') {
        Navigator.of(context).pushReplacementNamed('/pin');
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lpmNavy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo bounce
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: child,
                  ),
                );
              },
              child: ClipOval(
                child: Image.asset(
                  'assets/branding/app_icon.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // "Quán Nhỏ POS" text nảy tưng
            AnimatedBuilder(
              animation: _textController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _textSlide.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Quán Nhỏ',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: ' POS',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFF6B35), // orange accent
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tagline fade in
            AnimatedBuilder(
              animation: _tagController,
              builder: (context, child) {
                return Opacity(
                  opacity: _tagOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _tagSlide.value),
                    child: child,
                  ),
                );
              },
              child: const Text(
                'Quản lý cửa hàng, đơn giản hơn',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFFFB347),
                  letterSpacing: 0.2,
                ),
              ),
            ),

            const SizedBox(height: 80),

            // Loading dots nhỏ phía dưới
            AnimatedBuilder(
              animation: _tagController,
              builder: (context, child) {
                return Opacity(
                  opacity: _tagOpacity.value,
                  child: child,
                );
              },
              child: const _LoadingDots(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3 chấm nhấp nháy loading
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      ),
    );
    _anims = _controllers
        .map(
          (c) => Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: c, curve: Curves.easeInOut),
          ),
        )
        .toList();

    _startDots();
  }

  void _startDots() async {
    while (mounted) {
      for (int i = 0; i < 3; i++) {
        if (!mounted) return;
        _controllers[i].forward();
        await Future.delayed(const Duration(milliseconds: 150));
      }
      await Future.delayed(const Duration(milliseconds: 300));
      for (var c in _controllers) {
        c.reverse();
      }
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                Colors.white.withValues(alpha: 0.2),
                const Color(0xFFFF6B35),
                _anims[i].value,
              ),
            ),
          ),
        );
      }),
    );
  }
}
