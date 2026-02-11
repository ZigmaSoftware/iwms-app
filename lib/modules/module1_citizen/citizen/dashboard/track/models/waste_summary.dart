class WasteSummary {
  WasteSummary({
    required this.date,
    required this.totalTrip,
    required this.dryWeight,
    required this.wetWeight,
    required this.mixWeight,
    required this.totalNetWeight,
    required this.averageWeightPerTrip,
  });

  final DateTime date;
  final int totalTrip;
  final double dryWeight;
  final double wetWeight;
  final double mixWeight;
  final double totalNetWeight;
  final double averageWeightPerTrip;

  factory WasteSummary.zero(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return WasteSummary(
      date: normalized,
      totalTrip: 0,
      dryWeight: 0,
      wetWeight: 0,
      mixWeight: 0,
      totalNetWeight: 0,
      averageWeightPerTrip: 0,
    );
  }

  factory WasteSummary.fromJson(Map<String, dynamic> json) {
    final isoDate = json['date'] as String?;
    final parsedDate = isoDate != null ? DateTime.tryParse(isoDate) : null;
    final date = parsedDate != null
        ? DateTime(parsedDate.year, parsedDate.month, parsedDate.day)
        : DateTime.now();

    return WasteSummary(
      date: date,
      totalTrip: (json['total_trip'] as num?)?.toInt() ?? 0,
      dryWeight: (json['dry_weight'] as num?)?.toDouble() ?? 0.0,
      wetWeight: (json['wet_weight'] as num?)?.toDouble() ?? 0.0,
      mixWeight: (json['mix_weight'] as num?)?.toDouble() ?? 0.0,
      totalNetWeight: (json['total_net_weight'] as num?)?.toDouble() ?? 0.0,
      averageWeightPerTrip:
          (json['average_weight_per_trip'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
