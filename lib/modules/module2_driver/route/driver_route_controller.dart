import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/ors_service.dart';

class DriverRouteState {
  final bool loading;
  final String? error;
  final LatLng? driver;
  final LatLng? destination;
  final List<LatLng> route;

  const DriverRouteState({
    this.loading = false,
    this.error,
    this.driver,
    this.destination,
    this.route = const [],
  });

  DriverRouteState copyWith({
    bool? loading,
    String? error,
    LatLng? driver,
    LatLng? destination,
    List<LatLng>? route,
  }) {
    return DriverRouteState(
      loading: loading ?? this.loading,
      error: error,
      driver: driver ?? this.driver,
      destination: destination ?? this.destination,
      route: route ?? this.route,
    );
  }
}

class DriverRouteController extends ChangeNotifier {
  DriverRouteController({
    required this.djangoNextHouseUrl,
  });

  final String djangoNextHouseUrl;

  DriverRouteState _state = const DriverRouteState(loading: true);
  DriverRouteState get state => _state;

  Timer? _timer;

  // ✅ REQUIRED BY UI
  Future<void> start() async {
    await _refresh();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _refresh() async {
    try {
      _state = _state.copyWith(loading: true, error: null);
      notifyListeners();

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final driverPoint = LatLng(position.latitude, position.longitude);

      final destination = await _fetchNextHouse();
      if (destination == null) {
        _state = _state.copyWith(
          loading: false,
          driver: driverPoint,
          error: 'No destination assigned',
          route: const [],
        );
        notifyListeners();
        return;
      }

      // ✅ FIXED: positional arguments
      final route = await ORSService.fetchRoute(
        driverPoint,
        destination,
      );

      _state = DriverRouteState(
        loading: false,
        driver: driverPoint,
        destination: destination,
        route: route,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        loading: false,
        error: e.toString(),
      );
      notifyListeners();
    }
  }

  Future<LatLng?> _fetchNextHouse() async {
    final resp = await http.get(Uri.parse(djangoNextHouseUrl));

    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body);
    final lat = double.tryParse(data['lat']?.toString() ?? '');
    final lng = double.tryParse(data['lng']?.toString() ?? '');

    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
