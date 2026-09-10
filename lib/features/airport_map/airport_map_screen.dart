import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class AirportMapScreen extends StatefulWidget {
  const AirportMapScreen({super.key});

  @override
  State<AirportMapScreen> createState() => _AirportMapScreenState();
}

class _AirportMapScreenState extends State<AirportMapScreen> {
  late Future<List<Map<String, dynamic>>> _futureGates;
  late Future<List<Map<String, dynamic>>> _futureSecurity;
  late Future<List<Map<String, dynamic>>> _futureAmenities;
  Map<String, dynamic>? _selectedGate;
  String _query = '';
  bool _showAmenities = true;

  @override
  void initState() {
    super.initState();
    _futureGates = SupabaseService.getGates();
    _futureSecurity = SupabaseService.getSecurityZones();
    _futureAmenities = SupabaseService.getAmenities();
  }

  IconData _amenityIcon(String type) {
    switch (type) {
      case 'restaurant':
        return Icons.restaurant;
      case 'boutique':
        return Icons.shopping_bag_outlined;
      case 'toilette':
        return Icons.wc;
      case 'prise_electrique':
        return Icons.power;
      case 'wifi':
        return Icons.wifi;
      case 'change':
        return Icons.currency_exchange;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan interactif')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ----- Temps d'attente sûreté -----
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureSecurity,
              builder: (context, snapshot) {
                final zones = snapshot.data ?? [];
                if (zones.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: zones.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final z = zones[i];
                        final wait = z['estimated_wait_minutes'] as int? ?? 0;
                        final color = wait <= 10 ? AppColors.success : (wait <= 20 ? Colors.orange : Colors.redAccent);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(z['name'] as String, style: const TextStyle(fontSize: 10, color: AppColors.inkSoft, fontWeight: FontWeight.bold)),
                              Row(children: [
                                Icon(Icons.timer_outlined, size: 13, color: color),
                                const SizedBox(width: 3),
                                Text('$wait min', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                              ]),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            // ----- Recherche -----
            TextField(
              decoration: InputDecoration(
                hintText: 'Chercher une porte, un service…',
                hintStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.inkSoft),
                filled: true,
                fillColor: const Color(0xFFF3F7FA),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toUpperCase()),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Text('Afficher les commerces & services', style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                const Spacer(),
                Switch(
                  value: _showAmenities,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _showAmenities = v),
                ),
              ],
            ),

            // ----- Carte -----
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureGates,
                builder: (context, gateSnap) {
                  if (gateSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var gates = gateSnap.data ?? [];
                  if (_query.isNotEmpty) {
                    gates = gates.where((g) => (g['code'] as String).toUpperCase().contains(_query)).toList();
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FA),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    ),
                    child: Stack(
                      children: [
                        ...gates.map((g) {
                          final x = (g['map_x'] as num?)?.toDouble() ?? 50;
                          final y = (g['map_y'] as num?)?.toDouble() ?? 50;
                          final isSelected = _selectedGate?['id'] == g['id'];

                          return Align(
                            alignment: Alignment((x / 100) * 2 - 1, (y / 100) * 2 - 1),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedGate = g),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.textDark,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3))],
                                ),
                                child: Text(g['code'] as String, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        }),

                        if (_showAmenities)
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _futureAmenities,
                            builder: (context, amenitySnap) {
                              final amenities = amenitySnap.data ?? [];
                              return Stack(
                                children: amenities.map((a) {
                                  final x = (a['map_x'] as num?)?.toDouble() ?? 50;
                                  final y = (a['map_y'] as num?)?.toDouble() ?? 50;
                                  return Align(
                                    alignment: Alignment((x / 100) * 2 - 1, (y / 100) * 2 - 1),
                                    child: GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('${a['name']}${a['description'] != null ? ' — ${a['description']}' : ''}')),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.inkSoft.withValues(alpha: 0.3)),
                                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                                        ),
                                        child: Icon(_amenityIcon(a['type'] as String), size: 13, color: AppColors.inkSoft),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),
            if (_selectedGate != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DESTINATION', style: TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 0.5)),
                        Text('Porte ${_selectedGate!['code']} · ${_selectedGate!['walk_time_minutes'] ?? '?'} min à pied',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
