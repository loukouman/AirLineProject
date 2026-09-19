import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import 'scan_screen.dart';
import '../admin/admin_assistance_screen.dart';

class CheckinDeskScreen extends StatefulWidget {
  const CheckinDeskScreen({super.key});

  @override
  State<CheckinDeskScreen> createState() => _CheckinDeskScreenState();
}

class _CheckinDeskScreenState extends State<CheckinDeskScreen> {
  static const _statusOrder = ['enregistre', 'charge', 'en_transit', 'arrive'];
  static const _statusLabels = {
    'enregistre': 'Enregistré',
    'charge': 'Chargé en soute',
    'en_transit': 'En transit',
    'arrive': 'Arrivé au tapis',
  };

  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _futureFlights;
  late Future<int> _futureTodayCount;
  String? _selectedFlightId;
  String _query = '';
  StreamSubscription<List<Map<String, dynamic>>>? _watchSub;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getRecentCheckins();
    _futureFlights = SupabaseService.getAllFlights();
    _futureTodayCount = SupabaseService.getTodayCheckinsCount();

    _watchSub = SupabaseService.watchBoardingPassesRaw().listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = _selectedFlightId == null
          ? SupabaseService.getRecentCheckins()
          : SupabaseService.getCheckinsForFlight(_selectedFlightId!);
      _futureTodayCount = SupabaseService.getTodayCheckinsCount();
    });
  }

  void _selectFlight(String? flightId) {
    setState(() {
      _selectedFlightId = flightId;
      _query = '';
    });
    _refresh();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bonjour';
    if (hour >= 12 && hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  Future<void> _openBaggageManager(String boardingPassId, String passengerName, List<dynamic> baggages) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.08),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bagages · $passengerName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 14),
                if (baggages.isEmpty)
                  const Text('Aucun bagage enregistré.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12))
                else
                  ...baggages.map((b) {
                    final bag = b as Map<String, dynamic>;
                    final status = bag['status'] as String? ?? 'enregistre';
                    final currentIndex = _statusOrder.indexOf(status);
                    final nextStatus = currentIndex >= 0 && currentIndex < _statusOrder.length - 1
                        ? _statusOrder[currentIndex + 1]
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF3F7FA), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(bag['tag_number'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(_statusLabels[status] ?? status, style: const TextStyle(fontSize: 11, color: AppColors.inkSoft)),
                                ],
                              ),
                            ),
                            if (nextStatus != null)
                              TextButton(
                                onPressed: () async {
                                  await SupabaseService.advanceBaggageStatus(bag['id'] as String, nextStatus);
                                  if (context.mounted) Navigator.pop(context);
                                  _refresh();
                                },
                                child: Text('→ ${_statusLabels[nextStatus]}', style: const TextStyle(fontSize: 11)),
                              )
                            else
                              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final tagController = TextEditingController();
                      final weightController = TextEditingController();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Nouveau bagage'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: tagController,
                                autofocus: true,
                                decoration: const InputDecoration(labelText: 'Numéro de tag', border: OutlineInputBorder()),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: weightController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Poids (kg, optionnel)', border: OutlineInputBorder()),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                            FilledButton(
                              onPressed: tagController.text.trim().isEmpty ? null : () => Navigator.pop(context, true),
                              child: const Text('Ajouter'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && tagController.text.trim().isNotEmpty) {
                        await SupabaseService.addBaggage(
                          boardingPassId: boardingPassId,
                          tagNumber: tagController.text.trim(),
                          weightKg: double.tryParse(weightController.text.trim()),
                        );
                        if (context.mounted) Navigator.pop(context);
                        _refresh();
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Ajouter un bagage'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Agent';
    final firstName = fullName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.accessible),
            tooltip: 'Demandes d\'assistance PMR',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminAssistanceScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner une carte',
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
              _refresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async { await SupabaseService.signOut(); },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_greeting, $firstName', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 2),
                      FutureBuilder<int>(
                        future: _futureTodayCount,
                        builder: (context, snapshot) {
                          final count = snapshot.data;
                          return Text(
                            count == null ? 'Chargement...' : '$count voyageur(s) enregistré(s) aujourd\'hui',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.badge_outlined, color: Colors.white70, size: 32),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureFlights,
              builder: (context, snapshot) {
                final flights = snapshot.data ?? [];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      isExpanded: true,
                      value: _selectedFlightId,
                      hint: const Text('Tous les vols', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Tous les vols')),
                        ...flights.map((f) => DropdownMenuItem<String?>(
                              value: f['id'] as String,
                              child: Text('${f['flight_number']} · ${f['destination_code']}', style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      onChanged: _selectFlight,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filtrer par nom ou siège…',
                hintStyle: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.inkSoft),
                filled: true,
                fillColor: const Color(0xFFF3F7FA),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var passes = snapshot.data ?? [];
                  if (_query.isNotEmpty) {
                    passes = passes.where((p) {
                      final profile = p['profiles'] as Map<String, dynamic>?;
                      final name = (profile?['full_name'] as String? ?? '').toLowerCase();
                      final seat = (p['seat'] as String? ?? '').toLowerCase();
                      return name.contains(_query) || seat.contains(_query);
                    }).toList();
                  }

                  if (passes.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(60),
                          child: Text('Aucun enregistrement pour le moment.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedFlightId != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: AppColors.skyPale, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.groups_outlined, size: 16, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Text('${passes.length} voyageur(s) enregistré(s) sur ce vol', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: ListView.separated(
                          key: const PageStorageKey('checkin_list'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: passes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final p = passes[i];
                            final flight = p['flights'] as Map<String, dynamic>?;
                            final profile = p['profiles'] as Map<String, dynamic>?;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F7FA),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(radius: 16, backgroundColor: AppColors.skyPale, child: Icon(Icons.person, color: AppColors.primary, size: 16)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(profile?['full_name'] as String? ?? 'Voyageur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(
                                          '${flight?['flight_number'] ?? ''} · ${flight?['origin_code'] ?? ''} → ${flight?['destination_code'] ?? ''} · siège ${p['seat'] ?? '--'}',
                                          style: const TextStyle(color: AppColors.inkSoft, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm').format(DateTime.parse(p['checked_in_at'] as String)),
                                    style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
