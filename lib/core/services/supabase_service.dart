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

  /// Solde de points fidélité du voyageur connecté.
  static Future<int> getMyLoyaltyPoints() async {
    final userId = currentUser?.id;
    if (userId == null) return 0;
    final result = await client.from('profiles').select('loyalty_points').eq('id', userId).maybeSingle();
    return result?['loyalty_points'] as int? ?? 0;
  }

  /// Historique des gains de points, du plus récent au plus ancien.
  static Future<List<Map<String, dynamic>>> getMyLoyaltyHistory() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final result = await client
        .from('loyalty_transactions')
        .select()
        .eq('passenger_id', userId)
        .order('created_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Flux temps réel du solde de points, pour une mise à jour automatique
  /// dès qu'un vol du voyageur décolle et lui rapporte des points.
  static Stream<List<Map<String, dynamic>>> watchMyLoyaltyPoints() {
    final userId = currentUser?.id;
    return client.from('profiles').stream(primaryKey: ['id']).eq('id', userId ?? '');
  }

  /// Ajoute un document de voyage dans le coffre-fort privé de l'utilisateur.
  /// Stocké dans un dossier nommé d'après son identifiant, pour que les
  /// règles de sécurité du stockage n'autorisent que lui à y accéder.
  static Future<void> addTravelDocument({
    required Uint8List bytes,
    required String fileName,
    required String docType,
    required String label,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('Non connecté');

    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await client.storage.from('travel-documents').uploadBinary(path, bytes);

    await client.from('travel_documents').insert({
      'owner_id': userId,
      'doc_type': docType,
      'label': label,
      'file_path': path,
    });
  }

  static Future<List<Map<String, dynamic>>> getMyTravelDocuments() async {
    final userId = currentUser?.id;
    if (userId == null) return [];
    final result = await client
        .from('travel_documents')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Génère une URL temporaire (1h) pour afficher un document privé —
  /// jamais d'URL publique permanente pour ce type de contenu sensible.
  static Future<String> getTravelDocumentSignedUrl(String filePath) {
    return client.storage.from('travel-documents').createSignedUrl(filePath, 3600);
  }

  static Future<void> deleteTravelDocument(String id, String filePath) async {
    await client.storage.from('travel-documents').remove([filePath]);
    await client.from('travel_documents').delete().eq('id', id);
  }

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

  /// Statistiques globales pour le tableau de bord administrateur :
  /// taux d'enregistrement par vol, répartition des statuts, et incidents
  /// récents — pour donner une vue business exploitable en un coup d'œil.
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final flights = await client.from('flights').select('id, flight_number, status, destination_city');
    final checkins = await client.from('boarding_passes').select('flight_id');
    final incidents = await client
        .from('security_incidents')
        .select('id, severity, created_at')
        .gte('created_at', DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String());

    final flightList = List<Map<String, dynamic>>.from(flights);
    final checkinList = List<Map<String, dynamic>>.from(checkins);
    final incidentList = List<Map<String, dynamic>>.from(incidents);

    final statusCounts = <String, int>{};
    for (final f in flightList) {
      final status = f['status'] as String? ?? 'a_l_heure';
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    final checkinsPerFlight = <String, int>{};
    for (final c in checkinList) {
      final flightId = c['flight_id'] as String?;
      if (flightId == null) continue;
      checkinsPerFlight[flightId] = (checkinsPerFlight[flightId] ?? 0) + 1;
    }

    final topFlights = flightList
        .map((f) => {
              'flight_number': f['flight_number'],
              'destination_city': f['destination_city'],
              'checkins': checkinsPerFlight[f['id']] ?? 0,
            })
        .toList()
      ..sort((a, b) => (b['checkins'] as int).compareTo(a['checkins'] as int));

    final ads = await client.from('ads').select('id, title, is_active');
    final adsList = List<Map<String, dynamic>>.from(ads);

    final lostItems = await client.from('lost_items').select('id, status');
    final lostItemsList = List<Map<String, dynamic>>.from(lostItems);
    final pendingLostItems = lostItemsList.where((l) => l['status'] != 'clos' && l['status'] != 'retrouve').length;

    final assistanceRequests = await client.from('assistance_requests').select('id, status');
    final assistanceList = List<Map<String, dynamic>>.from(assistanceRequests);
    final pendingAssistance = assistanceList.where((a) => a['status'] != 'terminee').length;

    return {
      'total_flights': flightList.length,
      'total_checkins': checkinList.length,
      'status_counts': statusCounts,
      'top_flights': topFlights.take(5).toList(),
      'incidents_7d': incidentList.length,
      'incidents_by_severity': {
        'faible': incidentList.where((i) => i['severity'] == 'faible').length,
        'moyenne': incidentList.where((i) => i['severity'] == 'moyenne').length,
        'elevee': incidentList.where((i) => i['severity'] == 'elevee').length,
      },
      'active_ads': adsList.where((a) => a['is_active'] == true).length,
      'total_ads': adsList.length,
      'total_lost_items': lostItemsList.length,
      'pending_lost_items': pendingLostItems,
      'total_assistance': assistanceList.length,
      'pending_assistance': pendingAssistance,
    };
  }

  static Future<List<Map<String, dynamic>>> getAllFlights() async {
    final result = await client.from('flights').select('*, airlines(name), gates(code)').order('scheduled_departure');
    return List<Map<String, dynamic>>.from(result);
  }

  static Stream<List<Map<String, dynamic>>> watchFlight(String flightId) {
    return client.from('flights').stream(primaryKey: ['id']).eq('id', flightId);
  }

  /// Flux brut de TOUS les changements sur la table flights (statut, porte,
  /// horaires...). Utilisé pour déclencher un rafraîchissement automatique
  /// des écrans dès qu'un admin modifie un vol, sans action de l'utilisateur.
  static Stream<List<Map<String, dynamic>>> watchAllFlightsRaw() {
    return client.from('flights').stream(primaryKey: ['id']);
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

  /// Met à jour uniquement le statut d'un vol existant (utilisé par l'admin
  /// pour la gestion rapide depuis la liste des vols).
  static Future<void> updateFlightStatus(String flightId, String status) {
    return client.from('flights').update({'status': status}).eq('id', flightId);
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

  static Future<void> uploadAd({
    required Uint8List bytes,
    required String fileName,
    required String title,
    String mediaType = 'image',
  }) async {
    final path = 'ads/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await client.storage.from('ads').uploadBinary(path, bytes);
    final url = client.storage.from('ads').getPublicUrl(path);
    await client.from('ads').insert({
      'image_url': url,
      'title': title,
      'is_active': true,
      'media_type': mediaType,
    });
  }

  /// Publicité vidéo en plusieurs segments, joués bout à bout comme un
  /// statut continu (contournement de l'absence de découpage vidéo côté app).
  static Future<void> uploadAdSegments({
    required List<Uint8List> segments,
    required List<String> fileNames,
    required String title,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < segments.length; i++) {
      final path = 'ads/${DateTime.now().millisecondsSinceEpoch}_${i}_${fileNames[i]}';
      await client.storage.from('ads').uploadBinary(path, segments[i]);
      urls.add(client.storage.from('ads').getPublicUrl(path));
    }
    await client.from('ads').insert({
      'image_url': urls.first,
      'media_urls': urls,
      'title': title,
      'is_active': true,
      'media_type': 'video',
    });
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

  /// Vue administrateur : tous les objets perdus signalés, tous voyageurs
  /// confondus, avec le nom du déclarant.
  static Future<List<Map<String, dynamic>>> getAllLostItems() async {
    final result = await client
        .from('lost_items')
        .select('*, profiles(full_name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> updateLostItemStatus(String id, String status) {
    return client.from('lost_items').update({'status': status}).eq('id', id);
  }

  /// Vue administrateur : toutes les demandes d'assistance PMR, tous
  /// voyageurs confondus, avec le nom du demandeur.
  static Future<List<Map<String, dynamic>>> getAllAssistanceRequests() async {
    final result = await client
        .from('assistance_requests')
        .select('*, profiles(full_name), flights(flight_number)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<void> updateAssistanceStatus(String id, String status) {
    return client.from('assistance_requests').update({'status': status}).eq('id', id);
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

  /// Nombre de voyageurs enregistrés aujourd'hui, tous vols confondus.
  /// Utilisé pour le résumé du jour affiché à l'agent d'enregistrement.
  static Future<int> getTodayCheckinsCount() async {
    final startOfDay = DateTime.now().toUtc().copyWith(hour: 0, minute: 0, second: 0, microsecond: 0);
    final result = await client
        .from('boarding_passes')
        .select('id')
        .gte('checked_in_at', startOfDay.toIso8601String());
    return (result as List).length;
  }

  /// Flux temps réel des enregistrements : rafraîchit automatiquement
  /// l'écran de l'agent quand un autre agent enregistre un voyageur.
  static Stream<List<Map<String, dynamic>>> watchBoardingPassesRaw() {
    return client.from('boarding_passes').stream(primaryKey: ['id']);
  }

  /// Flux temps réel des zones de sûreté : synchronise automatiquement
  /// plusieurs agents qui consultent l'écran en même temps.
  static Stream<List<Map<String, dynamic>>> watchSecurityZonesRaw() {
    return client.from('security_zones').stream(primaryKey: ['id']);
  }

  /// Signale un incident ou objet suspect au poste de sûreté, avec une
  /// photo optionnelle jointe (preuve visuelle, objet trouvé, etc.).
  static Future<void> reportSecurityIncident({
    String? zoneId,
    required String title,
    String? description,
    String severity = 'moyenne',
    Uint8List? photoBytes,
  }) async {
    final userId = currentUser?.id;
    String? photoUrl;

    if (photoBytes != null) {
      final path = 'incidents/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await client.storage.from('incident-photos').uploadBinary(path, photoBytes);
      photoUrl = client.storage.from('incident-photos').getPublicUrl(path);
    }

    await client.from('security_incidents').insert({
      'reporter_id': userId,
      'zone_id': zoneId,
      'title': title,
      'description': description,
      'severity': severity,
      'photo_url': photoUrl,
    });
  }

  /// Historique des incidents signalés, du plus récent au plus ancien,
  /// avec le nom de la zone et de l'agent qui a signalé.
  static Future<List<Map<String, dynamic>>> getSecurityIncidents() async {
    final result = await client
        .from('security_incidents')
        .select('*, security_zones(name), profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(result);
  }

  static Future<List<Map<String, dynamic>>> getRecentCheckins() async {
    final result = await client
        .from('boarding_passes')
        .select('*, flights(flight_number, origin_code, destination_code), profiles(full_name), baggages(*)')
        .order('checked_in_at', ascending: false)
        .limit(30);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Enregistre un nouveau bagage (tag) pour une carte d'embarquement donnée,
  /// au moment du check-in.
  static Future<void> addBaggage({
    required String boardingPassId,
    required String tagNumber,
    double? weightKg,
  }) {
    return client.from('baggages').insert({
      'boarding_pass_id': boardingPassId,
      'tag_number': tagNumber,
      'weight_kg': weightKg,
      'status': 'enregistre',
    });
  }

  /// Fait avancer le statut d'un bagage à l'étape suivante de son parcours
  /// (enregistré → chargé → en transit → arrivé). Déclenche automatiquement
  /// la notification correspondante côté base de données.
  static Future<void> advanceBaggageStatus(String baggageId, String newStatus) {
    return client.from('baggages').update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', baggageId);
  }

  /// Flux temps réel des bagages : rafraîchit automatiquement l'écran du
  /// voyageur quand un agent fait avancer le statut de son bagage.
  static Stream<List<Map<String, dynamic>>> watchBaggagesRaw() {
    return client.from('baggages').stream(primaryKey: ['id']);
  }

  /// Enregistrements pour un vol précis, utilisé par le desk d'enregistrement
  /// quand l'agent filtre sur le vol qu'il traite actuellement.
  static Future<List<Map<String, dynamic>>> getCheckinsForFlight(String flightId) async {
    final result = await client
        .from('boarding_passes')
        .select('*, flights(flight_number, origin_code, destination_code), profiles(full_name)')
        .eq('flight_id', flightId)
        .order('checked_in_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  /// Recherche de secours par nom de voyageur ou numéro de siège, pour les
  /// cas où le QR code ne scanne pas (écran endommagé, mauvais éclairage...).
  static Future<List<Map<String, dynamic>>> searchCheckins(String query) async {
    if (query.trim().isEmpty) return [];

    final byName = await client
        .from('boarding_passes')
        .select('*, flights(*, airlines(name), gates(code)), profiles!inner(full_name)')
        .ilike('profiles.full_name', '%${query.trim()}%')
        .limit(15);

    final bySeat = await client
        .from('boarding_passes')
        .select('*, flights(*, airlines(name), gates(code)), profiles(full_name)')
        .ilike('seat', '%${query.trim()}%')
        .limit(15);

    final merged = <String, Map<String, dynamic>>{};
    for (final row in [...byName, ...bySeat]) {
      merged[row['id'] as String] = row as Map<String, dynamic>;
    }
    return merged.values.toList();
  }
}
