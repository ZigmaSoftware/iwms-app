import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/profile.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart'; // ADD THIS

const LinearGradient _headerGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.primaryVariant],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class OperatorHeader extends StatefulWidget {
  const OperatorHeader({
    super.key,
    required this.name,
    required this.empId, // Changed from emp_id
    this.displayId,
    required this.badge,
    required this.ward,
    required this.zone,
    required this.onLogout,
    this.onMenuTap,
    this.subtitle,
    this.showAvatar = false,
  });

  final String name;
  final String badge;
  final String ward;
  final String zone;
  final String empId; // Changed from emp_id
  final String? displayId;
  final String? subtitle;
  final VoidCallback onLogout;
  final VoidCallback? onMenuTap;
  final bool showAvatar;

  @override
  State<OperatorHeader> createState() => _OperatorHeaderState();
}

class _OperatorHeaderState extends State<OperatorHeader> {
  static const String _baseUrl = "http://192.168.7.176:8000";
  bool hasProfile = false;
  bool imageLoading = true;
  String? imageName;

  @override
  void initState() {
    super.initState();
    fetchEmployeeImage();
  }

  Future<void> fetchEmployeeImage() async {
    final client = HttpClient();
    try {
      final url =
          "$_baseUrl/api/desktop/staff-profile/?staff_id_id=${widget.empId}";

      final request =
          await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 5));
      final token = await _getAuthToken();
      if (token != null && token.isNotEmpty) {
        request.headers
            .set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join();

      final json = jsonDecode(body);

      if (json["status"] == "success") {
        if (!mounted) return;
        setState(() {
          imageName = json["data"]["photo"] ?? "";
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasProfile = false;
        imageLoading = false;
      });
    } finally {
      client.close(force: true);
    }
  }

  String convertToUrl(String path) {
    final clean = path.replaceAll("\\", "/");
    final filename = clean.split("/").last;
    return "$_baseUrl/media/emp_image/$filename";
  }

  String toTitleCase(String s) {
    return s
        .split(" ")
        .map((w) => w.isEmpty
            ? ""
            : "${w[0].toUpperCase()}${w.substring(1).toLowerCase()}")
        .join(" ");
  }

  Future<String?> _getAuthToken() async {
    final authRepo = getIt<AuthRepository>();
    final user = await authRepo.getAuthenticatedUser();
    final token = user?.authToken?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context); // FIX: Get localizations
    
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: _headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(t),
              const SizedBox(height: 8),
              _buildLocationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTitleSection(t)),
        _buildAvatarButton(),
      ],
    );
  }

  Widget _buildTitleSection(AppLocalizations t) {
    final displayId =
        (widget.displayId != null && widget.displayId!.trim().isNotEmpty)
            ? widget.displayId!
            : widget.empId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.operatorLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              toTitleCase(widget.name),
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "(${displayId})",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAvatarButton() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(empId: widget.empId),
          ),
        );
        fetchEmployeeImage();
      },
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        backgroundImage: (hasProfile && imageName != null)
            ? NetworkImage(convertToUrl(imageName!))
            : null,
        child: imageLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.green),
              )
            : (!hasProfile)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.person_add_alt_1,
                          size: 26, color: Colors.green),
                      SizedBox(height: 2),
                      Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  )
                : null,
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Text(
        '${widget.ward} · ${widget.zone}',
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
