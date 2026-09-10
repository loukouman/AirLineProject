import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/flight.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/weather_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_bell.dart';
import '../../core/widgets/ad_banner.dart';
import '../../core/widgets/offline_banner.dart';
import '../../core/widgets/ticket_shape.dart';
import '../checkin/checkin_screen.dart';
import '../tracking/tracking_screen.dart';
import '../airport_map/airport_map_screen.dart';
import '../parking/parking_screen.dart';
import '../baggage/baggage_screen.dart';
import '../lost_items/lost_items_screen.dart';
import '../assistance/assistance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _futureFlights;

  @override
  void initState() {
    super.initState();
    _futureFlights = SupabaseService.getMyFlights();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 18) return 'Bonjour';
    return 'Bonsoir';
  }

  Future<void> _refresh() async {
    setState(() {
      _futureFlights = SupabaseService.getMyFlights();
    });
    await _futureFlights;
  }

  Future<void> _openCheckin() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CheckinScreen()),
    );
    if (result == true) {
      _refresh();
    }
  }

  void _openTracking(Flight flight) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackingScreen(
          flightId: flight.id,
          flightLabel: flight.flightNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String? ?? 'Voyageur';
    final firstName = fullName.split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envol'),
        centerTitle: true,
        actions: const [NotificationBell(), SizedBox(width: 8)],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdBanner(),
              const SizedBox(height: 18),

              Center(
                child: Column(
                  children: [
                    Text(_greeting, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                    Text(firstName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _futureFlights,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final flights = snapshot.data ?? [];

                  if (flights.isEmpty) {
                    return _NoFlightCard(onTap: _openCheckin);
                  }

                  final nextData = flights.first;
                  final nextFlight = Flight.fromMap(nextData['flights'] as Map<String, dynamic>);
                  final others = flights.skip(1).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _openTracking(nextFlight),
                        child: _FlightCard(flight: nextFlight, seat: nextData['seat'] as String?),
                      ),
                      if (others.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text('Vos autres vols', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ...others.map((f) {
                          final flight = Flight.fromMap(f['flights'] as Map<String, dynamic>);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => _openTracking(flight),
                              child: _OtherFlightRow(flight: flight, seat: f['seat'] as String?),
                            ),
                          );
                        }),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 22),
              const Text('Actions rapides', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _QuickAction(icon: Icons.qr_code, label: 'Enregistrement', color: const Color(0xFFC45A1C), onTap: _openCheckin),
                  _QuickAction(icon: Icons.luggage, label: 'Mes bagages', color: const Color(0xFF2E9E6B), onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BaggageScreen()));
                  }),
                  _QuickAction(icon: Icons.map_outlined, label: 'Plan aéroport', color: const Color(0xFF3D7DC4), onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AirportMapScreen()));
                  }),
                  _QuickAction(icon: Icons.local_parking, label: 'Parking', color: const Color(0xFF8A5CC4), onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParkingScreen()));
                  }),
                  _QuickAction(icon: Icons.search_off, label: 'Objets perdus', color: const Color(0xFFC44A6A), onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LostItemsScreen()));
                  }),
                  _QuickAction(icon: Icons.accessible, label: 'Assistance PMR', color: const Color(0xFFC48A1C), onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AssistanceScreen()));
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoFlightCard extends StatelessWidget {
  final VoidCallback onTap;
  const _NoFlightCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('AUCUN VOL EN COURS',
                  style: TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1)),
            ),
            const SizedBox(height: 14),
            const Text(
              'Enregistre-toi pour ton prochain vol',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: const [
                Text('Toucher pour commencer', style: TextStyle(color: Colors.white70, fontSize: 12)),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, color: Colors.white70, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlightCard extends StatelessWidget {
  final Flight flight;
  final String? seat;
  const _FlightCard({required this.flight, this.seat});

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 26, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipPath(
        clipper: TicketClipper(notchY: 168, borderRadius: 22),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${flight.flightNumber} · ${flight.statusLabel.toUpperCase()}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flight.originCode,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      Text(flight.originCity, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const Icon(Icons.flight_takeoff, color: Colors.white, size: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(flight.destinationCode,
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      Text(flight.destinationCity, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              FutureBuilder<WeatherInfo?>(
                future: WeatherService.getWeatherForCity(flight.destinationCity),
                builder: (context, snapshot) {
                  final weather = snapshot.data;
                  if (weather == null) return const SizedBox.shrink();
                  final label = weather.temperature.round().toString() + '°C · ' + weather.description;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(weather.icon, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
              const DashedLine(color: Colors.white30),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _MetaItem(
                    label: 'EMBARQUEMENT',
                    value: flight.boardingTime != null ? timeFormat.format(flight.boardingTime!) : '--:--',
                  ),
                  _MetaItem(label: 'PORTE', value: flight.gateCode ?? '--'),
                  _MetaItem(label: 'SIÈGE', value: seat ?? '--'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Text('Voir le suivi du parcours', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, color: Colors.white70, size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtherFlightRow extends StatelessWidget {
  final Flight flight;
  final String? seat;
  const _OtherFlightRow({required this.flight, this.seat});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM · HH:mm');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flight, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${flight.flightNumber} · ${flight.originCode} → ${flight.destinationCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(dateFormat.format(flight.scheduledDeparture),
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 11)),
              ],
            ),
          ),
          if (seat != null)
            Text(seat!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
