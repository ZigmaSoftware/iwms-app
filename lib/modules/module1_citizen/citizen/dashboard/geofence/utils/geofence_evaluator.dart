import 'package:latlong2/latlong.dart';

import 'package:iwms_citizen_app/core/geofence_config.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';

class GeofenceEvaluator {
  const GeofenceEvaluator();

  bool isInsideGamma(VehicleModel vehicle) {
    final position = LatLng(vehicle.latitude, vehicle.longitude);
    if (GammaGeofenceConfig.contains(position)) {
      return true;
    }

    final address = vehicle.address?.toLowerCase() ?? '';
    final bool flaggedByProvider = vehicle.isInsideGeofence &&
        address.contains(GammaGeofenceConfig.addressHint);

    return flaggedByProvider && GammaGeofenceConfig.isNear(position);
  }
}
