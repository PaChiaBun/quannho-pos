import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/user_auth_service.dart';
import '../core/providers/session_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SPLASH SCREEN — Premium animated intro
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Logo ─────────────────────────────────────────────────────────────────
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  // ── Glow ring pulse ───────────────────────────────────────────────────────
  late AnimationController _glowCtrl;
  late Animation<double> _glowRadius;
  late Animation<double> _glowOpacity;

  // ── Text reveal ───────────────────────────────────────────────────────────
  late AnimationController _textCtrl;
  late Animation<double> _textOpacity;
  late Animation<double> _textSlide;

  // ── Tagline ───────────────────────────────────────────────────────────────
  late AnimationController _tagCtrl;
  late Animation<double> _tagOpacity;

  // ── Loading bar ───────────────────────────────────────────────────────────
  late AnimationController _barCtrl;
  late Animation<double> _barProgress;

  // ── Background shimmer ────────────────────────────────────────────────────
  late AnimationController _bgCtrl;
  late Animation<double> _bgAnim;

  static const _navy = Color(0xFF1E1C5E);
  static const _deep = Color(0xFF12103A);
  static const _orange = Color(0xFFFF6B35);
  static const _amber = Color(0xFFFFB347);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      FlutterNativeSplash.remove();
    }

    // Background slow pulse
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _bgAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));

    // Logo scale in with elastic
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    // Glow ring: repeating pulse
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowRadius = Tween<double>(
      begin: 88,
      end: 110,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowOpacity = Tween<double>(
      begin: 0.28,
      end: 0.60,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    // Text slide up + fade
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );
    _textSlide = Tween<double>(
      begin: 28.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    // Tagline
    _tagCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _tagOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _tagCtrl, curve: Curves.easeOut));

    // Loading bar
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _barProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 420));
    _textCtrl.forward();
    _barCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 280));
    _tagCtrl.forward();

    // Wait for bar to finish then navigate (min 2.2s so animations complete)
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Kiểm tra session đăng nhập
    final session = await UserAuthService.getCurrentSession();
    if (!mounted) return;

    if (session != null) {
      if (session.storeId != null && session.storeId!.isNotEmpty) {
        // ‼️ KIỂM TRA MEMBERSHIP CHỦ ĐỘNG (Server Validation)
        final val = await UserAuthService.validateActiveMembership(
          userId: session.userId,
          storeId: session.storeId!,
        );

        if (!mounted) return;

        if (!val.isActive && !val.isOffline) {
          // Server xác nhận thành viên đã bị thu hồi khỏi quán
          await ref.read(sessionProvider.notifier).clearStoreContext();
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/store_picker');
          return;
        }
      }

      ref.read(sessionProvider.notifier).setSession(session);
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _glowCtrl.dispose();
    _textCtrl.dispose();
    _tagCtrl.dispose();
    _barCtrl.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnim,
        builder: (_, child) {
          // Subtle background shift
          final bg = Color.lerp(_deep, _navy, _bgAnim.value)!;
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.6,
                colors: [
                  Color.lerp(const Color(0xFF2D2B8A), _deep, _bgAnim.value)!,
                  bg,
                  _deep,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // ── Decorative particles ───────────────────────────────────
            const _ParticleField(),

            // ── Main content ───────────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Logo area ────────────────────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoCtrl, _glowCtrl]),
                    builder: (_, child) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            Container(
                              width: _glowRadius.value * 2,
                              height: _glowRadius.value * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _orange.withValues(
                                      alpha: _glowOpacity.value,
                                    ),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            // Ring border
                            Container(
                              width: 172,
                              height: 172,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _orange.withValues(alpha: 0.30),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Logo — no ClipOval, no white border
                            Transform.scale(
                              scale: _logoScale.value,
                              child: child,
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(
                          0xFF1C2151,
                        ), // match splash bg — no white ring
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/branding/logo_head.png',
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── App name ─────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _textCtrl,
                    builder: (_, child) => Opacity(
                      opacity: _textOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: child,
                      ),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Quán Nhỏ',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                          ),
                          TextSpan(
                            text: ' POS',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: _orange,
                              letterSpacing: -1.0,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Tagline ───────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _tagCtrl,
                    builder: (_, child) =>
                        Opacity(opacity: _tagOpacity.value, child: child),
                    child: const Text(
                      'Quản lý cửa hàng, đơn giản hơn',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: _amber,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Loading bar + version ─────────────────────────────
                  AnimatedBuilder(
                    animation: _barCtrl,
                    builder: (_, __) => Opacity(
                      opacity: (_barCtrl.value * 3).clamp(0.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(48, 0, 48, 8),
                        child: Column(
                          children: [
                            // Progress bar track
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 3,
                                color: Colors.white.withValues(alpha: 0.10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor: _barProgress.value,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [_orange, _amber],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Bottom branding — LPM.VN ─────────────────────
                  AnimatedBuilder(
                    animation: _tagCtrl,
                    builder: (_, child) =>
                        Opacity(opacity: _tagOpacity.value, child: child),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Column(
                        children: [
                          // Divider line
                          Container(
                            width: 40,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.12),
                            margin: const EdgeInsets.only(bottom: 14),
                          ),
                          // "Sản phẩm của" label
                          Text(
                            'Sản phẩm của',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.38),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // LPM.VN logo badge
                          _LpmBadge(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICLE FIELD — subtle floating dots in background
// ─────────────────────────────────────────────────────────────────────────────
class _ParticleField extends StatefulWidget {
  const _ParticleField();

  @override
  State<_ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<_ParticleField>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  final _rng = math.Random(42); // fixed seed → consistent layout

  @override
  void initState() {
    super.initState();
    // Generate 18 particles at random positions
    _particles = List.generate(18, (i) => _Particle(_rng));

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(_particles, _ctrl.value),
        );
      },
    );
  }
}

class _Particle {
  final double x, y, size, speed, phase;

  _Particle(math.Random rng)
    : x = rng.nextDouble(),
      y = rng.nextDouble(),
      size = rng.nextDouble() * 3 + 1,
      speed = rng.nextDouble() * 0.3 + 0.1,
      phase = rng.nextDouble() * math.pi * 2;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  const _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Gentle float upward, wrapping
      final yPos = (p.y - t * p.speed) % 1.0;
      final opacity =
          (math.sin(t * 2 * math.pi * p.speed + p.phase) * 0.5 + 0.5) * 0.35;

      canvas.drawCircle(
        Offset(p.x * size.width, yPos * size.height),
        p.size,
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// LPM BADGE — Company branding at splash bottom
// ─────────────────────────────────────────────────────────────────────────────
class _LpmBadge extends StatelessWidget {
  const _LpmBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: Colors.white, // white bg vì logo có nền trắng
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'assets/branding/lpm_logo.png',
        height: 34,
        fit: BoxFit.contain,
      ),
    );
  }
}
