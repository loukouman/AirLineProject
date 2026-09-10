class BoardingPassInfo {
  final String passengerName;
  final String? seat;
  final String? boardingGroup;
  final String travelClass;
  final String qrCode;

  BoardingPassInfo({
    required this.passengerName,
    this.seat,
    this.boardingGroup,
    this.travelClass = 'ECO',
    required this.qrCode,
  });

  factory BoardingPassInfo.fromMap(Map<String, dynamic> map, String passengerName) {
    return BoardingPassInfo(
      passengerName: passengerName,
      seat: map['seat'] as String?,
      boardingGroup: map['boarding_group'] as String?,
      travelClass: map['travel_class'] as String? ?? 'ECO',
      qrCode: map['qr_code'] as String? ?? '',
    );
  }
}
