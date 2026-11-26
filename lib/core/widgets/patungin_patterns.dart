import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================================
// BAGITIGAKAN ORGANIC UI PATTERNS & BRAND WIDGETS
// Konsep Hybrid · Botani Hangat:
// - Logo "The Precision Divide" (tanda bagi ÷ dengan 3 pil tengah)
// - Wordmark "BagiTigaKan" + sub-tagline "÷ split_fairly(n)"
// - Pola non-kotak: gelombang kanvas, struk bergerigi, kupon putus-putus,
//   stempel miring, pebble asimetris, progress ring, dan tumpukan avatar.
// ============================================================================

/// Logo Vektor "The Precision Divide" — Palet Botani Hangat
class BagiTigaKanLogo extends StatelessWidget {
  final double size;
  final bool showSubtleBorder;

  const BagiTigaKanLogo({
    super.key,
    this.size = 48,
    this.showSubtleBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: showSubtleBorder
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.28),
              border: Border.all(
                color: AppTheme.warmCream.withValues(alpha: 0.26),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            )
          : null,
      child: CustomPaint(
        size: Size.square(size),
        painter: const _PrecisionDivideLogoPainter(),
      ),
    );
  }
}

class _PrecisionDivideLogoPainter extends CustomPainter {
  const _PrecisionDivideLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;

    // Latar squircle Deep Botanical Forest
    final bgPaint = Paint()..color = const Color(0xFF143C2E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(28 * s),
      ),
      bgPaint,
    );

    // Titik atas (Honey Gold)
    canvas.drawCircle(
      Offset(50 * s, 27 * s),
      10.5 * s,
      Paint()..color = const Color(0xFFF6C453),
    );

    // Tiga pil horizontal di tengah (gradasi mint/sage organik -> "Bagi Tiga")
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(17 * s, 42.5 * s, 19 * s, 15 * s),
        Radius.circular(7.5 * s),
      ),
      Paint()..color = const Color(0xFF4FD1A5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(40.5 * s, 42.5 * s, 19 * s, 15 * s),
        Radius.circular(7.5 * s),
      ),
      Paint()..color = const Color(0xFF7BE0BC),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(64 * s, 42.5 * s, 19 * s, 15 * s),
        Radius.circular(7.5 * s),
      ),
      Paint()..color = const Color(0xFFB6F0D8),
    );

    // Titik bawah (Warm Terracotta)
    canvas.drawCircle(
      Offset(50 * s, 73 * s),
      10.5 * s,
      Paint()..color = const Color(0xFFE07A5F),
    );
  }

  @override
  bool shouldRepaint(covariant _PrecisionDivideLogoPainter oldDelegate) =>
      false;
}

/// Wordmark tipografi "BagiTigaKan" + opsional sub-label "÷ split_fairly(n)"
class BagiTigaKanWordmark extends StatelessWidget {
  final double fontSize;
  final bool onDark;
  final bool showTagline;
  final CrossAxisAlignment alignment;

  const BagiTigaKanWordmark({
    super.key,
    this.fontSize = 22,
    this.onDark = false,
    this.showTagline = false,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = onDark ? AppTheme.warmCream : AppTheme.darkSlate;
    final accentColor =
        onDark ? const Color(0xFF9AF0C7) : AppTheme.primaryEmerald;
    final taglineColor = onDark
        ? AppTheme.warmCream.withValues(alpha: 0.78)
        : AppTheme.mutedInk;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.05,
              color: baseColor,
            ),
            children: [
              const TextSpan(text: 'Bagi'),
              TextSpan(
                text: 'Tiga',
                style: TextStyle(color: accentColor),
              ),
              const TextSpan(text: 'Kan'),
            ],
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 3),
          Text(
            '÷ split_fairly(n)',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: math.max(11.0, fontSize * 0.44),
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: taglineColor,
            ),
          ),
        ],
      ],
    );
  }
}

/// Salam hangat dinamis sesuai jam lokal pengguna
String timeBasedGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 4 && hour < 11) return 'Selamat pagi';
  if (hour >= 11 && hour < 15) return 'Selamat siang';
  if (hour >= 15 && hour < 19) return 'Selamat sore';
  return 'Selamat malam';
}

