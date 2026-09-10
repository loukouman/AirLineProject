import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Sauvegarde locale des cartes d'embarquement, pour un accès
/// même sans connexion réseau.
class OfflineCacheService {
  OfflineCacheService._();

  static Box get _box => Hive.box('envol_cache');
  static const _flightsKey = 'my_flights';
  static const _savedAtKey = 'my_flights_saved_at';

  static Future<void> cacheFlights(List<Map<String, dynamic>> flights) async {
    await _box.put(_flightsKey, jsonEncode(flights));
    await _box.put(_savedAtKey, DateTime.now().toIso8601String());
  }

  static List<Map<String, dynamic>> getCachedFlights() {
    final raw = _box.get(_flightsKey) as String?;
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static DateTime? getLastSavedAt() {
    final raw = _box.get(_savedAtKey) as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }
}
