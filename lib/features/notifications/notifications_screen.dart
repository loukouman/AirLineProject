import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Le simple fait d'ouvrir cet écran marque toutes les notifications comme lues.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SupabaseService.markAllNotificationsAsRead();
    });
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'changement_porte':
        return Icons.door_front_door_outlined;
      case 'retard':
        return Icons.schedule;
      case 'embarquement':
        return Icons.flight_takeoff;
      case 'bagage':
        return Icons.luggage;
      default:
        return Icons.campaign_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.watchMyNotifications(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 56, color: AppColors.inkSoft),
                    SizedBox(height: 16),
                    Text('Aucune notification pour le moment', style: TextStyle(color: AppColors.inkSoft)),
                  ],
                ),
              ),
            );
          }

          final sorted = [...notifications]
            ..sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = sorted[i];
              final isRead = n['is_read'] as bool? ?? false;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isRead ? Colors.white : AppColors.skyPale,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(_iconFor(n['type'] as String? ?? ''), size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text(n['body'] as String? ?? '', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd/MM HH:mm').format(DateTime.parse(n['created_at'] as String)),
                            style: const TextStyle(color: AppColors.inkSoft, fontSize: 10),
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
    );
  }
}