/// Pasangan warna organik deterministik untuk setiap grup/orang agar terasa hidup
class OrganicColorPair {
  final Color bg;
  final Color fg;
  final Color accent;

  const OrganicColorPair({
    required this.bg,
    required this.fg,
    required this.accent,
  });
}

class PatunginPalette {
  static const List<OrganicColorPair> _pairs = [
    OrganicColorPair(
      bg: Color(0xFFE1EFE8),
      fg: Color(0xFF1B6B50),
      accent: Color(0xFF2E8B6B),
    ),
    OrganicColorPair(
      bg: Color(0xFFFCEAE3),
      fg: Color(0xFFC44D2C),
      accent: Color(0xFFE06D4B),
    ),
    OrganicColorPair(
      bg: Color(0xFFFDF3D8),
      fg: Color(0xFF9F650B),
      accent: Color(0xFFD99116),
    ),
    OrganicColorPair(
      bg: Color(0xFFEDE9F8),
      fg: Color(0xFF5B3FA8),
      accent: Color(0xFF7C5FD3),
    ),
    OrganicColorPair(
      bg: Color(0xFFE3F0F7),
      fg: Color(0xFF1F638C),
      accent: Color(0xFF3384B5),
    ),
    OrganicColorPair(
      bg: Color(0xFFF6E8F0),
      fg: Color(0xFF9B3B6B),
      accent: Color(0xFFC2588C),
    ),
  ];

  static OrganicColorPair forKey(String key) {
    if (key.isEmpty) return _pairs.first;
    final hash = key.codeUnits.fold<int>(0, (acc, c) => acc + c * 31);
    return _pairs[hash.abs() % _pairs.length];
  }
}

/// Clipper lengkungan gelombang bawah untuk header organik (pengganti kotak datar)
class BottomWaveClipper extends CustomClipper<Path> {
  final double waveDepth;

  const BottomWaveClipper({this.waveDepth = 28});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - waveDepth);
    path.cubicTo(
      size.width * 0.25,
      size.height + waveDepth * 0.55,
      size.width * 0.72,
      size.height - waveDepth * 1.45,
      size.width,
      size.height - waveDepth * 0.35,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant BottomWaveClipper oldClipper) =>
      oldClipper.waveDepth != waveDepth;
}

/// Painter dekorasi pola organik: lingkaran botani lembut + tekstur titik halus
class OrganicCanvasPainter extends CustomPainter {
  final Color blobColor;
  final Color dotColor;
  final bool showArcs;

