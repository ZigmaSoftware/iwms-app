import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';

class _VehicleMarker extends StatelessWidget {
  final VehicleModel vehicle;
  final bool isSelected;
  final Color Function(String?) getVehicleStatusColor;

  const _VehicleMarker({
    required this.vehicle,
    required this.isSelected,
    required this.getVehicleStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 44.0 : 36.0;

    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow (depth illusion)
          Positioned(
            bottom: 2,
            child: Container(
              width: size * 0.7,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),

          // 3D Vehicle
          Image.asset(
            'assets/vehicles/truck_3d.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}
