import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Écran d'information sur le parking de l'aéroport de Ouagadougou.
/// L'aéroport ne publie pas de disponibilité en temps réel ni de grille
/// tarifaire officielle : cet écran affiche donc des informations factuelles
/// vérifiées (capacité), pas de réservation en ligne simulée.
class ParkingScreen extends StatelessWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_parking, color: Colors.white, size: 32),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Parking aéroport', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 3),
                      Text('Capacité : 100 places', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const _InfoRow(
            icon: Icons.place_outlined,
            title: 'Emplacement',
            description: "Parking situé à proximité immédiate de l'aérogare, à moins de 5 minutes du centre-ville de Ouagadougou.",
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            icon: Icons.timelapse,
            title: 'Tarification',
            description: "L'aéroport ne publie pas de grille tarifaire officielle en ligne. Le tarif est appliqué sur place à la sortie du parking.",
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            icon: Icons.security_outlined,
            title: 'Sécurité',
            description: "Zone surveillée, accessible aux véhicules des voyageurs et accompagnateurs.",
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.inkSoft, size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "La réservation en ligne n'est pas disponible pour ce parking. Ces informations sont données à titre indicatif.",
                    style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _InfoRow({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.skyPale, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
