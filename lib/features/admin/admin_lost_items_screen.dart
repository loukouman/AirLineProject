import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class AdminLostItemsScreen extends StatefulWidget {
  const AdminLostItemsScreen({super.key});

  @override
  State<AdminLostItemsScreen> createState() => _AdminLostItemsScreenState();
}

class _AdminLostItemsScreenState extends State<AdminLostItemsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  static const _statusLabels = {
    'signale': 'Signalé',
    'en_recherche': 'En recherche',
    'retrouve': 'Retrouvé',
    'clos': 'Clos',
  };
  static const _statusOrder = ['signale', 'en_recherche', 'retrouve', 'clos'];

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getAllLostItems();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getAllLostItems();
    });
  }

  Color _colorFor(String status) {
    switch (status) {
      case 'retrouve':
        return AppColors.success;
      case 'en_recherche':
        return Colors.orange;
      case 'clos':
        return AppColors.inkSoft;
      default:
        return Colors.redAccent;
    }
  }

  Future<void> _changeStatus(String id, String current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: _statusOrder.map((s) {
          return ListTile(
            title: Text(_statusLabels[s]!),
            trailing: s == current ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(context, s),
          );
        }).toList(),
      ),
    );
    if (result != null && result != current) {
      await SupabaseService.updateLostItemStatus(id, result);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objets perdus')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(60),
                    child: Text('Aucune déclaration pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final status = item['status'] as String? ?? 'signale';
                final color = _colorFor(status);
                final profile = item['profiles'] as Map<String, dynamic>?;
                final createdAt = DateTime.parse(item['created_at'] as String);

                return InkWell(
                  key: ValueKey(item['id']),
                  onTap: () => _changeStatus(item['id'] as String, status),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['description'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              if (item['location_lost'] != null)
                                Text('Lieu : ${item['location_lost']}', style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                              const SizedBox(height: 4),
                              Text(
                                '${profile?['full_name'] ?? 'Voyageur'} · ${DateFormat('dd/MM HH:mm').format(createdAt)}',
                                style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                          child: Text(_statusLabels[status] ?? status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                        ),
                      ],
                    ),
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
