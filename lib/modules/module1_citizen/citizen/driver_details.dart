import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/theme/citizen_pattern_background.dart';
// Note: Relative imports now work since you moved this file into presentation/citizen/
import '../../../router/app_router.dart';
import 'package:go_router/go_router.dart'; // Import GoRouter

// --- Reusable custom slide-up transition is now deprecated, use GoRouter navigation ---

class DriverDetailsScreen extends StatelessWidget {
  // Make parameters nullable to handle data passed via GoRouter state.extra
  final String? driverName;
  final String? vehicleNumber;

  const DriverDetailsScreen({
    super.key,
    this.driverName,
    this.vehicleNumber,
  });

  // Mock Data fallback (in case GoRouter fails to pass data)
  final String collectionTime = 'Tomorrow, 7:00 AM - 8:00 AM';
  final String collectionType = 'Wet Waste';

  @override
  Widget build(BuildContext context) {
    // Safely use fallback values
    final currentDriverName = driverName ?? 'Rajesh Kumar (N/A)';
    final currentVehicleNumber = vehicleNumber ?? 'TN 01 AB 1234 (N/A)';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final textColor = colorScheme.onSurface;
    final placeholderColor = colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutePaths.citizenHome);
            }
          },
        ),
        title: Text(
          'Collection Details',
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryColor,
      ),
      body: CitizenPatternBackground(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Your Next Collection',
              style: theme.textTheme.titleLarge!.copyWith(
                fontSize: 24,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),

            // Collection Summary Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.schedule, color: primaryColor, size: 30),
                title: Text(
                  'Type: $collectionType',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'Time: $collectionTime',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: placeholderColor),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 30),

            // Driver Information Section
            Text(
              'Assigned Crew Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 15),

            // Driver Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Driver Photo Placeholder
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: primaryColor,
                      child: const Icon(Icons.person,
                          size: 30, color: Colors.white),
                    ),
                    const SizedBox(width: 20),
                    // Driver Name & Vehicle
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentDriverName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Driver',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: placeholderColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vehicle No: $currentVehicleNumber',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Track Vehicle Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  // NEW GOROUTER NAVIGATION: Navigate to the MapScreen
                  context.pushNamed(
                    'citizenAllotedVehicleMap',
                  );
                },
                icon: const Icon(Icons.location_searching, color: Colors.white),
                label: const Text(
                  'Track Vehicle Live',
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