  const OrganicCanvasPainter({
    this.blobColor = const Color(0x22FFFFFF),
    this.dotColor = const Color(0x18FFFFFF),
    this.showArcs = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final blobPaint = Paint()..color = blobColor;

    // Bentuk pebble/blob lembut kanan atas
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.88, size.height * 0.16),
        width: size.width * 0.52,
        height: size.width * 0.42,
      ),
      blobPaint,
    );

    // Bentuk blob lembut kiri bawah
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.08, size.height * 0.85),
        width: size.width * 0.44,
        height: size.width * 0.34,
      ),
      blobPaint,
    );

    if (showArcs) {
      final arcPaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      canvas.drawCircle(
        Offset(size.width * 0.92, size.height * 0.2),
        size.width * 0.24,
        arcPaint,
      );
      canvas.drawCircle(
        Offset(size.width * 0.92, size.height * 0.2),
        size.width * 0.34,
        arcPaint,
      );
    }

    // Pola titik halus bergaya cetakan kertas / risograph
    final dotPaint = Paint()..color = dotColor;
    const double step = 22;
    for (double x = 14; x < size.width; x += step) {
      for (double y = 14; y < size.height; y += step) {
        if (((x + y) ~/ step) % 2 == 0) {
          canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant OrganicCanvasPainter oldDelegate) =>
      oldDelegate.blobColor != blobColor || oldDelegate.dotColor != dotColor;
}

/// Header bergelombang organik untuk Splash, Auth, Home, dan Detail Grup
class OrganicWaveHeader extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;
  final double waveDepth;
  final EdgeInsetsGeometry padding;

  const OrganicWaveHeader({
    super.key,
    required this.child,
    this.gradientColors = const [Color(0xFF143C2E), Color(0xFF1F6B51)],
    this.waveDepth = 28,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 44),
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: BottomWaveClipper(waveDepth: waveDepth),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomPaint(
          painter: const OrganicCanvasPainter(
            blobColor: Color(0x14FFFFFF),
            dotColor: Color(0x16FFFFFF),
          ),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Bentuk ikon/badge asimetris bergaya batu sungai (pebble) — bukan persegi kaku
class OrganicPebbleBadge extends StatelessWidget {
  final Widget child;
  final Color color;
  final double size;
  final int variant;

  const OrganicPebbleBadge({
    super.key,
    required this.child,
    required this.color,
    this.size = 48,
    this.variant = 0,
  });

  BorderRadius _radiusForVariant() {
    return switch (variant % 3) {
      0 => BorderRadius.only(
          topLeft: Radius.circular(size * 0.44),
          topRight: Radius.circular(size * 0.24),
          bottomLeft: Radius.circular(size * 0.26),
          bottomRight: Radius.circular(size * 0.46),
        ),
      1 => BorderRadius.only(
          topLeft: Radius.circular(size * 0.26),
          topRight: Radius.circular(size * 0.48),
          bottomLeft: Radius.circular(size * 0.44),
          bottomRight: Radius.circular(size * 0.24),
        ),
      _ => BorderRadius.only(
          topLeft: Radius.circular(size * 0.48),
          topRight: Radius.circular(size * 0.42),
          bottomLeft: Radius.circular(size * 0.22),
          bottomRight: Radius.circular(size * 0.44),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: _radiusForVariant(),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Clipper kertas struk belanja fisik dengan tepi bergerigi (zigzag/scalloped)
class ScallopedReceiptClipper extends CustomClipper<Path> {
  final double toothWidth;
  final double toothHeight;
  final bool topEdge;
  final bool bottomEdge;
  final double? notchYFraction;

  const ScallopedReceiptClipper({
    this.toothWidth = 14,
    this.toothHeight = 6,
    this.topEdge = true,
    this.bottomEdge = true,
    this.notchYFraction,
  });

  @override
  Path getClip(Size size) {
    final path = Path();

    // Sisi atas
    if (topEdge) {
      path.moveTo(0, toothHeight);
      double x = 0;
      while (x < size.width) {
        final nextX = math.min(x + toothWidth, size.width);
        final midX = (x + nextX) / 2;
        path.lineTo(midX, 0);
        path.lineTo(nextX, toothHeight);
        x = nextX;
      }
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
    }

    // Sisi kanan (dengan opsional lubang tiket)
    final double rightBottomY = bottomEdge ? size.height - toothHeight : size.height;
    if (notchYFraction != null) {
      final notchY = size.height * notchYFraction!;
      const notchR = 10.0;
      path.lineTo(size.width, notchY - notchR);
      path.arcToPoint(
        Offset(size.width, notchY + notchR),
        radius: const Radius.circular(notchR),
        clockwise: false,
      );
    }
    path.lineTo(size.width, rightBottomY);

    // Sisi bawah bergerigi
    if (bottomEdge) {
      double x = size.width;
      while (x > 0) {
        final nextX = math.max(x - toothWidth, 0.0);
        final midX = (x + nextX) / 2;
        path.lineTo(midX, size.height);
        path.lineTo(nextX, size.height - toothHeight);
        x = nextX;
      }
    } else {
      path.lineTo(0, size.height);
    }

    // Sisi kiri (dengan opsional lubang tiket)
    final double leftTopY = topEdge ? toothHeight : 0;
    if (notchYFraction != null) {
      final notchY = size.height * notchYFraction!;
      const notchR = 10.0;
      path.lineTo(0, notchY + notchR);
      path.arcToPoint(
        Offset(0, notchY - notchR),
        radius: const Radius.circular(notchR),
        clockwise: false,
      );
    }
    path.lineTo(0, leftTopY);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant ScallopedReceiptClipper oldClipper) =>
      oldClipper.toothWidth != toothWidth ||
      oldClipper.toothHeight != toothHeight ||
      oldClipper.topEdge != topEdge ||
      oldClipper.bottomEdge != bottomEdge ||
      oldClipper.notchYFraction != notchYFraction;
}

/// Permukaan Struk Kertas Fisik (untuk rincian tagihan & ringkasan patungan)
class ScallopedReceiptSurface extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final bool topEdge;
  final bool bottomEdge;
  final double? notchYFraction;

  const ScallopedReceiptSurface({
    super.key,
    required this.child,
    this.color = AppTheme.paperWhite,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 24),
    this.topEdge = true,
    this.bottomEdge = true,
    this.notchYFraction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A3D2C).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ScallopedReceiptClipper(
          topEdge: topEdge,
          bottomEdge: bottomEdge,
          notchYFraction: notchYFraction,
        ),
        child: Container(
          width: double.infinity,
          color: color,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

/// Tiket horizontal dengan lekukan samping (ticket notches) untuk tagihan aktif
class TicketStripClipper extends CustomClipper<Path> {
  final double radius;
  final double notchRadius;

  const TicketStripClipper({this.radius = 20, this.notchRadius = 8});

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );
    final notchY = size.height * 0.56;
    final leftNotch = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, notchY), radius: notchRadius));
    final rightNotch = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(size.width, notchY), radius: notchRadius),
      );
    return Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.difference, path, leftNotch),
      rightNotch,
    );
  }

  @override
  bool shouldReclip(covariant TicketStripClipper oldClipper) => false;
}

