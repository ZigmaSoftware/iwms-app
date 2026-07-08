import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/offline_attendance.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CameraScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final bool isTripAttendance;
  // String latitude;
  // String longitude;
  // final VoidCallback onAttendanceMarked;
  const CameraScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.isTripAttendance = false,
    // required this.latitude,
    // required this.longitude,
    // required this.onAttendanceMarked,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  XFile? _image;
  bool _isLoading = false;
  bool _isProcessingCapture = false;
  bool _isInitializingCamera = true;
  bool _autoCaptureScheduled = false;
  bool _cameraPermissionNeedsSettings = false;
  String? _cameraErrorMessage;
  final FlutterTts _flutterTts = FlutterTts();
  late String latitude;
  late String longitude;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    latitude = "0.0";
    longitude = "0.0";
    _checkGpsAndInitialize();
    _initializeTts();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _cameraPermissionNeedsSettings) {
      _initializeCamera();
    }
  }

  /// **Check if GPS is Enabled and Get Location**
  /// **Check if GPS is Enabled and Get Location**
  Future<void> _checkGpsAndInitialize() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("⚠️ Location permission denied");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Please allow location access in settings!'),
              backgroundColor: Colors.red),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("🚨 Location permission permanently denied");
      return;
    }

    bool isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      _showEnableGpsPopup();
      return;
    }

    // 🌟 Fetch location multiple times to ensure accuracy
    Position? position;
    for (int i = 0; i < 3; i++) {
      position = await _getCurrentLocation();
      if (position != null) break;
      await Future.delayed(Duration(seconds: 2)); // Small delay for retries
    }

    if (position != null) {
      if (mounted) {
        setState(() {
          latitude = position!.latitude.toString();
          longitude = position.longitude.toString();
        });
      }
    } else {
      print("❌ Failed to fetch location");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('GPS not detected. Move outside for better signal.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // Use high accuracy
        timeLimit: Duration(seconds: 7), // Increase timeout
      );
    } catch (e) {
      print("❌ Error getting location: $e");
      return null;
    }
  }

  /// **Show Popup to Enable GPS**
  void _showEnableGpsPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: Colors.red),
            SizedBox(width: 10),
            Text("Enable GPS"),
          ],
        ),
        content: Text(
          "Your GPS is turned off. This app requires location access to function properly. Please turn it on.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              Navigator.of(context).pop();
            },
            child: Text("Turn On GPS"),
          ),
          TextButton(
            onPressed: () {
              _exitApp();
            },
            child: Text("Exit App", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// **Exit App If Location Not Found**
  void _exitApp() {
    Navigator.pop(context);
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  /// **Initialize Camera**
  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _isInitializingCamera = true;
        _cameraErrorMessage = null;
        _cameraPermissionNeedsSettings = false;
      });
    }

    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (!mounted) return;

    if (!status.isGranted) {
      final needsSettings = status.isPermanentlyDenied || status.isRestricted;
      setState(() {
        _isInitializingCamera = false;
        _cameraPermissionNeedsSettings = needsSettings;
        _cameraErrorMessage = needsSettings
            ? 'Camera permission is blocked. Enable camera access from app settings to punch attendance.'
            : 'Camera permission is required to punch attendance.';
      });
      debugPrint('Camera permission denied: $status');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera found on this device.');
      }

      final selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializingCamera = false;
      });
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      _scheduleAutoCapture();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isInitializingCamera = false;
          _cameraErrorMessage = 'Unable to open camera. Please try again.';
        });
      }
    }
  }

  Future<void> _retryCameraPermission() async {
    if (_cameraPermissionNeedsSettings) {
      await openAppSettings();
      return;
    } else {
      await _initializeCamera();
    }
  }

  void _scheduleAutoCapture() {
    if (_autoCaptureScheduled) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _autoCaptureScheduled = true;
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) _takePicture();
    });
  }

  Future<void> _takePicture() async {
    if (_isProcessingCapture || _isLoading) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      setState(() => _isProcessingCapture = true);

      final ctrl = _cameraController!;
      final image = await ctrl.takePicture();

      final compressedImage = await _compressImage(image);
      if (!mounted) return;

      setState(() => _image = compressedImage);

      await _sendDataToBackend();
    } catch (e) {
      print('❌ Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image. Please retry.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingCapture = false);
      }
    }
  }

  Future<void> _speak(String message) async {
    await _flutterTts.speak(message);
  }

  // Future<void> _sendDataToBackend() async {
  //   setState(() {
  //     _isLoading = true;
  //   });

  //   // ⏳ Ensure valid location before sending data
  //   if (latitude == "0.0" || longitude == "0.0") {
  //     print("⚠️ Invalid coordinates: $latitude, $longitude. Retrying location fetch...");
  //     Position? position = await _getCurrentLocation();
  //     if (position != null) {
  //       latitude = position.latitude.toString();
  //       longitude = position.longitude.toString();
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('GPS error! Move outside and retry.'), backgroundColor: Colors.red),
  //       );
  //       setState(() {
  //         _isLoading = false;
  //       });
  //       return;
  //     }
  //   }

  //   try {
  //     var request = http.MultipartRequest(
  //       'POST',
  //       Uri.parse('http://10.64.151.226:8000/api/desktop/recognize/'),
  //     );
  //     request.fields['emp_id'] = widget.employeeId;
  //     request.fields['name'] = widget.employeeName;
  //     request.fields['latitude'] = latitude;
  //     request.fields['longitude'] = longitude;

  //     var multipartFile = http.MultipartFile(
  //       'captured_image',
  //       http.ByteStream.fromBytes(await _image!.readAsBytes()),
  //       await _image!.length(),
  //       filename: path.basename(_image!.path),
  //     );
  //     request.files.add(multipartFile);

  //     var response = await request.send();
  //     var responseBody = await response.stream.bytesToString();

  //     if (response.statusCode == 200) {
  //       setState(() {
  //         _isRecognized = true;
  //         _recognitionFinished = true;
  //       });

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('✅ Attendance marked successfully'), backgroundColor: Colors.green),
  //       );

  //       await _speak('Attendance marked successfully');
  //       // widget.onAttendanceMarked();
  //       Navigator.of(context).pop(true);
  //     } else {
  //       var data = json.decode(responseBody);
  //       setState(() {
  //         _isRecognized = false;
  //         _recognitionFinished = true;
  //       });

  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text(data['error'] ?? 'Failed to send data'), backgroundColor: Colors.red),
  //       );

  //       await _speak('Failed to send data');
  //       Navigator.of(context).pop(false);
  //     }
  //   } catch (e) {
  //     setState(() {
  //       _isRecognized = false;
  //       _recognitionFinished = true;
  //     });

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('🚨 Network error: $e'), backgroundColor: Colors.red),
  //     );

  //     await _speak('Face Not Matched');
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<void> _sendDataToBackend() async {
    if (_image == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.desktopBase}recognize/'),
      );

      final token = await _getAuthToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields["emp_id"] = widget.employeeId;
      request.fields["name"] = widget.employeeName;
      request.fields["latitude"] = latitude;
      request.fields["longitude"] = longitude;

      request.files.add(await http.MultipartFile.fromPath(
        "captured_image",
        _image!.path,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        _speak("Attendance marked successfully");
        if (mounted) Navigator.pop(context, true);
        return;
      }

      final message = _extractErrorMessage(
        responseBody,
        fallback: "Attendance marking failed.",
      );
      _showError(message);
      await _speak(message);
    } on TimeoutException catch (_) {
      // ---------------------------------------------------------
      // OFFLINE SAVE
      // ---------------------------------------------------------
      await saveOfflineAttendance(
        empId: widget.employeeId,
        name: widget.employeeName,
        imagePath: _image!.path,
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("No internet. Attendance saved offline."),
          backgroundColor: Colors.orange,
        ));
      }

      _speak("Attendance saved offline");
      if (mounted) Navigator.pop(context, true);
    } on http.ClientException catch (_) {
      await saveOfflineAttendance(
        empId: widget.employeeId,
        name: widget.employeeName,
        imagePath: _image!.path,
        latitude: latitude,
        longitude: longitude,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No internet. Attendance saved offline."),
          backgroundColor: Colors.orange,
        ));
      }

      _speak("Attendance saved offline");
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      const message = "Attendance marking failed.";
      _showError(message);
      await _speak(message);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _getAuthToken() async {
    final authRepo = getIt<AuthRepository>();
    final user = await authRepo.getAuthenticatedUser();
    final token = user?.authToken?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  Future<XFile> _compressImage(XFile image) async {
    final imageBytes = await image.readAsBytes();
    final compressedBytes = await FlutterImageCompress.compressWithList(
      imageBytes,
      minWidth: 960,
      minHeight: 720,
      quality: 88,
    );
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/attendance_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(Uint8List.fromList(compressedBytes), flush: true);
    return XFile(file.path);
  }

  String _extractErrorMessage(String body, {required String fallback}) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        final detail = data["detail"]?.toString().trim();
        if (detail != null && detail.isNotEmpty) return detail;

        final error = data["error"]?.toString().trim();
        if (error != null && error.isNotEmpty) return error;

        final message = data["message"]?.toString().trim();
        if (message != null && message.isNotEmpty) return message;

        final missing = data["missing_fields"];
        if (missing is List && missing.isNotEmpty) {
          return "Missing fields: ${missing.join(', ')}";
        }
      }
    } catch (_) {}

    return fallback;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _cameraPreview() {
    if (_cameraErrorMessage != null) {
      return _CameraAccessView(
        message: _cameraErrorMessage!,
        actionLabel:
            _cameraPermissionNeedsSettings ? 'Open Settings' : 'Try Again',
        onAction: _retryCameraPermission,
      );
    }

    if (_isInitializingCamera) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return _CameraAccessView(
        message: 'Camera is not ready. Please try again.',
        actionLabel: 'Try Again',
        onAction: _initializeCamera,
      );
    }

    final previewSize = controller.value.previewSize;
    final screenSize = MediaQuery.of(context).size;
    final width = previewSize?.height ?? screenSize.width;
    final height = previewSize?.width ?? screenSize.height;

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: width,
        height: height,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _scheduleAutoCapture();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _cameraPreview()),
          Positioned(
            top: 36,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(false),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _CaptureButton(
              label: "Capture Attendance",
              onTap: _isLoading ||
                      _isProcessingCapture ||
                      _cameraController == null ||
                      !_cameraController!.value.isInitialized
                  ? null
                  : _takePicture,
            ),
          ),
          if (_isProcessingCapture || _isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: CaptainTheme.accent),
                      const SizedBox(height: 12),
                      const Text(
                        "Hold still, recognizing face...",
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

class _CameraAccessView extends StatelessWidget {
  const _CameraAccessView({
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
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onAction,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: CaptainTheme.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: onTap == null
                  ? const LinearGradient(
                      colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                    )
                  : CaptainTheme.accentGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: onTap == null ? null : CaptainTheme.softShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
