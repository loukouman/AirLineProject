import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/flight.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ticket_shape.dart';
import '../../core/widgets/offline_banner.dart';

class BoardingPassScreen extends StatefulWidget {
  const BoardingPassScreen({super.key});

  @override
  State<BoardingPassScreen> createState() => _BoardingPassScreenState();
}

class _BoardingPassScreenState extends State<BoardingPassScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getMyFlights();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = SupabaseService.getMyFlights();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vols'),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'Mes cartes'),
              Tab(text: 'Tableau des vols'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MyPassesTab(future: _future, onRefresh: _refresh),
            const _FlightBoardTab(),
          ],
        ),
      ),
    );
  }
}

class _MyPassesTab extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> future;
  final Future<void> Function() onRefresh;
  const _MyPassesTab({required this.future, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final passengerName =
        SupabaseService.currentUser?.userMetadata?['full_name'] as String? ?? 'Voyageur';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final passes = snapshot.data ?? [];
          final isOffline = SupabaseService.lastFlightsFromCache;

          if (passes.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (isOffline) const OfflineBanner(),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Column(
                    children: [
                      Icon(Icons.confirmation_number_outlined, size: 56, color: AppColors.inkSoft),
                      SizedBox(height: 16),
                      Text('Aucune carte d\'embarquement pour le moment',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: passes.length + (isOffline ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 20),
            itemBuilder: (context, i) {
              if (isOffline && i == 0) return const OfflineBanner();
              final data = passes[isOffline ? i - 1 : i];
              final flight = Flight.fromMap(data['flights'] as Map<String, dynamic>);
              return _BoardingPassCard(
                flight: flight,
                passengerName: passengerName,
                seat: data['seat'] as String?,
                boardingGroup: data['boarding_group'] as String?,
                travelClass: data['travel_class'] as String? ?? 'ECO',
                qrCode: data['qr_code'] as String? ?? '',
              );
            },
          );
        },
      ),
    );
  }
}

class _FlightBoardTab extends StatefulWidget {
  const _FlightBoardTab();

  @override
  State<_FlightBoardTab> createState() => _FlightBoardTabState();
}

class _FlightBoardTabState extends State<_FlightBoardTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = SupabaseService.getAllFlights();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = SupabaseService.getAllFlights();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final flights = snapshot.data ?? [];

          if (flights.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.all(60),
                  child: Text('Aucun vol programmé pour le moment.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft)),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: flights.length,
            itemBuilder: (context, i) => _BoardRow(data: flights[i]),
          );
        },
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _BoardRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final flight = Flight.fromMap(data);
    final timeFormat = DateFormat('HH:mm');

    Color statusColor;
    switch (flight.status) {
      case 'embarquement':
        statusColor = AppColors.primary;
        break;
      case 'retarde':
        statusColor = Colors.orange;
        break;
      case 'annule':
        statusColor = Colors.redAccent;
        break;
      case 'decolle':
        statusColor = AppColors.inkSoft;
        break;
      default:
        statusColor = AppColors.success;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(timeFormat.format(flight.scheduledDeparture),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${flight.destinationCode} · ${flight.destinationCity}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${flight.flightNumber} · ${flight.airlineName}',
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 11)),
              ],
            ),
          ),
          if (flight.gateCode != null) ...[
            Text(flight.gateCode!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(flight.statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _BoardingPassCard extends StatelessWidget {
  final Flight flight;
  final String passengerName;
  final String? seat;
  final String? boardingGroup;
  final String travelClass;
  final String qrCode;

  const _BoardingPassCard({
    required this.flight,
    required this.passengerName,
    this.seat,
    this.boardingGroup,
    required this.travelClass,
    required this.qrCode,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 14)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: ClipPath(
        clipper: TicketClipper(notchY: 210, borderRadius: 22),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.flight, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(flight.airlineName.isEmpty ? 'COMPAGNIE' : flight.airlineName.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(flight.originCode, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          Text(dateFormat.format(flight.scheduledDeparture), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                        const Icon(Icons.flight_takeoff, color: Colors.white, size: 22),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(flight.destinationCode, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          Text(dateFormat.format(flight.scheduledArrival), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.4,
                  children: [
                    _Field(label: 'PASSAGER', value: passengerName.split(' ').first.toUpperCase()),
                    _Field(label: 'PORTE', value: flight.gateCode ?? '--'),
                    _Field(label: 'SIÈGE', value: seat ?? '--'),
                    _Field(label: 'EMBARQUEMENT', value: flight.boardingTime != null ? dateFormat.format(flight.boardingTime!) : '--:--'),
                    _Field(label: 'GROUPE', value: boardingGroup ?? '--'),
                    _Field(label: 'CLASSE', value: travelClass),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: DashedLine(),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(border: Border.all(color: Colors.black.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(8)),
                      child: QrImageView(
                        data: qrCode.isEmpty ? flight.id : qrCode,
                        version: QrVersions.auto,
                        size: 64,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(flight.flightNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          const Text('Présentez ce code à la porte d\'embarquement', style: TextStyle(color: AppColors.inkSoft, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.inkSoft, letterSpacing: 0.5)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
