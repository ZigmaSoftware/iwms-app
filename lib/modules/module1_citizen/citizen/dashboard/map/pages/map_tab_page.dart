import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/modules/module1_citizen/citizen/alloted_vehicle_map.dart';

/// Wrapper for the map tab to keep existing logic intact.
class MapTabPage extends StatelessWidget {
  const MapTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CitizenAllotedVehicleMapScreen();
  }
}
