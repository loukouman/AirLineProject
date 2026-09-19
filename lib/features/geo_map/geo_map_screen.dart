import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_theme.dart';

class GeoMapScreen extends StatefulWidget {
  const GeoMapScreen({super.key});

  @override
  State<GeoMapScreen> createState() => _GeoMapScreenState();
}

class _GeoMapScreenState extends State<GeoMapScreen> {
  static const LatLng _airportPosition = LatLng(12.3532, -1.5124);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng? _searchedPlace;
  String? _searchedLabel;
  LatLng? _myPosition;
  List<LatLng> _routePoints = [];
  String? _routeInfo;
  bool _searching = false;
  bool _locating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _recenter() {
    _mapController.move(_airportPosition, 15);
  }

  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searching = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'EnvolApp/1.0'});

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        if (results.isEmpty) {
          setState(() => _errorMessage = 'Aucun lieu trouvé pour "$query"');
        } else {
          final result = results.first as Map<String, dynamic>;
          final lat = double.parse(result['lat'] as String);
          final lon = double.parse(result['lon'] as String);
          final place = LatLng(lat, lon);
          setState(() {
            _searchedPlace = place;
            _searchedLabel = result['display_name'] as String?;
          });
          _mapController.move(place, 14);
        }
      } else {
        setState(() => _errorMessage = 'Recherche indisponible pour le moment');
      }
    } catch (_) {
      setState(() => _errorMessage = 'Vérifie ta connexion internet');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _findMyPosition() async {
    setState(() {
      _locating = true;
      _errorMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _errorMessage = 'Active la localisation sur ton téléphone');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _errorMessage = "Autorisation de localisation refusée");
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final me = LatLng(position.latitude, position.longitude);
      setState(() => _myPosition = me);
      _mapController.move(me, 14);
    } catch (_) {
      setState(() => _errorMessage = 'Impossible de récupérer ta position');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _getDirectionsToAirport() async {
    setState(() {
      _errorMessage = null;
      _routePoints = [];
      _routeInfo = null;
    });

    LatLng? origin = _myPosition;
    if (origin == null) {
      await _findMyPosition();
      origin = _myPosition;
    }
    if (origin == null) return;

    try {
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};${_airportPosition.longitude},${_airportPosition.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes == null || routes.isEmpty) {
          setState(() => _errorMessage = "Itinéraire indisponible pour cette position");
          return;
        }
        final route = routes.first as Map<String, dynamic>;
        final coords = (route['geometry']['coordinates'] as List<dynamic>)
            .map((c) => LatLng((c as List)[1] as double, c[0] as double))
            .toList();

        final durationMin = ((route['duration'] as num) / 60).round();
        final distanceKm = ((route['distance'] as num) / 1000).toStringAsFixed(1);

        setState(() {
          _routePoints = coords;
          _routeInfo = '$distanceKm km · environ $durationMin min en voiture';
        });

        _mapController.fitCamera(CameraFit.coordinates(coordinates: coords, padding: const EdgeInsets.all(40)));
      } else {
        setState(() => _errorMessage = "Itinéraire indisponible pour le moment");
      }
    } catch (_) {
      setState(() => _errorMessage = 'Vérifie ta connexion internet');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _airportPosition,
              initialZoom: 15,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.airline_word_mobile',
              ),

              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, strokeWidth: 4, color: AppColors.primary),
                  ],
                ),

              MarkerLayer(
                markers: [
                  Marker(
                    point: _airportPosition,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.flight, color: Colors.white, size: 22),
                    ),
                  ),
                  if (_myPosition != null)
                    Marker(
                      point: _myPosition!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF378ADD),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                        ),
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ),
                  if (_searchedPlace != null)
                    Marker(
                      point: _searchedPlace!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                    ),
                ],
              ),

              const RichAttributionWidget(
                attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
              ),
            ],
          ),

          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un lieu…',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.inkSoft),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                ),
                onSubmitted: _searchPlace,
              ),
            ),
          ),

          if (_errorMessage != null)
            Positioned(
              top: 70,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(12)),
                child: Text(_errorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFF791F1F))),
              ),
            ),

          if (_routeInfo != null)
            Positioned(
              bottom: 90,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_routeInfo!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'directions',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: _getDirectionsToAirport,
                  child: const Icon(Icons.directions),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF378ADD),
                  onPressed: _locating ? null : _findMyPosition,
                  child: _locating
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'recenter',
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _recenter,
                  child: const Icon(Icons.flight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
