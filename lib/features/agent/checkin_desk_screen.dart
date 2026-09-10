import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import 'scan_screen.dart';

class CheckinDeskScreen extends StatefulWidget {
  const CheckinDeskScreen({super.key});

  @override
  State<CheckinDeskScreen> createState() => _CheckinDeskScreenState();
}

class _CheckinDeskScreenState extends State<CheckinDeskScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getRecentCheckins();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getRecentCheckins();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner une carte',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
              _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async { await SupabaseService.signOut(); },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final passes = snapshot.data ?? [];
            if (passes.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(60),
                    child: Text('Aucun enregistrement pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: passes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = passes[i];
                final flight = p['flights'] as Map<String, dynamic>?;
                final profile = p['profiles'] as Map<String, dynamic>?;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 16, backgroundColor: AppColors.skyPale, child: Icon(Icons.person, color: AppColors.primary, size: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile?['full_name'] as String? ?? 'Voyageur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              '${flight?['flight_number'] ?? ''} · ${flight?['origin_code'] ?? ''} → ${flight?['destination_code'] ?? ''} · siège ${p['seat'] ?? '--'}',
                              style: const TextStyle(color: AppColors.inkSoft, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(DateTime.parse(p['checked_in_at'] as String)),
                        style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
