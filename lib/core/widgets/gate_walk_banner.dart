import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bannière qui aide le voyageur à savoir s'il a le temps de rejoindre
/// sa porte avant l'embarquement. Se met à jour chaque minute.
///
/// [walkMinutes] est une estimation du temps de marche jusqu'à la porte.
/// À défaut de données précises par porte, une estimation par défaut est utilisée.
class GateWalkBanner extends StatefulWidget {
  final String gateCode;
  final DateTime boardingTime;
  final int walkMinutes;

  const GateWalkBanner({
    super.key,
    required this.gateCode,
    required this.boardingTime,
    this.walkMinutes = 10,
  });

  @override
  State<GateWalkBanner> createState() => _GateWalkBannerState();
}

class _GateWalkBannerState extends State<GateWalkBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutesLeft = widget.boardingTime.difference(DateTime.now()).inMinutes;

    if (minutesLeft < -30) return const SizedBox.shrink();

    final bool isUrgent = minutesLeft <= widget.walkMinutes + 5;
    final bool isPast = minutesLeft < 0;

    final Color bg = isPast
        ? const Color(0xFFFCEBEB)
        : isUrgent
            ? const Color(0xFFFAEEDA)
            : const Color(0xFFEAF3DE);
    final Color fg = isPast
        ? const Color(0xFF791F1F)
        : isUrgent
            ? const Color(0xFF854F0B)
            : const Color(0xFF3B6D11);
    final IconData icon = isPast ? Icons.error_outline : Icons.directions_walk;

    final String message = isPast
        ? "L'embarquement est en cours à la porte ${widget.gateCode}"
        : "Porte ${widget.gateCode} à ${widget.walkMinutes} min à pied · il te reste $minutesLeft min";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
