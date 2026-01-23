
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/offline_attendance.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as path;

class CameraScreen extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final bool isTripAttendance;
  // String latitude;
  // String longitude;
  // final VoidCallback onAttendanceMarked;
  const CameraScreen({super.key, 
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

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  XFile? _image;
  bool _isLoading = false;
  bool _isProcessingCapture = false;
  bool _autoCaptureScheduled = false;
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

  /// **Check if GPS is Enabled and Get Location**
  /// **Check if GPS is Enabled and Get Location**
  Future<void> _checkGpsAndInitialize() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("⚠️ Location permission denied");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please allow location access in settings!'), backgroundColor: Colors.red),
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
          SnackBar(content: Text('GPS not detected. Move outside for better signal.'), backgroundColor: Colors.orange),
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
    final status = await Permission.camera.request();
    if (status.isGranted) {
      try {
        final cameras = await availableCameras();
        final frontCamera = cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();

        if (mounted) {
          setState(() {
            _cameraController!.setFocusMode(FocusMode.auto);
          });
          _scheduleAutoCapture();
        }
    
      } catch (e) {
        print('Error initializing camera: $e');
      }
    } else {
      print('Camera permission denied');
    }
  }

  void _scheduleAutoCapture() {
    if (_autoCaptureScheduled) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    _autoCaptureScheduled = true;
    Future.delayed(const Duration(milliseconds: 600), () {
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

      if (widget.isTripAttendance) {
        await _sendTripAttendance();
      } else {
        await _sendDataToBackend();
      }
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
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.7.176:8000/api/desktop/recognize/'),  //can use local ip or domain name
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

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        _speak("Attendance marked successfully");
        if (mounted) Navigator.pop(context, true);
      } else {
        throw Exception("Face mismatch");
      }

    } catch (e) {
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
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTripAttendance() async {
    if (_image == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://192.168.7.176:8000/api/desktop/vehicles/trip-attendance/'),
      );

      final token = await _getAuthToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields["latitude"] = latitude;
      request.fields["longitude"] = longitude;
      request.fields["source"] = "MOBILE";

      request.files.add(await http.MultipartFile.fromPath(
        "photo",
        _image!.path,
      ));

      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        _speak("Trip attendance recorded");
        if (mounted) Navigator.pop(context, true);
        return;
      }

      String message = "Trip attendance failed.";
      try {
        final data = json.decode(responseBody);
        if (data is Map) {
          if (data["detail"] != null) {
            message = data["detail"].toString();
          } else if (data["non_field_errors"] is List &&
              data["non_field_errors"].isNotEmpty) {
            message = data["non_field_errors"].first.toString();
          }
        }
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      _speak(message);
      if (mounted) Navigator.pop(context, false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Trip attendance failed.")),
        );
      }
      _speak("Trip attendance failed");
      if (mounted) Navigator.pop(context, false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final compressedBytes = await FlutterImageCompress.compressWithList(imageBytes, minWidth: 640, minHeight: 480, quality: 50);
    return XFile.fromData(Uint8List.fromList(compressedBytes), path: image.path);
  }

  Widget _cameraPreview() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
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
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _takePicture,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(
                widget.isTripAttendance
                    ? "Capture Trip Attendance"
                    : "Capture Attendance",
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                backgroundColor: Colors.green.shade700,
              ),
            ),
          ),
          if (_isProcessingCapture || _isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
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
