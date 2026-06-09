import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/env.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/driver_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/profile.dart';

/// Driver header — same silhouette and information architecture as the
/// operator header (avatar/Register button anchored LEFT, identity stack
/// beside it, greeting pill + logout on the RIGHT, and a context strip
/// underneath), recolored to the driver's green brand gradient.
///
/// The bottom strip surfaces driver-relevant context — assigned vehicle and
/// shift — in place of the operator's ward/zone strip, with a live "On Duty"
/// indicator that doubles as a quick visual confirmation the shift is active.
class DriverHeader extends StatefulWidget {
  const DriverHeader({
    super.key,
    required this.name,
    required this.empId,
    required this.onLogout,
    this.displayId,
    this.designation,
    this.onProfileTap,
  });

  final String name;
  final String empId;
  final String? displayId;
  final String? designation;
  final VoidCallback onLogout;
  final VoidCallback? onProfileTap;

  @override
  State<DriverHeader> createState() => _DriverHeaderState();
}

class _DriverHeaderState extends State<DriverHeader> {
  static const String _baseUrl = kOperatorProfileBaseUrl;
  bool hasProfile = false;
  bool imageLoading = true;
  String? imageName;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeImage();
  }

  Future<void> _fetchEmployeeImage() async {
    if (widget.empId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        hasProfile = false;
        imageLoading = false;
      });
      return;
    }
    try {
      final dio = await authorizedDio();
      final response = await dio.get(
        '${ApiConfig.desktopBase}staff-profile/',
        queryParameters: {'staff_id_id': widget.empId},
      );
      final json = response.data;
      if (json is Map && json['status'] == 'success') {
        if (!mounted) return;
        setState(() {
          imageName = json['data']?['photo'] ?? '';
          hasProfile = imageName != null && imageName!.isNotEmpty;
          imageLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          hasProfile = false;
          imageLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        hasProfile = false;
        imageLoading = false;
      });
    }
  }

  String _convertToUrl(String path) {
    final clean = path.replaceAll('\\', '/');
    return '$_baseUrl/media/$clean';
  }

  String _toTitleCase(String s) {
    return s
        .split(' ')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final designation = (widget.designation?.trim().isNotEmpty == true)
        ? widget.designation!
        : 'Driver';
    // The ID badge shows the human-readable employee id (e.g. "13753223"),
    // not the internal staff unique id ("STC-...") that backs the photo API.
    final badgeId =
        (widget.displayId != null && widget.displayId!.trim().isNotEmpty)
            ? widget.displayId!.trim()
            : widget.empId;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: DriverTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildAvatarButton(),
                  const SizedBox(width: 11),
                  Expanded(
                      child: _buildIdentitySection(badgeId, designation)),
                  const SizedBox(width: 8),
                  _greetingPill(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _greetingPill() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wb_sunny_rounded,
                  color: DriverTheme.accent, size: 12),
              const SizedBox(width: 4),
              Text(
                _greeting(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _logoutButton(),
      ],
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
        onPressed: widget.onLogout,
        tooltip: 'Logout',
      ),
    );
  }

  Widget _buildIdentitySection(String displayId, String designation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _toTitleCase(widget.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(Icons.local_shipping_rounded,
                color: Color(0xFFFFD27D), size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                designation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, color: Colors.white, size: 10),
              const SizedBox(width: 4),
              Text(
                displayId,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarButton() {
    return GestureDetector(
      onTap: () async {
        if (widget.onProfileTap != null) {
          widget.onProfileTap!();
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(empId: widget.empId),
          ),
        );
        _fetchEmployeeImage();
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [DriverTheme.accent, DriverTheme.accentDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: DriverTheme.accent.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          radius: 23,
          backgroundColor: Colors.white,
          backgroundImage: (hasProfile && imageName != null)
              ? NetworkImage(_convertToUrl(imageName!))
              : null,
          child: imageLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: DriverTheme.primary,
                  ),
                )
              : (!hasProfile)
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded,
                            size: 18, color: DriverTheme.primary),
                        Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            color: DriverTheme.primary,
                          ),
                        ),
                      ],
                    )
                  : null,
        ),
      ),
    );
  }
}
