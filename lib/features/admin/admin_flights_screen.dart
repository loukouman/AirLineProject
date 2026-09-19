import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

class AdminFlightsScreen extends StatefulWidget {
  const AdminFlightsScreen({super.key});

  @override
  State<AdminFlightsScreen> createState() => _AdminFlightsScreenState();
}

class _AdminFlightsScreenState extends State<AdminFlightsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _flightNumberController = TextEditingController();
  final _originCodeController = TextEditingController();
  final _originCityController = TextEditingController();
  final _destinationCodeController = TextEditingController();
  final _destinationCityController = TextEditingController();

  String? _selectedAirlineId;
  String? _selectedGateId;
  DateTime? _departure;
  DateTime? _boarding;
  bool _submitting = false;

  late Future<List<Map<String, dynamic>>> _futureAirlines;
  late Future<List<Map<String, dynamic>>> _futureGates;

  late Future<List<Map<String, dynamic>>> _futureFlights;

  static const _statusLabels = {
    'a_l_heure': 'À l\'heure',
    'retarde': 'Retardé',
    'embarquement': 'Embarquement',
    'decolle': 'Décollé',
    'annule': 'Annulé',
  };
  static const _statusOrder = ['a_l_heure', 'retarde', 'embarquement', 'decolle', 'annule'];

  @override
  void initState() {
    super.initState();
    _futureAirlines = SupabaseService.getAirlines();
    _futureGates = SupabaseService.getGates();
    _futureFlights = SupabaseService.getAllFlights();
  }

  void _refreshFlights() {
    setState(() {
      _futureFlights = SupabaseService.getAllFlights();
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'retarde':
        return Colors.orange;
      case 'annule':
        return Colors.redAccent;
      case 'embarquement':
        return const Color(0xFF378ADD);
      case 'decolle':
        return AppColors.inkSoft;
      default:
        return AppColors.success;
    }
  }

  Future<void> _changeFlightStatus(String flightId, String current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: _statusOrder.map((s) {
          return ListTile(
            title: Text(_statusLabels[s]!),
            trailing: s == current ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(context, s),
          );
        }).toList(),
      ),
    );
    if (result != null && result != current) {
      await SupabaseService.updateFlightStatus(flightId, result);
      _refreshFlights();
    }
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _originCodeController.dispose();
    _originCityController.dispose();
    _destinationCodeController.dispose();
    _destinationCityController.dispose();
    super.dispose();
  }

  Future<void> _pickDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return;

    setState(() {
      _departure = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _boarding = _departure!.subtract(const Duration(minutes: 40));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAirlineId == null || _departure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compagnie et date/heure de départ sont obligatoires.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await SupabaseService.createFlight(
        flightNumber: _flightNumberController.text.trim().toUpperCase(),
        airlineId: _selectedAirlineId!,
        originCode: _originCodeController.text.trim().toUpperCase(),
        originCity: _originCityController.text.trim(),
        destinationCode: _destinationCodeController.text.trim().toUpperCase(),
        destinationCity: _destinationCityController.text.trim(),
        scheduledDeparture: _departure!,
        scheduledArrival: _departure!.add(const Duration(hours: 6)),
        boardingTime: _boarding,
        gateId: _selectedGateId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vol créé avec succès.')),
        );
        _formKey.currentState!.reset();
        _flightNumberController.clear();
        _originCodeController.clear();
        _originCityController.clear();
        _destinationCodeController.clear();
        _destinationCityController.clear();
        setState(() {
          _selectedAirlineId = null;
          _selectedGateId = null;
          _departure = null;
          _boarding = null;
        });
        _refreshFlights();
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouveau vol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 14),

            TextFormField(
              controller: _flightNumberController,
              decoration: const InputDecoration(labelText: 'Numéro de vol (ex: AF719)', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureAirlines,
              builder: (context, snapshot) {
                final airlines = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _selectedAirlineId,
                  decoration: const InputDecoration(labelText: 'Compagnie aérienne', border: OutlineInputBorder()),
                  items: airlines
                      .map((a) => DropdownMenuItem(value: a['id'] as String, child: Text(a['name'] as String)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAirlineId = v),
                );
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _originCodeController,
                    decoration: const InputDecoration(labelText: 'Code origine (OUA)', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _originCityController,
                    decoration: const InputDecoration(labelText: 'Ville origine', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _destinationCodeController,
                    decoration: const InputDecoration(labelText: 'Code destination (CDG)', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _destinationCityController,
                    decoration: const InputDecoration(labelText: 'Ville destination', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureGates,
              builder: (context, snapshot) {
                final gates = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _selectedGateId,
                  decoration: const InputDecoration(labelText: 'Porte d\'embarquement', border: OutlineInputBorder()),
                  items: gates
                      .map((g) => DropdownMenuItem(value: g['id'] as String, child: Text(g['code'] as String)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGateId = v),
                );
              },
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: _pickDeparture,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date et heure de départ', border: OutlineInputBorder()),
                child: Text(
                  _departure == null
                      ? 'Toucher pour choisir'
                      : '${_departure!.day}/${_departure!.month}/${_departure!.year} · ${_departure!.hour.toString().padLeft(2, '0')}:${_departure!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: _departure == null ? AppColors.inkSoft : AppColors.ink),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: AppColors.skyDeep, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer le vol'),
              ),
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Vols existants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureFlights,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final flights = snapshot.data ?? [];
                if (flights.isEmpty) {
                  return const Text('Aucun vol programmé pour le moment.', style: TextStyle(color: AppColors.inkSoft, fontSize: 12));
                }
                return Column(
                  children: flights.map((f) {
                    final status = f['status'] as String? ?? 'a_l_heure';
                    final color = _statusColor(status);
                    final airline = f['airlines'] as Map<String, dynamic>?;
                    final gate = f['gates'] as Map<String, dynamic>?;
                    final departure = DateTime.tryParse(f['scheduled_departure'] as String? ?? '');

                    return InkWell(
                      key: ValueKey(f['id']),
                      onTap: () => _changeFlightStatus(f['id'] as String, status),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${f['flight_number']} · ${f['destination_city'] ?? f['destination_code']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '${airline?['name'] ?? ''} · Porte ${gate?['code'] ?? '--'}'
                                    '${departure != null ? ' · ' + DateFormat('dd/MM HH:mm').format(departure) : ''}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text(_statusLabels[status] ?? status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
