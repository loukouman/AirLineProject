import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../agent/checkin_desk_screen.dart';
import '../agent/incident_history_screen.dart';
import 'admin_lost_items_screen.dart';
import 'admin_assistance_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getDashboardStats();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getDashboardStats();
    });
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'a_l_heure':
        return 'À l\'heure';
      case 'retarde':
        return 'Retardés';
      case 'embarquement':
        return 'Embarquement';
      case 'decolle':
        return 'Décollés';
      case 'annule':
        return 'Annulés';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'retarde':
        return Colors.orange;
      case 'annule':
        return Colors.redAccent;
      case 'embarquement':
        return const Color(0xFF378ADD);
      case 'decolle':
        return AppColors.inkSoft;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data ?? {};
          final statusCounts = (stats['status_counts'] as Map<String, dynamic>? ?? {});
          final topFlights = (stats['top_flights'] as List<dynamic>? ?? []);
          final incidentsBySeverity = (stats['incidents_by_severity'] as Map<String, dynamic>? ?? {});

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.flight_outlined,
                      label: 'Vols actifs',
                      value: '${stats['total_flights'] ?? 0}',
                      color: AppColors.primary,
                      onTap: () => DefaultTabController.of(context).animateTo(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Enregistrements',
                      value: '${stats['total_checkins'] ?? 0}',
                      color: const Color(0xFF378ADD),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CheckinDeskScreen())),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.report_gmailerrorred_outlined,
                      label: 'Incidents (7j)',
                      value: '${stats['incidents_7d'] ?? 0}',
                      color: Colors.redAccent,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IncidentHistoryScreen())),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.campaign_outlined,
                      label: 'Pubs actives',
                      value: '${stats['active_ads'] ?? 0} / ${stats['total_ads'] ?? 0}',
                      color: const Color(0xFF8A5CC4),
                      onTap: () => DefaultTabController.of(context).animateTo(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.search_off,
                      label: 'Objets perdus à traiter',
                      value: '${stats['pending_lost_items'] ?? 0} / ${stats['total_lost_items'] ?? 0}',
                      color: const Color(0xFFC44A6A),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminLostItemsScreen())),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.accessible,
                      label: 'Assistances à traiter',
                      value: '${stats['pending_assistance'] ?? 0} / ${stats['total_assistance'] ?? 0}',
                      color: const Color(0xFFC48A1C),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAssistanceScreen())),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Text('Répartition des statuts de vol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              if (statusCounts.isEmpty)
                const Text('Aucune donnée pour le moment.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12))
              else
                Column(
                  children: statusCounts.entries.map((entry) {
                    final status = entry.key;
                    final count = entry.value as int;
                    final total = stats['total_flights'] as int? ?? 1;
                    final ratio = total > 0 ? count / total : 0.0;
                    final color = _statusColor(status);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_statusLabel(status), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFF3F7FA),
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
              const Text('Vols les plus fréquentés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              if (topFlights.isEmpty)
                const Text('Aucune donnée pour le moment.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12))
              else
                ...topFlights.map((f) {
                  final flight = f as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${flight['flight_number']} · ${flight['destination_city']}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text('${flight['checkins']} voyageur(s)', style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                      ],
                    ),
                  );
                }),

              const SizedBox(height: 24),
              const Text('Incidents par gravité (7 derniers jours)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _SeverityStat(label: 'Faible', count: incidentsBySeverity['faible'] as int? ?? 0, color: AppColors.success)),
                  const SizedBox(width: 8),
                  Expanded(child: _SeverityStat(label: 'Moyenne', count: incidentsBySeverity['moyenne'] as int? ?? 0, color: Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: _SeverityStat(label: 'Élevée', count: incidentsBySeverity['elevee'] as int? ?? 0, color: Colors.redAccent)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                if (onTap != null) Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 12),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _SeverityStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SeverityStat({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
