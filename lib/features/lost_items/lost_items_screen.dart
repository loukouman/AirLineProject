import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class LostItemsScreen extends StatefulWidget {
  const LostItemsScreen({super.key});

  @override
  State<LostItemsScreen> createState() => _LostItemsScreenState();
}

class _LostItemsScreenState extends State<LostItemsScreen> {
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  bool _submitting = false;
  late Future<List<Map<String, dynamic>>> _future;

  static const _statusLabels = {
    'signale': 'Signalé',
    'en_recherche': 'Recherche en cours',
    'retrouve': 'Retrouvé',
    'clos': 'Clos',
  };

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getMyLostItems();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getMyLostItems();
    });
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Décris l\'objet perdu.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await SupabaseService.reportLostItem(
        description: description,
        locationLost: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      );
      _descriptionController.clear();
      _locationController.clear();
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déclaration envoyée.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objets perdus')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Déclarer un objet perdu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description de l\'objet', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Lieu approximatif (optionnel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Envoyer la déclaration'),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Mes déclarations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                final items = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
                }
                if (items.isEmpty) {
                  return const Text('Aucune déclaration pour le moment.', style: TextStyle(color: AppColors.inkSoft));
                }
                return Column(
                  children: items.map((item) {
                    final status = item['status'] as String? ?? 'signale';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['description'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (item['location_lost'] != null) ...[
                            const SizedBox(height: 3),
                            Text('Lieu : ${item['location_lost']}', style: const TextStyle(color: AppColors.inkSoft, fontSize: 11)),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: Text(_statusLabels[status] ?? status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('dd/MM HH:mm').format(DateTime.parse(item['created_at'] as String)),
                                style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
