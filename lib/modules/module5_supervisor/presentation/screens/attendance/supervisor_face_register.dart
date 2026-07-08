import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Face enrollment for the supervisor. Captures a front-camera selfie and
/// uploads it to the shared, role-agnostic enrollment endpoint:
///   POST {base}register/  (multipart: emp_id, name, source_image)
///
/// The backend stores it as the reference face against which future
/// `recognize/` punches are matched. Returns `true` on a successful (or
/// already-existing) registration.
class SupervisorFaceRegisterScreen extends StatefulWidget {
  const SupervisorFaceRegisterScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  final String employeeId;
  final String employeeName;

  @override
  State<SupervisorFaceRegisterScreen> createState() =>
      _SupervisorFaceRegisterScreenState();
}

class _SupervisorFaceRegisterScreenState
    extends State<SupervisorFaceRegisterScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _busy = false;
  bool _needsSettings = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsSettings) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
        _needsSettings = false;
      });
    }

    var status = await Permission.camera.status;
    if (status.isDenied) status = await Permission.camera.request();
    if (!mounted) return;

    if (!status.isGranted) {
      final needsSettings = status.isPermanentlyDenied || status.isRestricted;
      setState(() {
        _initializing = false;
        _needsSettings = needsSettings;
        _error = needsSettings
            ? 'Camera permission is blocked. Enable camera access from app settings to register your face.'
            : 'Camera permission is required to register your face.';
      });
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera found on this device.');
      }
      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Unable to open camera. Please try again.';
        });
      }
    }
  }

  Future<void> _retry() async {
    if (_needsSettings) {
      await openAppSettings();
    } else {
      await _initCamera();
    }
  }

  Future<XFile> _compress(XFile image) async {
    final bytes = await image.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 960,
      minHeight: 720,
      quality: 88,
    );
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/register_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(Uint8List.fromList(compressed), flush: true);
    return XFile(file.path);
  }

  Future<String?> _authToken() async {
    final user = await getIt<AuthRepository>().getAuthenticatedUser();
    final token = user?.authToken?.trim();
    return (token == null || token.isEmpty) ? null : token;
  }

  Future<void> _captureAndRegister() async {
    final controller = _controller;
    if (_busy || controller == null || !controller.value.isInitialized) return;

    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      final image = await _compress(shot);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.desktopBase}register/'),
      );
      final token = await _authToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['emp_id'] = widget.employeeId;
      request.fields['name'] = widget.employeeName;
      request.files
          .add(await http.MultipartFile.fromPath('source_image', image.path));

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final message = _message(body) ?? 'Face registered successfully';
        _snack(message, ok: true);
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      _snack(_message(body) ?? 'Registration failed. Please try again.');
    } catch (_) {
      _snack('Registration failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _message(String body) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        for (final key in ['message', 'detail', 'error']) {
          final v = data[key]?.toString().trim();
          if (v != null && v.isNotEmpty) return v;
        }
      }
    } catch (_) {}
    return null;
  }

  void _snack(String msg, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? SupervisorTheme.success : SupervisorTheme.danger,
      ),
    );
  }

  Widget _preview() {
    if (_error != null) {
      return _AccessView(
        message: _error!,
        actionLabel: _needsSettings ? 'Open Settings' : 'Try Again',
        onAction: _retry,
      );
    }
    if (_initializing) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _AccessView(
        message: 'Camera is not ready. Please try again.',
        actionLabel: 'Try Again',
        onAction: _initCamera,
      );
    }
    final previewSize = controller.value.previewSize;
    final screen = MediaQuery.of(context).size;
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize?.height ?? screen.width,
        height: previewSize?.width ?? screen.height,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller?.value.isInitialized == true;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _preview()),
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            ),
          ),
          Positioned(
            top: 44,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Register your face',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: (!ready || _busy) ? null : _captureAndRegister,
              icon: const Icon(Icons.face_retouching_natural_rounded),
              label: const Text('Capture & Register'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                backgroundColor: SupervisorTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Registering your face…',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccessView extends StatelessWidget {
  const _AccessView({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 52),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 46),
                backgroundColor: SupervisorTheme.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
