import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:iwms_citizen_app/core/env.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';

class ProfilePage extends StatefulWidget {
  final String empId;
  const ProfilePage({super.key, required this.empId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  bool isRegistered = false;
  bool _submitting = false;
  String? _error;

  XFile? _image;
  String? imageName;

  final String mediaBaseUrl = kOperatorProfileBaseUrl;

  // Read-only fields
  String employeeName = "";
  String department = "";
  String designation = "";
  String dob = "";
  String bloodGroup = "";
  String doj = "";

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // ----------------------------------------------------------------------
  // FETCH PROFILE (READ ONLY)
  // ----------------------------------------------------------------------
  Future<void> _fetchProfile() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _error = null;
      });
    }
    try {
      final token = await _getAuthToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }

      final res = await http.get(
        Uri.parse('${ApiConfig.desktopBase}staff-profile/').replace(
          queryParameters: {'staff_id_id': widget.empId},
        ),
        headers: headers.isEmpty ? null : headers,
      );

      final jsonRes = jsonDecode(res.body);

      if (jsonRes["status"] == "success") {
        final data = jsonRes["data"];

        String? photo = data["photo"];

        if (!mounted) return;
        setState(() {
          employeeName = (data["employee_name"] ?? "").toString();
          department = (data["department"] ?? "").toString();
          designation = (data["designation"] ?? "").toString();
          dob = (data["personal"]?["dob"] ?? "").toString();
          bloodGroup = (data["personal"]?["blood_group"] ?? "").toString();
          doj = (data["doj"] ?? "").toString();

          imageName = photo;

          // Registered ONLY if photo exists
          isRegistered = photo != null && photo.isNotEmpty;
          isLoading = false;
        });
        return;
      }

      // Reached the server but it did not return a success payload.
      if (!mounted) return;
      setState(() {
        _error = "We couldn't load your profile. Please try again.";
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't reach the server. Check your connection and retry.";
        isLoading = false;
      });
    }
  }

  // ----------------------------------------------------------------------
  // REGISTER NEW EMPLOYEE SELFIE
  // ----------------------------------------------------------------------
  Future<void> registerEmployee() async {
    if (_image == null) {
      _toast("Please capture a selfie to register.");
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      final token = await _getAuthToken();
      final url = Uri.parse('${ApiConfig.desktopBase}register/');
      final req = http.MultipartRequest("POST", url);

      if (token != null && token.isNotEmpty) {
        req.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }

      req.fields["emp_id"] = widget.empId;
      req.fields["name"] = employeeName;
      req.fields["department"] = department;
      req.fields["dob"] = dob;
      req.fields["blood_group"] = bloodGroup;

      req.files.add(await http.MultipartFile.fromPath(
        "source_image",
        _image!.path,
        filename: path.basename(_image!.path),
      ));

      final res = await req.send();
      final resBody = await res.stream.bytesToString();
      final dynamic parsed = jsonDecode(resBody);
      if (parsed is! Map<String, dynamic>) {
        _toast("Invalid server response (${res.statusCode}).");
        return;
      }
      final json = parsed;

      final message = (json["message"] ?? "Registration failed").toString();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _toast(message);
        _fetchProfile();
      } else {
        _toast("Failed: $message");
      }
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ----------------------------------------------------------------------
  // CAPTURE IMAGE
  // ----------------------------------------------------------------------
  Future<void> _captureImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 640,
      minHeight: 480,
      quality: 70,
    );

    final compressedPath = path.join(
      path.dirname(picked.path),
      "cmp_${path.basename(picked.path)}",
    );

    await File(compressedPath).writeAsBytes(compressed);

    setState(() {
      _image = XFile(compressedPath);
      imageName = null;
    });
  }

  // ----------------------------------------------------------------------
  // TOAST
  // ----------------------------------------------------------------------
  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: CaptainTheme.accentDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _getAuthToken() async {
    final authRepo = getIt<AuthRepository>();
    final user = await authRepo.getAuthenticatedUser();
    final token = user?.authToken?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  // ----------------------------------------------------------------------
  // UI
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CaptainTheme.background,
      appBar: AppBar(
        backgroundColor: CaptainTheme.surface,
        foregroundColor: CaptainTheme.strongText,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Selfie Registration",
          style: TextStyle(
            color: CaptainTheme.strongText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: CaptainBackground(
        child: isLoading
            ? Center(
                child: CircularProgressIndicator(color: CaptainTheme.accent),
              )
            : _error != null
                ? _errorView()
                : _content(),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // CONTENT
  // ----------------------------------------------------------------------
  Widget _content() {
    ImageProvider? profileImage;
    if (_image != null) {
      profileImage = FileImage(File(_image!.path));
    } else if (imageName != null && imageName!.isNotEmpty) {
      profileImage = NetworkImage("$mediaBaseUrl/media/$imageName");
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        children: [
          _heroCard(profileImage),
          const SizedBox(height: 16),
          _detailsCard(),
          const SizedBox(height: 22),
          if (!isRegistered) _registerButton(),
        ],
      ),
    );
  }

  // ==========================================================
  // HERO — avatar + name + designation + registration status
  // ==========================================================
  Widget _heroCard(ImageProvider? profileImage) {
    final canCapture = imageName == null || imageName!.isEmpty;
    final displayName = employeeName.trim().isEmpty ? '—' : employeeName.trim();
    final subtitle = designation.trim().isNotEmpty
        ? designation.trim()
        : (department.trim().isNotEmpty ? department.trim() : 'Field staff');

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: CaptainTheme.accent, width: 2.5),
                ),
                padding: const EdgeInsets.all(3),
                child: CircleAvatar(
                  radius: 52,
                  backgroundColor: CaptainTheme.surfaceMuted,
                  backgroundImage: profileImage,
                  child: profileImage == null
                      ? Icon(Icons.person,
                          size: 48, color: CaptainTheme.mutedText)
                      : null,
                ),
              ),
              if (canCapture)
                GestureDetector(
                  onTap: _captureImage,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: CaptainTheme.accentGradient,
                      border: Border.all(color: CaptainTheme.surface, width: 3),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.camera_alt,
                        size: 18, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: CaptainTheme.strongText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CaptainTheme.mutedText,
            ),
          ),
          const SizedBox(height: 14),
          _statusChip(),
        ],
      ),
    );
  }

  Widget _statusChip() {
    final registered = isRegistered;
    final Color color = registered ? CaptainTheme.success : CaptainTheme.accent;
    final IconData icon =
        registered ? Icons.verified_rounded : Icons.photo_camera_front_rounded;
    final String label = registered
        ? 'Face registered'
        : (_image != null
            ? 'Selfie ready — tap Register'
            : 'Capture a selfie to register attendance');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DETAILS — read-only staff record
  // ==========================================================
  Widget _detailsCard() {
    final rows = <Widget>[
      _infoTile(Icons.badge_outlined, "Name", employeeName),
      _infoTile(Icons.apartment_outlined, "Department", department),
      _infoTile(Icons.work_outline_rounded, "Designation", designation),
      _infoTile(Icons.cake_outlined, "Date of Birth", _formatDate(dob)),
      _infoTile(Icons.bloodtype_outlined, "Blood Group", bloodGroup),
      _infoTile(
          Icons.event_available_outlined, "Date of Joining", _formatDate(doj)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: CaptainTheme.hairline.withValues(alpha: 0.6),
              ),
          ],
        ],
      ),
    );
  }

  Widget _registerButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _submitting ? null : registerEmployee,
          child: Ink(
            decoration: BoxDecoration(
              gradient: CaptainTheme.accentGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: CaptainTheme.softShadow,
            ),
            child: Center(
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : const Text(
                      "Register Selfie",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ERROR STATE
  // ==========================================================
  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48, color: CaptainTheme.mutedText),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: CaptainTheme.strongText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 170,
              height: 46,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _fetchProfile,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: CaptainTheme.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Retry',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // UI COMPONENTS
  // ----------------------------------------------------------------------
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: CaptainTheme.surface,
      borderRadius: CaptainTheme.cardRadius,
      border: Border.all(color: CaptainTheme.hairline),
      boxShadow: CaptainTheme.softShadow,
    );
  }

  /// Formats an ISO date string (e.g. "1992-05-20") as "20 May 1992".
  /// Returns the raw value unchanged if it isn't a parseable date.
  String _formatDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    return DateFormat('d MMM yyyy').format(parsed);
  }

  Widget _infoTile(IconData icon, String label, String value) {
    final hasValue = value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CaptainTheme.accentSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: CaptainTheme.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: CaptainTheme.mutedText,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasValue ? value : 'Not provided',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    color: hasValue
                        ? CaptainTheme.strongText
                        : CaptainTheme.mutedText.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