/// Garis sobek putus-putus bergaya struk / buku catatan
class DashedDivider extends StatelessWidget {
  final Color color;
  final double height;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.color = const Color(0xFFD8CEBE),
    this.height = 1,
    this.dashWidth = 5,
    this.dashSpace = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dashWidth: dashWidth,
          dashSpace: dashSpace,
          strokeWidth: height,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  final double strokeWidth;

  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Stempel miring bergaya tinta karet (untuk status LUNAS / BELUM LUNAS pada struk)
class InkStampBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double angleRadians;

  const InkStampBadge({
    super.key,
    required this.text,
    required this.color,
    this.angleRadians = -0.07,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angleRadians,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.72), width: 1.7),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Kupon kode undangan dengan garis pinggir putus-putus
class DashedCouponChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const DashedCouponChip({
    super.key,
    required this.label,
    this.icon = Icons.copy_rounded,
    this.color = const Color(0xFF1F638C),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: color.withValues(alpha: 0.55),
          radius: 20,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.6, 0.6, size.width - 1.2, size.height - 1.2),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + 4.5, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 7.5;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Progress ring melingkar untuk progres pelunasan (pengganti bar garis kaku)
class CircularProgressRing extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;
  final Color trackColor;
  final String centerText;

  const CircularProgressRing({
    super.key,
    required this.progress,
    this.size = 62,
    this.color = AppTheme.primaryEmerald,
    this.trackColor = const Color(0xFFE6DDD0),
    required this.centerText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
          trackColor: trackColor,
        ),
        child: Center(
          child: Text(
            centerText,
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkSlate,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - 7) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Tumpukan avatar saling tumpang tindih (human social touch)
class OverlappingAvatarStack extends StatelessWidget {
  final List<String> labels;
  final int maxVisible;
  final double radius;
  final Color borderColor;

  const OverlappingAvatarStack({
    super.key,
    required this.labels,
    this.maxVisible = 4,
    this.radius = 15,
    this.borderColor = AppTheme.paperWhite,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    final visible = labels.take(maxVisible).toList();
    final extra = labels.length - visible.length;
    final overlap = radius * 1.35;
    final totalCount = visible.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      height: radius * 2 + 4,
      width: radius * 2 + 4 + (totalCount - 1) * overlap,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * overlap,
              child: _buildCircle(
                visible[i],
                PatunginPalette.forKey(visible[i] + i.toString()),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * overlap,
              child: Container(
                width: radius * 2 + 2,
                height: radius * 2 + 2,
                decoration: BoxDecoration(
                  color: AppTheme.warmSand,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$extra',
                  style: TextStyle(
                    fontSize: radius * 0.68,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.darkSlate,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCircle(String initials, OrganicColorPair colors) {
    return Container(
      width: radius * 2 + 2,
      height: radius * 2 + 2,
      decoration: BoxDecoration(
        color: colors.bg,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.72,
          fontWeight: FontWeight.w800,
          color: colors.fg,
        ),
      ),
    );
  }
}
