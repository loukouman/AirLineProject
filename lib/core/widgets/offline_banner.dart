import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: const [
          Icon(Icons.wifi_off, size: 15, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Hors connexion — affichage des données enregistrées localement',
              style: TextStyle(fontSize: 11, color: AppColors.textDark, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
