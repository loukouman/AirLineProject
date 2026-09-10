import 'package:flutter/material.dart';

/// Découpe un Container en forme de "vrai billet" :
/// coins arrondis + deux encoches circulaires (gauche/droite)
/// à la hauteur [notchY], comme une carte d'embarquement perforée.
class TicketClipper extends CustomClipper<Path> {
  final double notchY;
  final double borderRadius;
  final double notchRadius;

  TicketClipper({
    required this.notchY,
    this.borderRadius = 20,
    this.notchRadius = 12,
  });

  @override
  Path getClip(Size size) {
    final r = borderRadius;
    final nr = notchRadius;
    final path = Path();

    path.moveTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);
    path.lineTo(size.width - r, 0);
    path.quadraticBezierTo(size.width, 0, size.width, r);
    path.lineTo(size.width, notchY - nr);
    path.arcToPoint(
      Offset(size.width, notchY + nr),
      radius: Radius.circular(nr),
      clockwise: false,
    );
    path.lineTo(size.width, size.height - r);
    path.quadraticBezierTo(size.width, size.height, size.width - r, size.height);
    path.lineTo(r, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - r);
    path.lineTo(0, notchY + nr);
    path.arcToPoint(
      Offset(0, notchY - nr),
      radius: Radius.circular(nr),
      clockwise: false,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant TicketClipper oldClipper) {
    return oldClipper.notchY != notchY ||
        oldClipper.borderRadius != borderRadius ||
        oldClipper.notchRadius != notchRadius;
  }
}

/// Ligne pointillée horizontale, style "détachez ici" du billet.
class DashedLine extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashGap;

  const DashedLine({
    super.key,
    this.height = 1,
    this.color = const Color(0x1F000000),
    this.dashWidth = 6,
    this.dashGap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          dashWidth: dashWidth,
          dashGap: dashGap,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashGap;

  _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke;

    final y = size.height / 2;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap;
  }
}
