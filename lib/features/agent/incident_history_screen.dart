import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class IncidentHistoryScreen extends StatefulWidget {
  const IncidentHistoryScreen({super.key});

  @override
  State<IncidentHistoryScreen> createState() => _IncidentHistoryScreenState();
}

class _IncidentHistoryScreenState extends State<IncidentHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _severityFilter;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getSecurityIncidents();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getSecurityIncidents();
    });
  }

  Color _colorForSeverity(String severity) {
    switch (severity) {
      case 'elevee':
        return Colors.redAccent;
      case 'moyenne':
        return Colors.orange;
      default:
        return AppColors.success;
    }
  }

  String _labelForSeverity(String severity) {
    switch (severity) {
      case 'elevee':
        return 'Élevée';
      case 'moyenne':
        return 'Moyenne';
      default:
        return 'Faible';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historique des incidents')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('Filtrer :', style: TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _FilterChip(label: 'Toutes', selected: _severityFilter == null, onTap: () => setState(() => _severityFilter = null)),
                      _FilterChip(label: 'Faible', color: AppColors.success, selected: _severityFilter == 'faible', onTap: () => setState(() => _severityFilter = 'faible')),
                      _FilterChip(label: 'Moyenne', color: Colors.orange, selected: _severityFilter == 'moyenne', onTap: () => setState(() => _severityFilter = 'moyenne')),
                      _FilterChip(label: 'Élevée', color: Colors.redAccent, selected: _severityFilter == 'elevee', onTap: () => setState(() => _severityFilter = 'elevee')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var incidents = snapshot.data ?? [];
                  if (_severityFilter != null) {
                    incidents = incidents.where((i) => i['severity'] == _severityFilter).toList();
                  }

                  if (incidents.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(60),
                          child: Text('Aucun incident signalé.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: incidents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final incident = incidents[i];
                      final severity = incident['severity'] as String? ?? 'faible';
                      final color = _colorForSeverity(severity);
                      final zone = incident['security_zones'] as Map<String, dynamic>?;
                      final reporter = incident['profiles'] as Map<String, dynamic>?;
                      final photoUrl = incident['photo_url'] as String?;
                      final createdAt = DateTime.parse(incident['created_at'] as String);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (photoUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(photoUrl, width: 56, height: 56, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(incident['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                        child: Text(_labelForSeverity(severity), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                                      ),
                                    ],
                                  ),
                                  if (incident['description'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(incident['description'] as String, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    '${zone?['name'] ?? 'Zone non précisée'} · ${reporter?['full_name'] ?? 'Agent'} · ${DateFormat('dd/MM HH:mm').format(createdAt)}',
                                    style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.black.withValues(alpha: 0.15)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: selected ? color : AppColors.textDark, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
