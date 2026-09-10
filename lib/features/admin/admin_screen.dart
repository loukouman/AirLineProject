import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'admin_flights_screen.dart';
import 'admin_alerts_screen.dart';
import 'admin_roles_screen.dart';
import 'admin_ads_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.primary,
            isScrollable: true,
            tabs: [
              Tab(text: 'Vols'),
              Tab(text: 'Alertes'),
              Tab(text: 'Rôles'),
              Tab(text: 'Pubs'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminFlightsScreen(),
            AdminAlertsScreen(),
            AdminRolesScreen(),
            AdminAdsScreen(),
          ],
        ),
      ),
    );
  }
}
