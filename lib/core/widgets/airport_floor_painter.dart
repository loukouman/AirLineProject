import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dessine le schéma visuel du terminal : hall d'enregistrement,
/// couloir de sécurité, et deux ailes de portes (A et B).
/// Les coordonnées sont en pourcentage (0-100) de la largeur/hauteur.
class AirportFloorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset p(double xPct, double yPct) => Offset(w * xPct / 100, h * yPct / 100);

    final buildingBorder = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final zoneFill = Paint()..color = const Color(0xFFEFEAE3);
    final corridorFill = Paint()..color = const Color(0xFFE3DCD1);
    final wingFill = Paint()..color = const Color(0xFFF7F3EE);

    // Contour du bâtiment
    final building = RRect.fromRectAndRadius(
      Rect.fromLTRB(p(4, 4).dx, p(4, 4).dy, p(96, 96).dx, p(96, 96).dy),
      const Radius.circular(18),
    );
    canvas.drawRRect(building, Paint()..color = Colors.white);
    canvas.drawRRect(building, buildingBorder);

    // Hall d'enregistrement (bas, centre)
    final hall = Rect.fromLTRB(p(20, 68).dx, p(68, 68).dy, p(80, 90).dx, p(90, 90).dy);
    canvas.drawRRect(RRect.fromRectAndRadius(hall, const Radius.circular(10)), zoneFill);
    _label(canvas, "Hall d'enregistrement", hall.center, 10);

    // Couloir central
    final corridor = Rect.fromLTRB(p(46, 32).dx, p(32, 32).dy, p(54, 70).dx, p(70, 70).dy);
    canvas.drawRect(corridor, corridorFill);

    // Contrôle de sûreté
    final security = Rect.fromLTRB(p(35, 30).dx, p(30, 30).dy, p(65, 42).dx, p(42, 42).dy);
    canvas.drawRRect(RRect.fromRectAndRadius(security, const Radius.circular(10)), zoneFill);
    _label(canvas, 'Contrôle de sûreté', security.center, 10);

    // Aile A (gauche)
    final wingA = Rect.fromLTRB(p(8, 8).dx, p(8, 8).dy, p(44, 26).dx, p(26, 26).dy);
    canvas.drawRRect(RRect.fromRectAndRadius(wingA, const Radius.circular(10)), wingFill);
    canvas.drawRRect(RRect.fromRectAndRadius(wingA, const Radius.circular(10)), buildingBorder);
    _label(canvas, 'Portes A', Offset(wingA.center.dx, wingA.top - 8), 10);

    // Aile B (droite)
    final wingB = Rect.fromLTRB(p(56, 8).dx, p(8, 8).dy, p(92, 26).dx, p(26, 26).dy);
    canvas.drawRRect(RRect.fromRectAndRadius(wingB, const Radius.circular(10)), wingFill);
    canvas.drawRRect(RRect.fromRectAndRadius(wingB, const Radius.circular(10)), buildingBorder);
    _label(canvas, 'Portes B', Offset(wingB.center.dx, wingB.top - 8), 10);

    // Entrée
    final entrance = p(50, 95);
    canvas.drawCircle(entrance, 5, Paint()..color = AppColors.primary);
    _label(canvas, 'ENTRÉE', Offset(entrance.dx, entrance.dy + 12), 8, bold: true, color: AppColors.primary);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize, {
    bool bold = false,
    Color color = const Color(0xFF7A6A5F),
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant AirportFloorPainter oldDelegate) => false;
}

/// Trace un chemin en pointillés entre l'entrée et une porte sélectionnée,
/// pour guider visuellement le voyageur sur le plan.
class GuideLinePainter extends CustomPainter {
  final Offset from;
  final Offset to;
  final Color color;

  GuideLinePainter({
    required this.from,
    required this.to,
    this.color = const Color(0xFFC45A1C),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const dashLength = 6.0;
    const gapLength = 5.0;
    final total = (to - from).distance;
    if (total == 0) return;
    final direction = (to - from) / total;

    double drawn = 0;
    while (drawn < total) {
      final segStart = from + direction * drawn;
      final segEnd = from + direction * (drawn + dashLength).clamp(0, total);
      canvas.drawLine(segStart, segEnd, paint);
      drawn += dashLength + gapLength;
    }

    canvas.drawCircle(to, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant GuideLinePainter oldDelegate) {
    return oldDelegate.from != from || oldDelegate.to != to;
  }
}
