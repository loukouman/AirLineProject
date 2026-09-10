import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  late Future<List<Map<String, dynamic>>> _futureFlights;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _futureFlights = _loadAvailableFlights();
  }

  Future<List<Map<String, dynamic>>> _loadAvailableFlights() async {
    final userId = SupabaseService.currentUser?.id;

    final flights = await SupabaseService.client
        .from('flights')
        .select('*, airlines(name)')
        .order('scheduled_departure');

    if (userId == null) return List<Map<String, dynamic>>.from(flights);

    final existingPasses = await SupabaseService.client
        .from('boarding_passes')
        .select('flight_id')
        .eq('passenger_id', userId);

    final alreadyCheckedInIds =
        (existingPasses as List).map((p) => p['flight_id'] as String).toSet();

    return List<Map<String, dynamic>>.from(flights)
        .where((f) => !alreadyCheckedInIds.contains(f['id']))
        .toList();
  }

  Future<void> _checkIn(Map<String, dynamic> flight) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    setState(() => _submitting = true);
    try {
      await SupabaseService.client.from('boarding_passes').insert({
        'passenger_id': userId,
        'flight_id': flight['id'],
        'seat': _randomSeat(),
        'boarding_group': '${1 + (DateTime.now().millisecond % 4)}',
        'travel_class': 'ECO',
        'status': 'enregistre',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enregistrement réussi ! Va voir ta carte d\'embarquement.')),
        );
        Navigator.of(context).pop(true);
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

  String _randomSeat() {
    final row = 5 + (DateTime.now().microsecond % 25);
    final letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    final letter = letters[DateTime.now().millisecond % letters.length];
    return '$row$letter';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM · HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrement')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureFlights,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final flights = snapshot.data ?? [];
          if (flights.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun vol disponible pour l\'enregistrement en ce moment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: flights.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final f = flights[i];
              final airline = f['airlines'] as Map<String, dynamic>?;

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${f['flight_number']} · ${airline?['name'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${f['origin_code']} → ${f['destination_code']}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(DateTime.parse(f['scheduled_departure'] as String)),
                            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _submitting ? null : () => _checkIn(f),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.skyDeep),
                      child: const Text('S\'enregistrer'),
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
