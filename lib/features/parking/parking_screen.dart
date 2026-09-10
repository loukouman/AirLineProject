import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ParkingScreen extends StatelessWidget {
  const ParkingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parking')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_parking, size: 56, color: AppColors.inkSoft),
              SizedBox(height: 16),
              Text(
                'La réservation de parking arrive bientôt',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
