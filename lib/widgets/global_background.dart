import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yvl/providers/settings_provider.dart';

class GlobalBackground extends ConsumerStatefulWidget {
  final Widget child;
  const GlobalBackground({super.key, required this.child});

  @override
  ConsumerState<GlobalBackground> createState() => _GlobalBackgroundState();
}

class _GlobalBackgroundState extends ConsumerState<GlobalBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _controller2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeType = ref.watch(settingsProvider).themeType;
    final isSky = themeType == ThemeType.sky;

    if (!isSky) {
      return Stack(
        children: [
          Container(color: Theme.of(context).scaffoldBackgroundColor),
          widget.child,
        ],
      );
    }

    // Sky animated background
    return Stack(
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge([_controller1, _controller2]),
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _SkyBackgroundPainter(
                  t1: _controller1.value,
                  t2: _controller2.value,
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _SkyBackgroundPainter extends CustomPainter {
  final double t1;
  final double t2;

  const _SkyBackgroundPainter({required this.t1, required this.t2});

  @override
  void paint(Canvas canvas, Size size) {
    // Deep navy base
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF010A18), Color(0xFF050A14), Color(0xFF020810)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Animated orb 1 — cyan/sky
    final cx1 = size.width * (0.2 + 0.3 * math.sin(t1 * math.pi * 2));
    final cy1 = size.height * (0.1 + 0.25 * math.cos(t1 * math.pi * 2));
    final orb1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00BCD4).withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: size.width * 0.55));
    canvas.drawCircle(Offset(cx1, cy1), size.width * 0.55, orb1);

    // Animated orb 2 — deep blue
    final cx2 = size.width * (0.7 + 0.2 * math.cos(t2 * math.pi * 2));
    final cy2 = size.height * (0.4 + 0.3 * math.sin(t2 * math.pi * 2));
    final orb2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0D47A1).withValues(alpha: 0.4),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: size.width * 0.6));
    canvas.drawCircle(Offset(cx2, cy2), size.width * 0.6, orb2);

    // Animated orb 3 — teal accent
    final cx3 = size.width * (0.5 + 0.25 * math.sin((t1 + 0.5) * math.pi * 2));
    final cy3 = size.height * (0.7 + 0.2 * math.cos((t2 + 0.3) * math.pi * 2));
    final orb3 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF006064).withValues(alpha: 0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx3, cy3), radius: size.width * 0.45));
    canvas.drawCircle(Offset(cx3, cy3), size.width * 0.45, orb3);

    // Stars (static dots)
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
      final sx = rng.nextDouble() * size.width;
      final sy = rng.nextDouble() * size.height;
      final sr = rng.nextDouble() * 1.2 + 0.3;
      canvas.drawCircle(Offset(sx, sy), sr, starPaint);
    }
  }

  @override
  bool shouldRepaint(_SkyBackgroundPainter old) => old.t1 != t1 || old.t2 != t2;
}
