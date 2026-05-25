import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/env.dart';
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

        setState(() {
          employeeName = data["employee_name"] ?? "";
          department = data["department"] ?? "";
          designation = data["designation"] ?? "";
          dob = data["personal"]?["dob"] ?? "";
          bloodGroup = data["personal"]?["blood_group"] ?? "";
          doj = data["doj"] ?? "";

          imageName = photo;

          // Registered ONLY if photo exists
          isRegistered = photo != null && photo.isNotEmpty;
        });
      }
    } catch (_) {}

    setState(() => isLoading = false);
  }

  // ----------------------------------------------------------------------
  // REGISTER NEW EMPLOYEE SELFIE
  // ----------------------------------------------------------------------
  Future<void> registerEmployee() async {
    if (_image == null) {
      _toast("Please capture an image to register.");
      return;
    }

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
        backgroundColor: AppColors.primary,
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
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    ImageProvider? profileImage;
    if (_image != null) {
      profileImage = FileImage(File(_image!.path));
    } else if (imageName != null && imageName!.isNotEmpty) {
      profileImage = NetworkImage("$mediaBaseUrl/media/$imageName");
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          "Selfie Registration",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ==========================================================
            // PROFILE IMAGE
            // ==========================================================
            // ==========================================================
// PROFILE IMAGE
// ==========================================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: profileImage,
                        child: profileImage == null
                            ? const Icon(Icons.person,
                                size: 50, color: Colors.grey)
                            : null,
                      ),

                      // ----------------------------------------------------------
                      // SHOW CAMERA ICON ONLY IF NO IMAGE EXISTS
                      // ----------------------------------------------------------
                      if (imageName == null || imageName!.isEmpty)
                        GestureDetector(
                          onTap: _captureImage,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary,
                            child: const Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isRegistered)
                    Column(
                      children: [
                        const Text(
                          "Capture a selfie to register attendance.",
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ==========================================================
            // READ-ONLY EMPLOYEE DETAILS
            // ==========================================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _infoTile("Name", employeeName),
                  _infoTile("Department", department),
                  _infoTile("Designation", designation),
                  _infoTile("Date of Birth", dob),
                  _infoTile("Blood Group", bloodGroup),
                  _infoTile("Date of Joining", doj),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ==========================================================
            // REGISTER BUTTON (only if not registered)
            // ==========================================================
            if (!isRegistered)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: registerEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Register Selfie",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            "$label:",
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}
