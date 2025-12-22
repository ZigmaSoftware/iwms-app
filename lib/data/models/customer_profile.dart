class CustomerProfile {
  final String uniqueId;
  final String name;
  final String contactNo;
  final String wardName;
  final String wardId;
  final String address;
  final double? latitude;
  final double? longitude;

  CustomerProfile({
    required this.uniqueId,
    required this.name,
    required this.contactNo,
    required this.wardName,
    required this.wardId,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    final wardName = (json['ward_name'] ?? '').toString();
    final wardRaw = json['ward_id'] ?? json['ward'];
    String wardId = '';
    if (wardRaw is Map) {
      wardId = (wardRaw['unique_id'] ?? wardRaw['id'] ?? wardRaw['pk'] ?? '')
          .toString();
    } else if (wardRaw != null) {
      wardId = wardRaw.toString();
    }

    final addressParts = [
      json['building_no'],
      json['street'],
      json['area'],
      json['pincode'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();

    final lat = double.tryParse((json['latitude'] ?? '').toString());
    final lon = double.tryParse((json['longitude'] ?? '').toString());

    return CustomerProfile(
      uniqueId: (json['unique_id'] ?? '').toString(),
      name: (json['customer_name'] ?? '').toString(),
      contactNo: (json['contact_no'] ?? '').toString(),
      wardName: wardName.isNotEmpty ? wardName : 'Ward',
      wardId: wardId,
      address: addressParts.join(', '),
      latitude: lat,
      longitude: lon,
    );
  }
}
