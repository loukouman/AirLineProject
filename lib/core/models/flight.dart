class Flight {
  final String id;
  final String flightNumber;
  final String airlineName;
  final String originCode;
  final String originCity;
  final String destinationCode;
  final String destinationCity;
  final DateTime scheduledDeparture;
  final DateTime scheduledArrival;
  final DateTime? boardingTime;
  final String? gateCode;
  final String status;

  Flight({
    required this.id,
    required this.flightNumber,
    required this.airlineName,
    required this.originCode,
    required this.originCity,
    required this.destinationCode,
    required this.destinationCity,
    required this.scheduledDeparture,
    required this.scheduledArrival,
    this.boardingTime,
    this.gateCode,
    required this.status,
  });

  factory Flight.fromMap(Map<String, dynamic> map) {
    final airline = map['airlines'] as Map<String, dynamic>?;
    final gate = map['gates'] as Map<String, dynamic>?;

    return Flight(
      id: map['id'] as String,
      flightNumber: map['flight_number'] as String,
      airlineName: airline?['name'] as String? ?? '',
      originCode: map['origin_code'] as String,
      originCity: map['origin_city'] as String,
      destinationCode: map['destination_code'] as String,
      destinationCity: map['destination_city'] as String,
      scheduledDeparture: DateTime.parse(map['scheduled_departure'] as String),
      scheduledArrival: DateTime.parse(map['scheduled_arrival'] as String),
      boardingTime: map['boarding_time'] != null
          ? DateTime.parse(map['boarding_time'] as String)
          : null,
      gateCode: gate?['code'] as String?,
      status: map['status'] as String? ?? 'a_l_heure',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'a_l_heure':
        return 'À l\'heure';
      case 'retarde':
        return 'Retardé';
      case 'embarquement':
        return 'Embarquement';
      case 'ferme':
        return 'Fermé';
      case 'decolle':
        return 'Décollé';
      case 'annule':
        return 'Annulé';
      default:
        return status;
    }
  }
}
