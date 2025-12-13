import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/profile.dart';

const LinearGradient _headerGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.primaryVariant],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class OperatorHeader extends StatefulWidget {
  const OperatorHeader({
    super.key,
    required this.name,
    required this.emp_id,
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
  final String emp_id;
  final String? subtitle;
  final VoidCallback onLogout;
  final VoidCallback? onMenuTap;
  final bool showAvatar;

  @override
  State<OperatorHeader> createState() => _OperatorHeaderState();
}

class _OperatorHeaderState extends State<OperatorHeader> {
  bool hasProfile = false;
  bool imageLoading = true;
  String? imageName;

  @override
  void initState() {
    super.initState();
    fetchEmployeeImage();
  }

  // ----------------------------------------------------------------------
  // FETCH EMPLOYEE SELFIE IMAGE
  // ----------------------------------------------------------------------
  Future<void> fetchEmployeeImage() async {
    try {
      final url =
          "http://10.164.86.186:8000/api/mobile/staff-profile/?staff_id_id=${widget.emp_id}";

      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      final json = jsonDecode(body);

      if (json["status"] == "success") {
        setState(() {
          imageName = json["data"]["photo"] ?? "";
          hasProfile = imageName != null && imageName!.isNotEmpty;
          imageLoading = false;
        });
      } else {
        setState(() {
          hasProfile = false;
          imageLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasProfile = false;
        imageLoading = false;
      });
    }
  }

  // Convert Django file path to full URL
  String convertToUrl(String path) {
    final filename = path.split("\\").last;
    return "http://10.164.86.186:8000/media/$filename";
  }

  // Convert name to proper case
  String toTitleCase(String s) {
    return s
        .split(" ")
        .map((w) => w.isEmpty ? "" : "${w[0].toUpperCase()}${w.substring(1).toLowerCase()}")
        .join(" ");
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), // COMPACT HEADER
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),
              _buildLocationCard(),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Header Row: Name + Avatar
  // -------------------------------------------------------------
  Widget _buildTopBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildTitleSection()),
        _buildAvatarButton(),
      ],
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operator',
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withOpacity(.75),
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
                fontSize: 20, // SMALLER FONT
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              "(${widget.emp_id})",
              style: const TextStyle(
                fontSize: 18, // SMALLER FONT
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

  // -------------------------------------------------------------
  // PROFILE IMAGE / REGISTER BUTTON
  // -------------------------------------------------------------
    Widget _buildAvatarButton() {
      return GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfilePage(empId: widget.emp_id),
            ),
          );

          fetchEmployeeImage();
        },
        child: CircleAvatar(
          radius: 30, // SMALLER AVATAR
          backgroundColor: Colors.white,

          backgroundImage:
              (hasProfile && imageName != null) ? NetworkImage(convertToUrl(imageName!)) : null,

          child: imageLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                )
              : (!hasProfile)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.person_add_alt_1, size: 26, color: Colors.green),
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

  // -------------------------------------------------------------
  // Ward · Zone Section — COMPACT
  // -------------------------------------------------------------
  Widget _buildLocationCard() {
    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
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
