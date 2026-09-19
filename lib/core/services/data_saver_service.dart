import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Gère le mode économe en données : 'auto' (activé automatiquement en
/// données mobiles, désactivé en Wi-Fi), 'on' (toujours activé),
/// 'off' (toujours désactivé). Le choix de l'utilisateur est mémorisé
/// localement et respecté même hors ligne.
class DataSaverService {
  DataSaverService._();

  static const _key = 'data_saver_mode';
  static Box get _box => Hive.box('envol_cache');

  /// Préférence choisie par l'utilisateur : 'auto' | 'on' | 'off'.
  static final ValueNotifier<String> mode = ValueNotifier('auto');

  /// Valeur effective à respecter à l'instant T (calculée à partir du
  /// mode et, en 'auto', de la connexion réseau réelle).
  static final ValueNotifier<bool> effective = ValueNotifier(false);

  static StreamSubscription<List<ConnectivityResult>>? _sub;
  static List<ConnectivityResult> _lastResults = [];

  static Future<void> initialize() async {
    mode.value = _box.get(_key, defaultValue: 'auto') as String;

    final connectivity = Connectivity();
    _lastResults = await connectivity.checkConnectivity();
    _recompute();

    _sub = connectivity.onConnectivityChanged.listen((results) {
      _lastResults = results;
      _recompute();
    });

    mode.addListener(_recompute);
  }

  static void _recompute() {
    switch (mode.value) {
      case 'on':
        effective.value = true;
        break;
      case 'off':
        effective.value = false;
        break;
      default: // auto
        final hasWifi = _lastResults.contains(ConnectivityResult.wifi) ||
            _lastResults.contains(ConnectivityResult.ethernet);
        final hasAnyConnection = _lastResults.isNotEmpty && !_lastResults.contains(ConnectivityResult.none);
        effective.value = hasAnyConnection && !hasWifi;
    }
  }

  static Future<void> setMode(String newMode) async {
    mode.value = newMode;
    await _box.put(_key, newMode);
  }

  static void dispose() {
    _sub?.cancel();
  }
}
