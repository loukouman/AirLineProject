import 'package:firebase_messaging/firebase_messaging.dart';
import 'supabase_service.dart';

/// Gère la permission de notifications, la récupération du token FCM
/// (identifiant unique de cet appareil auprès de Firebase) et son
/// enregistrement dans Supabase pour ce voyageur.
class PushNotificationService {
  PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null) {
      await _saveToken(token);
    }

    // Si le token change (réinstallation, etc.), on le met à jour automatiquement.
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    await SupabaseService.client.from('profiles').update({'fcm_token': token}).eq('id', userId);
  }
}
