import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class AssistanceScreen extends StatefulWidget {
  const AssistanceScreen({super.key});

  @override
  State<AssistanceScreen> createState() => _AssistanceScreenState();
}

class _AssistanceScreenState extends State<AssistanceScreen> {
  final _detailsController = TextEditingController();
  bool _submitting = false;
  late Future<List<Map<String, dynamic>>> _future;

  static const _statusLabels = {
    'demandee': 'Demandée',
    'confirmee': 'Confirmée',
    'en_cours': 'En cours',
    'terminee': 'Terminée',
  };

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getMyAssistanceRequests();
  }

  void _refresh() {
    setState(() {
      _future = SupabaseService.getMyAssistanceRequests();
    });
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await SupabaseService.requestAssistance(
        details: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
      );
      _detailsController.clear();
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande d\'assistance envoyée.')));
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
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistance PMR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.skyPale, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.accessible, color: AppColors.primary, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Demande une assistance pour vous accompagner dans vos déplacements dans l\'aéroport.',
                      style: TextStyle(fontSize: 12, color: AppColors.textDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Précisions (optionnel)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: _submitting
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.accessible, color: Colors.white, size: 18),
                label: const Text('Demander une assistance'),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Mes demandes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                final requests = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()));
                }
                if (requests.isEmpty) {
                  return const Text('Aucune demande pour le moment.', style: TextStyle(color: AppColors.inkSoft));
                }
                return Column(
                  children: requests.map((req) {
                    final status = req['status'] as String? ?? 'demandee';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
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
                                Text(req['details'] as String? ?? 'Demande d\'assistance', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 3),
                                Text(
                                  DateFormat('dd/MM HH:mm').format(DateTime.parse(req['created_at'] as String)),
                                  style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                            child: Text(_statusLabels[status] ?? status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
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
