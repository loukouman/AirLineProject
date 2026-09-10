import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _submitting = false;
  late Future<List<Map<String, dynamic>>> _futureAlerts;

  @override
  void initState() {
    super.initState();
    _futureAlerts = SupabaseService.getAllAlerts();
  }

  void _refresh() {
    setState(() {
      _futureAlerts = SupabaseService.getAllAlerts();
    });
  }

  Future<void> _publish() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titre et message sont obligatoires.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await SupabaseService.createAlert(title: title, message: message);
      _titleController.clear();
      _messageController.clear();
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alerte publiée.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deactivate(String id) async {
    await SupabaseService.deactivateAlert(id);
    _refresh();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Publier une alerte', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _publish,
              style: FilledButton.styleFrom(backgroundColor: AppColors.coral, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Publier'),
            ),
          ),
          const SizedBox(height: 26),
          const Text('Alertes existantes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _futureAlerts,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final alerts = snapshot.data ?? [];
              if (alerts.isEmpty) {
                return const Text('Aucune alerte publiée.', style: TextStyle(color: AppColors.inkSoft));
              }

              return Column(
                children: alerts.map((a) {
                  final isActive = a['is_active'] as bool? ?? false;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.coralSoft : const Color(0xFFF3F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 3),
                              Text(a['message'] as String, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM HH:mm').format(DateTime.parse(a['created_at'] as String)),
                                style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                            onPressed: () => _deactivate(a['id'] as String),
                            tooltip: 'Désactiver',
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Inactive', style: TextStyle(fontSize: 10, color: AppColors.inkSoft)),
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
    );
  }
}
