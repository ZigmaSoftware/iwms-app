import 'package:equatable/equatable.dart';

class VehicleModel extends Equatable {
  // Core identification and location fields
  final String id;
  final double latitude;
  final double longitude;

  // Fields made nullable to handle missing API data without crashing
  final String? registrationNumber;
  final String? driverName;
  final String? status;
  final double? wasteCapacityKg;
  final String? lastUpdated;
  final bool isInsideGeofence;
  final String? address;

  // Real-time telemetry
  final double? speedKmh;
  final double? fuelLevel;
  final double? distanceKm;

  const VehicleModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.registrationNumber,
    this.driverName,
    this.status,
    this.wasteCapacityKg,
    this.lastUpdated,
    this.isInsideGeofence = false,
    this.address,
    this.speedKmh,
    this.fuelLevel,
    this.distanceKm,
  });

  // Factory constructor to safely parse JSON from the API
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    // Helper function for safe double parsing, defaulting to 0.0 if data is null or invalid
    double safeParseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is String) return double.tryParse(value) ?? 0.0;
      if (value is num) return value.toDouble();
      return 0.0;
    }

    // Helper function for safe int parsing, defaulting to 0 if data is null or invalid
    int safeParseInt(dynamic value) {
      if (value == null) return 0;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is num) return value.toInt();
      return 0;
    }

    // --- Registration Number (Prioritize 'regNo') ---
    final regNo = json['regNo']?.toString() ??
        json['VEHICLE_NO']?.toString() ??
        json['vehicle_no']?.toString();

    // --- Driver Name (Prioritize 'driverName'. Normalizes '-' to null for fallback.) ---
    final rawDriverName = json['driverName']?.toString() ??
        json['DRIVER_NAME']?.toString() ??
        json['driver_name']?.toString();

    final driver =
        (rawDriverName == '-' || rawDriverName?.trim().isEmpty == true)
            ? null
            : rawDriverName;

    // --- Map coordinates (Prioritize the inner, numeric 'lat' and 'lng') ---
    final lat = safeParseDouble(json['lat'] ?? json['LAT'] ?? json['latitude']);
    final lon =
        safeParseDouble(json['lng'] ?? json['LON'] ?? json['longitude']);

    // --- Load/capacity data (Using loadTruck as a best guess, mapping "nill" to 0) ---
    final loadData = json['loadTruck']?.toString() != 'nill'
        ? json['loadTruck']
        : (json['CURRENT_LOAD'] ?? json['load']);

    // --- Last Update Time (Use 'lastSeen' as primary) ---
    final updateTime =
        json['lastSeen']?.toString() ?? json['LAST_UPDATE_TIME']?.toString();

    // --- Model Assembly ---
    // Determine unique ID (Use deviceId as a robust fallback ID)
    final vehicleId = regNo ?? json['deviceId']?.toString() ?? '${lat}_$lon';

    // 🟢 START OF THE REAL FIX: New Status Determination Logic
    // This logic correctly interprets the API data based on your provided JSON.
    final ignition = json['ignitionStatus']?.toString().toLowerCase();
    final speed = safeParseInt(json['speed']);

    // Use the "status" field (e.g., "OFF") as a fallback if ignitionStatus is missing
    final fallbackStatus = json['status']?.toString().toLowerCase();
    final insideGeofence =
        json['insideGeoFence']?.toString().toUpperCase() == 'Y';
    final address = json['address']?.toString();

    String determinedStatus;

    if (ignition == 'off' || fallbackStatus == 'off') {
      // If ignition is OFF, it's 'Parked'.
      determinedStatus = 'Parked';
    } else if (ignition == 'on') {
      // If ignition is ON, check speed.
      if (speed > 0) {
        determinedStatus = 'Running';
      } else {
        // Ignition is ON but speed is 0, so it's 'Idle'.
        determinedStatus = 'Idle';
      }
    } else {
      // Fallback for missing or unexpected ignitionStatus (e.g., null, "N/A")
      // We check the speed again just in case.
      if (speed > 0) {
        determinedStatus = 'Running';
      }
      // Check for "NoData" status from API
      else if (fallbackStatus == 'nodata' || (json['noDataStatus'] == 1)) {
        determinedStatus = 'No Data';
      }
      // If we really can't determine, default to 'Parked' if speed is 0.
      else if (speed == 0) {
        determinedStatus = 'Parked';
      }
      // Final fallback
      else {
        determinedStatus = 'No Data';
      }
    }
    // 🟢 END OF THE REAL FIX

    // --- Real-time telemetry ---
    double? parseTelemetry(List<String> keys) {
      for (final key in keys) {
        if (json.containsKey(key) && json[key] != null) {
          return safeParseDouble(json[key]);
        }
      }
      return null;
    }

    final speedTelemetry = parseTelemetry(['speed', 'SPEED']);
    final fuelTelemetry = parseTelemetry(
      ['fuelLevel', 'fuel', 'fuelPct', 'fuelPercent', 'fuel_perc'],
    );
    final distanceTelemetry = parseTelemetry(
      ['odo', 'ODO', 'odometer', 'distance', 'totalDistance', 'totalDistanceKm'],
    );

    return VehicleModel(
      id: vehicleId,
      latitude: lat,
      longitude: lon,

      // Assigning mapped values
      registrationNumber: regNo,
      driverName: driver,
      status: determinedStatus, // <-- Use the new, correct status

      // Pass load data through safe parser
      wasteCapacityKg: safeParseDouble(loadData),
      lastUpdated: updateTime,
      isInsideGeofence: insideGeofence,
      address: address,
      speedKmh: speedTelemetry,
      fuelLevel: fuelTelemetry,
      distanceKm: distanceTelemetry,
    );
  }

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        registrationNumber,
        driverName,
        status,
        wasteCapacityKg,
        lastUpdated,
        isInsideGeofence,
        address,
        speedKmh,
        fuelLevel,
        distanceKm,
      ];

  get vehicleNumber => null;

  get vehicleType => null;
}
