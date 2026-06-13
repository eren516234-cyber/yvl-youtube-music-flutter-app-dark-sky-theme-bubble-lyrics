import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:yvl/services/ytm_home.dart';

/// Half-circle spinning album dialer that emerges from the bottom-right corner.
/// Albums are arranged in an arc. Swipe up/down to spin. Tap to play.
class AlbumDialer extends StatefulWidget {
  final List<HomeItem> albums;
  final void Function(HomeItem) onItemSelected;
  final VoidCallback onClose;

  const AlbumDialer({
    super.key,
    required this.albums,
    required this.onItemSelected,
    required this.onClose,
  });

  @override
  State<AlbumDialer> createState() => _AlbumDialerState();
}

class _AlbumDialerState extends State<AlbumDialer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryAnim;

  double _rotOffset = 0.0; // degrees
  double _dragStartY = 0.0;
  double _rotAtDragStart = 0.0;
  int _lastTickIdx = -1;

  // Arc geometry (from bottom-right corner)
  static const double _radius = 230.0;
  static const double _baseItemSize = 68.0;
  static const double _arcStartDeg = 110.0; // degrees from positive-x axis
  static const double _arcEndDeg = 255.0;
  static const double _arcSpanDeg = _arcEndDeg - _arcStartDeg;
  static const double _spacingDeg = 20.0; // degrees between items

  static double _rad(double deg) => deg * pi / 180;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _entryAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut);
    _entryCtrl.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // Returns items with their (angleDeg, HomeItem)
  List<({double angleDeg, HomeItem item, int idx})> _getItems() {
    final result = <({double angleDeg, HomeItem item, int idx})>[];
    for (int i = 0; i < widget.albums.length; i++) {
      final deg = _arcStartDeg + (i * _spacingDeg) - _rotOffset;
      if (deg >= _arcStartDeg - _spacingDeg && deg <= _arcEndDeg + _spacingDeg) {
        result.add((angleDeg: deg, item: widget.albums[i], idx: i));
      }
    }
    return result;
  }

  double get _centerDeg => (_arcStartDeg + _arcEndDeg) / 2;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: widget.onClose,
      child: AnimatedBuilder(
        animation: _entryAnim,
        builder: (context, _) {
          return Container(
            color: Colors.black.withValues(alpha: 0.45 * _entryAnim.value),
            child: Stack(
              children: [
                // Arc glow background
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CustomPaint(
                    size: Size(_radius * 1.4, _radius * 1.4),
                    painter: _ArcGlowPainter(progress: _entryAnim.value),
                  ),
                ),

                // Album items on the arc
                ..._getItems().map((entry) {
                  final angleRad = _rad(entry.angleDeg);
                  final rx = size.width - _radius * _entryAnim.value * cos(angleRad);
                  final ry = size.height - _radius * _entryAnim.value * sin(angleRad);

                  final distFromCenter = (entry.angleDeg - _centerDeg).abs();
                  final isCenter = distFromCenter < _spacingDeg * 0.55;
                  final scale = (1.0 - distFromCenter / 90.0).clamp(0.55, 1.0);
                  final opacity = (1.0 - distFromCenter / 100.0).clamp(0.35, 1.0);
                  final itemSize = _baseItemSize * scale;

                  return Positioned(
                    left: rx - itemSize / 2,
                    top: ry - itemSize / 2,
                    child: Opacity(
                      opacity: opacity,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onItemSelected(entry.item);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: itemSize,
                          height: itemSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isCenter ? 0.7 : 0.4),
                                blurRadius: isCenter ? 24 : 12,
                                offset: const Offset(0, 6),
                              ),
                              if (isCenter)
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                            ],
                            border: Border.all(
                              color: isCenter
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.25),
                              width: isCenter ? 2.5 : 1.0,
                            ),
                          ),
                          child: ClipOval(
                            child: entry.item.thumbnailUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: entry.item.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _albumFallback(),
                                  )
                                : _albumFallback(),
                          ),
                        ),
                      ),
                    ).animate().scale(
                          begin: const Offset(0.4, 0.4),
                          end: const Offset(1.0, 1.0),
                          duration: const Duration(milliseconds: 300),
                          delay: Duration(milliseconds: entry.idx * 25),
                          curve: Curves.easeOutBack,
                        ),
                  );
                }),

                // Spin gesture zone (bottom-right area)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (d) {
                      _dragStartY = d.localPosition.dy;
                      _rotAtDragStart = _rotOffset;
                    },
                    onPanUpdate: (d) {
                      final dy = d.localPosition.dy - _dragStartY;
                      // 1px up = 0.5 degrees rotation
                      final newRot = _rotAtDragStart - dy * 0.5;
                      final maxRot =
                          (widget.albums.length - 6) * _spacingDeg.toDouble();
                      setState(() {
                        _rotOffset = newRot.clamp(-_arcSpanDeg / 3, maxRot);
                      });
                      // Tick haptic when crossing item boundary
                      final tickIdx = (_rotOffset / _spacingDeg).round();
                      if (tickIdx != _lastTickIdx) {
                        _lastTickIdx = tickIdx;
                        HapticFeedback.selectionClick();
                      }
                    },
                    child: Container(
                      width: _radius * 1.4,
                      height: _radius * 1.4,
                      color: Colors.transparent,
                    ),
                  ),
                ),

                // Close X button
                Positioned(
                  right: 20,
                  bottom: 80 + bottomPad,
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3), width: 1),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ).animate().fadeIn(duration: 300.ms).scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        delay: 200.ms,
                        curve: Curves.elasticOut,
                      ),
                ),

                // "Spin to explore" hint
                Positioned(
                  right: 70,
                  bottom: 92 + bottomPad,
                  child: Text(
                    '↑ Spin',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4 * _entryAnim.value),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _albumFallback() {
    return Container(
      color: Colors.grey[850],
      child: const Icon(Icons.album_rounded, color: Colors.white38, size: 28),
    );
  }
}

// Glowing arc background painter
class _ArcGlowPainter extends CustomPainter {
  final double progress;
  const _ArcGlowPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width, size.height);
    final radius = size.width * 0.95 * progress;

    // Gradient glow ring
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.bottomRight,
        startAngle: pi * 0.6,
        endAngle: pi * 1.45,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.04 * progress),
          Colors.white.withOpacity(0.08 * progress),
          Colors.white.withOpacity(0.04 * progress),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 0.6, // start
      pi * 0.85, // sweep
      false,
      paint,
    );

    // Fine border arc
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.12 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.98 * progress),
      pi * 0.55,
      pi * 0.95,
      false,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcGlowPainter old) => old.progress != progress;
}
