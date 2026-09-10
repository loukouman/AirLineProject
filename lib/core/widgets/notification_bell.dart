import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../../features/notifications/notifications_screen.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _lastUnreadCount = 0;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: SupabaseService.watchMyNotifications(),
      builder: (context, snapshot) {
        final unreadCount =
            (snapshot.data ?? []).where((n) => (n['is_read'] as bool? ?? false) == false).length;

        if (!_initialized) {
          _lastUnreadCount = unreadCount;
          _initialized = true;
        } else if (unreadCount > _lastUnreadCount) {
          SystemSound.play(SystemSoundType.alert);
          _lastUnreadCount = unreadCount;
        } else {
          _lastUnreadCount = unreadCount;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: AppColors.ink),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$unreadCount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
