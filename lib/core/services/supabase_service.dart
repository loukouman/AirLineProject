import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'offline_cache_service.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) {
    return client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => client.auth.signOut();

  static Future<String> getMyRole() async {
    final userId = currentUser?.id;
    if (userId == null) return 'voyageur';
    final result = await client.from('profiles').select('role').eq('id', userId).maybeSingle();
    return result?['role'] as String? ?? 'voyageur';
  }

  /// true si les dernières données affichées venaient du cache local
  /// (pas de connexion au moment de la requête).
  static bool lastFlightsFromCache = false;

  static Future<List<Map<String, dynamic>>> getMyFlights() async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    try {
      final result = await client
          .from('boarding_passes')
          .select('*, flights(*, airlines(name), gates(code)), baggages(*)')
          .eq('passenger_id', userId);

      final list = List<Map<String, dynamic>>.from(result);
      list.sort((a, b) {
        final fa = a['flights'] as Map<String, dynamic>?;
        final fb = b['flights'] as Map<String, dynamic>?;
        final da = fa != null ? DateTime.parse(fa['scheduled_departure'] as String) : DateTime(2100);
        final db = fb != null ? DateTime.parse(fb['scheduled_departure'] as String) : DateTime(2100);
        return da.compareTo(db);
      });

      lastFlightsFromCache = false;
      await OfflineCacheService.cacheFlights(list);
      return list;
    } catch (e) {
      final cached = OfflineCacheService.getCachedFlights();
      lastFlightsFromCache = true;
      return cached;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllFlights() async {
    final result = await client.from('flights').select('*, airlines(name), gates(code)').order('scheduled_departure');
    return List<Map<String, dynamic>>.from(result);
  }

  static Stream<List<Map<String, dynamic>>> watchFlight(String flightId) {
    return client.from('flights').stream(primaryKey: ['id']).eq('id', flightId);
  }

  static Future<List<Map<String, dynamic>>> getJourneyEvents(String flightId) async {
    final userId = currentUser?.id;
    if (userId == null) return [];

    final result = await client
        .from('journey_events')
        .select()
        .eq('passenger_id', userId)
        .eq('flight_id', flightId);

    final list = List<Map<String, dynamic>>.from(result);
    list.sort((a, b) {
      final ta = DateTime.parse(a['event_time'] as String);
      final tb = DateTime.parse(b['event_time'] as String);
      return ta.compareTo(tb);
    });
    return list;
  }

  static Stream<List<Map<String, dynamic>>> watchMyNotifications() {
    final userId = currentUser?.id;
    return client.from('notifications').stream(primaryKey: ['id']).eq('recipient_id', userId ?? '').order('created_at');
  }

  static Future<void> markNotificationAsRead(String notificationId) {
    return client.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  // ---------------------------------------------------------------------
  // Administration
  // ---------------------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getAirlines() async {
    final result = await client.from('airlines').select().order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<List<Map<String, dynamic>>> getGates() async {
    final result = await client.from('gates').select().order('code');
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> createFlight({
    required String flightNumber,
    required String airlineId,
    required String originCode,
    required String originCity,
    required String destinationCode,
    required String destinationCity,
    required DateTime scheduledDeparture,
    required DateTime scheduledArrival,
    DateTime? boardingTime,
    String? gateId,
  }) {
    return client.from('flights').insert({
      'flight_number': flightNumber,
      'airline_id': airlineId,
      'origin_code': originCode,
      'origin_city': originCity,
      'destination_code': destinationCode,
      'destination_city': destinationCity,
      'scheduled_departure': scheduledDeparture.toIso8601String(),
      'scheduled_arrival': scheduledArrival.toIso8601String(),
      'boarding_time': boardingTime?.toIso8601String(),
      'gate_id': gateId,
      'status': 'a_l_heure',
    });
  }

  static Future<List<Map<String, dynamic>>> getAllAlerts() async {
    final result = await client.from('alerts').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> createAlert({required String title, required String message}) {
    final userId = currentUser?.id;
    return client.from('alerts').insert({'author_id': userId, 'title': title, 'message': message, 'is_active': true});
  }

  static Future<void> deactivateAlert(String alertId) {
    return client.from('alerts').update({'is_active': false}).eq('id', alertId);
  }

  /// Liste tous les comptes (voyageurs, agents, admins) pour la gestion des rôles.
  static Future<List<Map<String, dynamic>>> getAllProfiles() async {
    final result = await client.from('profiles').select().order('full_name');
    return List<Map<String, dynamic>>.from(result);
  }

  /// Change le rôle d'un compte. Réservé à l'admin (RLS le vérifie côté serveur).
  static Future<void> updateUserRole(String userId, String newRole) {
    return client.from('profiles').update({'role': newRole}).eq('id', userId);
  }

  // ---------------------------------------------------------------------
  // Publicités (bandeau accueil)
  // ---------------------------------------------------------------------

  static Stream<List<Map<String, dynamic>>> watchActiveAds() {
    return client
        .from('ads')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.where((r) => r['is_active'] == true).toList());
  }

  static Future<List<Map<String, dynamic>>> getAllAds() async {
    final result = await client.from('ads').select().order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> uploadAd({required Uint8List bytes, required String fileName, required String title}) async {
    final path = 'ads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await client.storage.from('ads').uploadBinary(path, bytes);
    final url = client.storage.from('ads').getPublicUrl(path);
    await client.from('ads').insert({'image_url': url, 'title': title, 'is_active': true});
  }

  static Future<void> deleteAd(String adId, String imageUrl) async {
    await client.from('ads').delete().eq('id', adId);
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final index = segments.indexOf('ads');
      if (index != -1 && index + 1 < segments.length) {
        final storagePath = segments.sublist(index + 1).join('/');
        await client.storage.from('ads').remove([storagePath]);
      }
    } catch (_) {
      // La suppression du fichier physique est best-effort ; la ligne DB est déjà supprimée.
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    final userId = currentUser?.id;
    if (userId == null) return;
    await client.from('notifications').update({'is_read': true}).eq('recipient_id', userId).eq('is_read', false);
  }

  static Future<String?> getMyAvatarUrl() async {
    final userId = currentUser?.id;
    if (userId == null) return null;
    final result = await client.from('profiles').select('avatar_url').eq('id', userId).maybeSingle();
    return result?['avatar_url'] as String?;
  }

  static Future<String> uploadMyAvatar(Uint8List bytes, String fileName) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Non connecté');

    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await client.storage.from('avatars').uploadBinary(
      path, bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    final url = client.storage.from('avatars').getPublicUrl(path);
    await client.from('profiles').update({'avatar_url': url}).eq('id', userId);
    return url;
  }

  static Future<List<Map<String, dynamic>>> getSecurityZones() async {
    final result = await client.from('security_zones').select().order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<List<Map<String, dynamic>>> getAmenities() async {
    final result = await client.from('amenities').select().order('name');
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> reportLostItem({required String description, String? locationLost}) {
    final userId = currentUser?.id;
    return client.from('lost_items').insert({
      'reporter_id': userId,
      'description': description,
      'location_lost': locationLost,
      'status': 'signale',
    });
  }

  static Future<List<Map<String, dynamic>>> getMyLostItems() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final result = await client.from('lost_items').select().eq('reporter_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> requestAssistance({String? flightId, String? details}) {
    final userId = currentUser?.id;
    return client.from('assistance_requests').insert({
      'passenger_id': userId,
      'flight_id': flightId,
      'details': details,
      'status': 'demandee',
    });
  }

  static Future<List<Map<String, dynamic>>> getMyAssistanceRequests() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final result = await client.from('assistance_requests').select().eq('passenger_id', userId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<List<Map<String, dynamic>>> getActiveAdsOnce() async {
    final result = await client.from('ads').select().eq('is_active', true).order('created_at');
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> signInWithGoogle() async {
    const webClientId = '770299498838-1bqiiv2vdsq8e97s20afbs8ejjl0kll4.apps.googleusercontent.com';

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: webClientId);

    final googleUser = await googleSignIn.authenticate();
    final idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('Impossible de récupérer le jeton Google');
    }

    await client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  static Future<void> updateSecurityZoneWait(String zoneId, int minutes) {
    return client.from('security_zones').update({
      'estimated_wait_minutes': minutes,
      'updated_by': currentUser?.id,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', zoneId);
  }

  static Future<List<Map<String, dynamic>>> getRecentCheckins() async {
    final result = await client
        .from('boarding_passes')
        .select('*, flights(flight_number, origin_code, destination_code), profiles(full_name)')
        .order('checked_in_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(result);
  }
}
