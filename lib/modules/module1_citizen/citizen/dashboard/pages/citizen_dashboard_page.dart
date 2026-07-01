import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/core/geofence_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/logic/vehicle_tracking/vehicle_bloc.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/banner/controllers/banner_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/banner/models/banner_slide.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/banner/services/banner_service.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/geofence/utils/geofence_evaluator.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/home/controllers/home_nav_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/home/widgets/home_tab.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/map/pages/map_tab_page.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/notifications/controllers/notification_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/notifications/models/citizen_alert.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/profile/widgets/profile_tab.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/quick_actions/models/quick_action.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/controllers/track_controller.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/models/waste_period.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/services/track_service.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/widgets/track_tab.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class CitizenDashboardPage extends StatefulWidget {
  const CitizenDashboardPage({super.key, required this.userName});

  final String userName;

  static const Color darkBackground = Color(0xFF04120A);
  static const Color darkSurface = Color(0xFF0B2716);

  @override
  State<CitizenDashboardPage> createState() => _CitizenDashboardPageState();
}

class _CitizenDashboardPageState extends State<CitizenDashboardPage>
    with TickerProviderStateMixin {
  late final BannerController _bannerController;
  late final TrackController _trackController;
  late final NotificationController _notificationController;
  late final HomeNavController _navController;
  late final GeofenceEvaluator _geofenceEvaluator;
  late final AuthRepository _authRepository;
  DateTime? _lastGeofenceAlertAt;
  String? _userId;
  final Set<String> _notifiedCitizenAssignments = {};

  late final List<BannerSlide> _fallbackSlides;

  @override
  void initState() {
    super.initState();
    _fallbackSlides = _defaultBannerSlides;
    _bannerController = BannerController(
      service: BannerService(),
      fallbackSlides: _fallbackSlides,
    );
    _trackController = TrackController(TrackService());
    _notificationController = getIt<NotificationController>();
    _navController = HomeNavController();
    _geofenceEvaluator = const GeofenceEvaluator();
    _authRepository = getIt<AuthRepository>();

    unawaited(_bannerController.initialize());
    unawaited(_trackController.refresh(force: true));
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final user = await _authRepository.getAuthenticatedUser();
    if (!mounted) return;
    setState(() {
      _userId = user?.userId;
    });
    if (user?.userId != null && user!.userId.trim().isNotEmpty) {
      unawaited(_fetchCitizenAssignments(user.userId.trim()));
    }
  }

  Future<void> _fetchCitizenAssignments(String customerId) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return;

    try {
      final dio = await authorizedDio();
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await dio.get(
        ApiConfig.citizenAssignments,
        queryParameters: {
          'customer_id': customerId,
          'date': dateStr,
        },
      );

      final decoded = response.data;
      final List list = decoded is List
          ? decoded
          : (decoded is Map ? (decoded['results'] ?? decoded['data'] ?? []) : []);

      for (final item in list) {
        if (item is! Map) continue;
        final id = item['unique_id']?.toString();
        if (id == null || id.isEmpty) continue;
        if (!_notifiedCitizenAssignments.add(id)) continue;

        final wardName = item['ward_name']?.toString() ?? 'your ward';
        final date = item['date']?.toString() ?? dateStr;
        _notificationController.addAlert(
          CitizenAlert(
            title: 'Collection scheduled',
            message: 'Waste pickup scheduled for $wardName on $date.',
            timestamp: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Citizen assignment alerts skipped: $e');
    }
  }

  @override
  void dispose() {
    _bannerController.dispose();
    _trackController.dispose();
    _navController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    final normalizedName = widget.userName.trim();
    final showUserName =
        normalizedName.isNotEmpty && normalizedName.toLowerCase() != 'citizen demo';

    final backgroundColor = isDarkMode
        ? CitizenDashboardPage.darkBackground
        : const Color.fromRGBO(235, 248, 239, 1);
    final surfaceColor =
        isDarkMode ? CitizenDashboardPage.darkSurface : Colors.white;
    final outlineColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor =
        isDarkMode ? Colors.white70 : Colors.black54;
    final highlightColor =
        isDarkMode ? colorScheme.secondary : colorScheme.primary;

    final localizations = AppLocalizations.of(context);
    final quickActions = _buildQuickActions(context, localizations);
    final navLabels = [
      localizations.tabHome,
      localizations.tabTrack,
      localizations.tabMap,
      localizations.tabProfile,
    ];
    final localeCode = Localizations.localeOf(context).languageCode;
    final navTextStyle = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      color: isDarkMode ? Colors.white70 : Colors.black87,
      fontWeight: FontWeight.w600,
      fontSize: localeCode == 'ta' ? 11 : 12,
    );

    final List<Color> sectionHeaderGradientColors = isDarkMode
        ? const [Color(0xFF0D3A16), Color(0xFF43A047)]
        : const [Color(0xFF1B5E20), Color(0xFF66BB6A)];

    final responsive = MediaQuery.of(context).size;
    final double headerHeight = math.min(responsive.height * 0.36, 360);

    Widget buildTabBody(BottomNavItem item) {
      switch (item) {
        case BottomNavItem.track:
          return TrackTab(
            controller: _trackController,
            highlightColor: highlightColor,
            textColor: textColor,
            onPickDate: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _trackController.selectedDate,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 1, 12, 31),
              );
              if (picked != null) {
                await _trackController.pickDate(picked);
              }
            },
          );
        case BottomNavItem.map:
          return const MapTabPage();
        case BottomNavItem.profile:
          return ProfileTab(
            headerHeight: headerHeight,
            headerGradientColors: sectionHeaderGradientColors,
            normalizedName: normalizedName,
            highlightColor: highlightColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
          );
        case BottomNavItem.home:
          return HomeTab(
            bannerController: _bannerController,
            trackController: _trackController,
            notificationController: _notificationController,
            quickActions: quickActions,
            userName: normalizedName,
            showUserName: showUserName,
            isDarkMode: isDarkMode,
            surfaceColor: surfaceColor,
            outlineColor: outlineColor,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            highlightColor: highlightColor,
            onStatsTap: () {
              _trackController.setPeriod(WastePeriod.monthly);
              _navController.setItem(BottomNavItem.track);
              unawaited(_trackController.refresh(force: true));
            },
          );
      }
    }

    return BlocListener<VehicleBloc, VehicleState>(
      listenWhen: (previous, current) => current is VehicleLoaded,
      listener: (context, state) {
        if (state is VehicleLoaded) {
          _evaluateGeofence(state.vehicles);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: AnimatedBuilder(
          animation: _navController,
          builder: (context, _) {
            final isMapTab = _navController.active == BottomNavItem.map;
            final body = buildTabBody(_navController.active);
            return Stack(
              children: [
                Positioned.fill(
                  child: isMapTab ? body : SafeArea(child: body),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: KeyedSubtree(
            key: ValueKey(navLabels.join('-')),
            child: MotionTabBar(
              labels: navLabels,
              textStyle: navTextStyle,
              icons: const [
                Icons.home_outlined,
                Icons.delete_outline,
                Icons.map_outlined,
                Icons.person_outline,
              ],
              tabBarColor:
                  isDarkMode ? CitizenDashboardPage.darkSurface : Colors.white,
              tabSelectedColor: highlightColor,
              tabIconColor: isDarkMode ? Colors.white54 : Colors.black54,
              tabBarHeight: 64,
              tabSize: 52,
              tabIconSize: 22,
              tabIconSelectedSize: 24,
              initialSelectedTab:
                  _labelForNav(_navController.active, localizations),
              onTabItemSelected: (value) {
                int? index;
                if (value is int) {
                  index = value;
                } else if (value is String) {
                  index = navLabels.indexOf(value);
                }
                if (index != null &&
                    index >= 0 &&
                    index < navLabels.length) {
                  _navController.setItem(_navFromIndex(index));
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  List<QuickAction> _buildQuickActions(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return [
      QuickAction(
        label: localizations.quickActionTrackVehicles,
        assetPath: 'assets/icons/track_vehicles.png',
        onTap: () => context.push(AppRoutePaths.citizenMap),
      ),
      QuickAction(
        label: localizations.quickActionCollectionDetails,
        assetPath: 'assets/icons/collection_details.png',
        onTap: () => context.push(AppRoutePaths.citizenHistory),
      ),
      QuickAction(
        label: localizations.quickActionCollectionHistory,
        assetPath: 'assets/icons/collectionhistory.png',
        onTap: () => context.push(AppRoutePaths.citizenHistory),
      ),
      QuickAction(
        label: localizations.quickActionRaiseGrievance,
        assetPath: 'assets/icons/raise_grievance.png',
        onTap: () => context.push(AppRoutePaths.citizenGrievanceChat),
      ),
      QuickAction(
        label: localizations.quickActionRateCollector,
        assetPath: 'assets/icons/rate_collector.png',
        onTap: () => _showComingSoon(context, 'Rating feature'),
      ),
      QuickAction(
        label: localizations.quickActionQr,
        assetPath: 'assets/icons/qr.png',
        onTap: () => _showQrDialog(context, localizations),
      ),
      QuickAction(
        label: localizations.quickActionUpcomingCollection,
        assetPath: 'assets/icons/upcoming_collection.png',
        onTap: () => _showComingSoon(context, 'Upcoming collection schedule'),
      ),
    ];
  }

  void _evaluateGeofence(List<VehicleModel> vehicles) {
    final hasVehicleInside =
        vehicles.any((vehicle) => _geofenceEvaluator.isInsideGamma(vehicle));

    final now = DateTime.now();
    final last = _lastGeofenceAlertAt;
    final withinCooldown =
        last != null && now.difference(last) < const Duration(minutes: 5);

    if (hasVehicleInside && !withinCooldown) {
      const message =
          'Upcoming collection: our truck is approaching ${GammaGeofenceConfig.name}. '
          'Please segregate your dry, wet and mixed waste for pickup.';
      _notificationController.addAlert(
        CitizenAlert(
          title: 'Collector arriving soon',
          message: message,
          timestamp: DateTime.now(),
        ),
      );
      _lastGeofenceAlertAt = now;
    }
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  Future<void> _showQrDialog(
    BuildContext context,
    AppLocalizations localizations,
  ) async {
    final theme = Theme.of(context);
    final uid = _userId;
    final qrPayload = uid != null
        ? jsonEncode({"type": "citizen", "uid": uid})
        : null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  localizations.qrDialogTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  localizations.qrDialogSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                if (qrPayload != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.08),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        color: Colors.black,
                        eyeShape: QrEyeShape.square,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        color: Colors.black87,
                        dataModuleShape: QrDataModuleShape.square,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28.0),
                    child: Text(
                      localizations.qrDialogLoginPrompt,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(Icons.check),
                  label: Text(localizations.qrDialogDone),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  BottomNavItem _navFromIndex(int index) {
    const values = [
      BottomNavItem.home,
      BottomNavItem.track,
      BottomNavItem.map,
      BottomNavItem.profile,
    ];
    if (index < 0 || index >= values.length) return values.first;
    return values[index];
  }

  String _labelForNav(BottomNavItem item, AppLocalizations localizations) {
    switch (item) {
      case BottomNavItem.track:
        return localizations.tabTrack;
      case BottomNavItem.map:
        return localizations.tabMap;
      case BottomNavItem.profile:
        return localizations.tabProfile;
      case BottomNavItem.home:
        return localizations.tabHome;
    }
  }

  static const List<BannerSlide> _defaultBannerSlides = [
    BannerSlide(
      chipLabel: 'Support',
      title: 'Report missed pickups instantly',
      subtitle: 'Our support desk responds within 10 mins.',
      colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
      icon: Icons.support_agent,
      backgroundImage: 'assets/banner/banner1.jpg',
      subtitleFontSize: 10,
    ),
    BannerSlide(
      chipLabel: 'Pickups',
      title: 'Track your collector live on map',
      subtitle: 'Stay ready before the vehicle arrives.',
      colors: [Color(0xFF1B5E20), Color(0xFF2E7D5A)],
      icon: Icons.map_outlined,
      backgroundImage: 'assets/banner/banner3.jpg',
      subtitleFontSize: 10,
    ),
    BannerSlide(
      chipLabel: 'Segregation',
      title: 'Smart sorting keeps trucks faster',
      subtitle: 'Separate dry, wet & mixed waste every morning.',
      colors: [Color(0xFF1B5E20), Color(0xFF66BB6A)],
      icon: Icons.auto_awesome,
      backgroundImage: 'assets/banner/banner2.jpg',
      subtitleFontSize: 10,
    ),
    BannerSlide(
      chipLabel: 'Rewards',
      title: 'Earn green points every recycle',
      subtitle: 'Redeem perks from trusted partners.',
      colors: [Color(0xFF2E7D5A), Color(0xFF66BB6A)],
      icon: Icons.star_rate_outlined,
    ),
  ];
}
