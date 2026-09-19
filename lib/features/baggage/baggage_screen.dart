import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

class BaggageScreen extends StatefulWidget {
  const BaggageScreen({super.key});

  @override
  State<BaggageScreen> createState() => _BaggageScreenState();
}

class _BaggageScreenState extends State<BaggageScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  StreamSubscription<List<Map<String, dynamic>>>? _watchSub;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getMyFlights();
    _watchSub = SupabaseService.watchBaggagesRaw().listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = SupabaseService.getMyFlights();
    });
    await _future;
  }

  int _statusStep(String status) {
    switch (status) {
      case 'enregistre':
        return 0;
      case 'charge':
        return 1;
      case 'en_transit':
        return 2;
      case 'arrive':
        return 3;
      default:
        return 0;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'enregistre':
        return 'Enregistré';
      case 'charge':
        return 'Chargé en soute';
      case 'en_transit':
        return 'En transit';
      case 'arrive':
        return 'Arrivé au tapis';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes bagages')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final passes = snapshot.data ?? [];
            final allBaggages = <Map<String, dynamic>>[];

            for (final pass in passes) {
              final flight = pass['flights'] as Map<String, dynamic>?;
              final baggages = pass['baggages'] as List<dynamic>? ?? [];
              for (final b in baggages) {
                allBaggages.add({
                  ...b as Map<String, dynamic>,
                  'flight_number': flight?['flight_number'],
                  'destination_code': flight?['destination_code'],
                });
              }
            }

            if (allBaggages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(height: 80),
                        Icon(Icons.luggage_outlined, size: 56, color: AppColors.inkSoft),
                        SizedBox(height: 16),
                        Text(
                          'Aucun bagage enregistré pour le moment',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: allBaggages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) {
                final b = allBaggages[i];
                final status = b['status'] as String? ?? 'enregistre';
                final step = _statusStep(status);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.skyPale,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.luggage, color: AppColors.skyDeep),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b['tag_number'] as String? ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  '${b['flight_number'] ?? ''} → ${b['destination_code'] ?? ''}'
                                  '${b['weight_kg'] != null ? ' · ${b['weight_kg']} kg' : ''}',
                                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _BaggageProgress(currentStep: step),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          _statusLabel(status),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.skyDeep),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BaggageProgress extends StatelessWidget {
  final int currentStep;
  const _BaggageProgress({required this.currentStep});

  static const _labels = ['Enregistré', 'Chargé', 'Transit', 'Arrivé'];
  static const _icons = [Icons.check_circle_outline, Icons.luggage, Icons.flight, Icons.done_all];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_labels.length, (i) {
        final isDone = i <= currentStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i <= currentStep ? AppColors.skyDeep : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? AppColors.skyDeep : Colors.white,
                      border: Border.all(color: isDone ? AppColors.skyDeep : Colors.black.withValues(alpha: 0.15), width: 1.5),
                    ),
                    child: Icon(_icons[i], size: 13, color: isDone ? Colors.white : AppColors.inkSoft),
                  ),
                  if (i < _labels.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentStep ? AppColors.skyDeep : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(_labels[i], style: const TextStyle(fontSize: 9, color: AppColors.inkSoft)),
            ],
          ),
        );
      }),
    );
  }
}
