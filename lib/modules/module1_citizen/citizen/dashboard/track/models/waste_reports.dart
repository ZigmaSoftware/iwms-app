class DayWiseTicket {
  DayWiseTicket({
    required this.ticketNo,
    required this.timestamp,
    required this.vehicleNo,
    required this.dryWeight,
    required this.wetWeight,
    required this.mixWeight,
    required this.netWeight,
  });

  final String ticketNo;
  final DateTime timestamp;
  final String vehicleNo;
  final double dryWeight;
  final double wetWeight;
  final double mixWeight;
  final double netWeight;

  factory DayWiseTicket.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['Date'] ?? json['date'])?.toString();
    final parsedDate = rawDate != null ? DateTime.tryParse(rawDate) : null;

    return DayWiseTicket(
      ticketNo: json['Ticket_No']?.toString() ?? 'NA',
      timestamp: parsedDate ?? DateTime.now(),
      vehicleNo: json['Vehicle_No']?.toString() ?? 'Unknown',
      dryWeight: _parseWeight(json['Dry_Wt']),
      wetWeight: _parseWeight(json['Wet_Wt']),
      mixWeight: _parseWeight(json['Mix_Wt']),
      netWeight: _parseWeight(json['Net_Wt']),
    );
  }
}

class VehicleWeightReport {
  VehicleWeightReport({
    required this.vehicleNo,
    required this.totalWeight,
    this.date,
  });

  final String vehicleNo;
  final double totalWeight;
  final DateTime? date;

  factory VehicleWeightReport.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString();
    final parsedDate = rawDate != null ? DateTime.tryParse(rawDate) : null;

    return VehicleWeightReport(
      vehicleNo: json['VehicleNo']?.toString() ?? 'Unknown',
      totalWeight: _parseWeight(json['total_Weight']),
      date: parsedDate,
    );
  }
}

double _parseWeight(dynamic raw) {
  if (raw == null) return 0;
  final cleaned = raw.toString().replaceAll(',', '').trim();
  return double.tryParse(cleaned) ?? 0;
}
