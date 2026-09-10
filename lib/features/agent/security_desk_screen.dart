import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class SecurityDeskScreen extends StatefulWidget {
  const SecurityDeskScreen({super.key});

  @override
  State<SecurityDeskScreen> createState() => _SecurityDeskScreenState();
}

class _SecurityDeskScreenState extends State<SecurityDeskScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getSecurityZones();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getSecurityZones();
    });
  }

  Future<void> _updateWait(String zoneId, int currentMinutes) async {
    final controller = TextEditingController(text: currentMinutes.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temps d\'attente (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text) ?? currentMinutes),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result != null) {
      await SupabaseService.updateSecurityZoneWait(zoneId, result);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zones de sûreté'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async { await SupabaseService.signOut(); },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final zones = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: zones.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final z = zones[i];
              final wait = z['estimated_wait_minutes'] as int? ?? 0;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(z['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('${z['open_lanes'] ?? 0} file(s) ouverte(s)', style: const TextStyle(color: AppColors.inkSoft, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('$wait min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                      onPressed: () => _updateWait(z['id'] as String, wait),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
