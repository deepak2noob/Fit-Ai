import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'yoga_pose_classifier.dart'; // ✅ Import classifier
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PostureCameraPage extends StatefulWidget {
  const PostureCameraPage({Key? key}) : super(key: key);

  @override
  State<PostureCameraPage> createState() => _PostureCameraPageState();
}

class _PostureCameraPageState extends State<PostureCameraPage> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  Pose? _pose;
  String _statusText = "Initializing camera...";
  String _currentPose = "No Pose"; // ✅ Detected yoga pose text

  // ✅ Controls
  int _extraRotation = 0; // 0,90,180,270
  bool _mirror = false;
  Offset _dragOffset = Offset.zero; // drag skeleton

  late YogaPoseClassifier _classifier; // ✅ Classifier instance

  // ✅ Supported pose list
  final List<String> _supportedPoses = [
    "T-Pose",
    "Warrior Pose",
    "Tree Pose",
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
      ),
    );
    _classifier = YogaPoseClassifier(); // ✅ init classifier
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          _statusText = "Camera initialized.";
        });
      }
    } catch (e) {
      debugPrint("❌ Error initializing camera: $e");
      if (mounted) {
        setState(() {
          _statusText = "Camera initialization failed.";
        });
      }
    }
  }

  Uint8List _yuv420toNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = width * height ~/ 2;
    final Uint8List nv21 = Uint8List(ySize + uvSize);

    final planeY = image.planes[0];
    int offset = 0;
    for (int row = 0; row < height; row++) {
      int start = row * planeY.bytesPerRow;
      nv21.setRange(offset, offset + width, planeY.bytes, start);
      offset += width;
    }

    final planeU = image.planes[1];
    final planeV = image.planes[2];
    final int uvRowStride = planeU.bytesPerRow;
    final int uvPixelStride = planeU.bytesPerPixel!;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        int uvIndex = row * uvRowStride + col * uvPixelStride;
        int nvIndex = ySize + (row * width) + (col * 2);
        nv21[nvIndex] = planeV.bytes[uvIndex];
        nv21[nvIndex + 1] = planeU.bytes[uvIndex];
      }
    }
    return nv21;
  }

  InputImage? _convertCameraImage(
      CameraImage image, CameraDescription description) {
    try {
      final bytes = _yuv420toNv21(image);
      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());

      final rotation = InputImageRotationValue.fromRawValue(
              description.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      final format = InputImageFormat.nv21;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
    } catch (e) {
      debugPrint("❌ Error converting camera image: $e");
      return null;
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isBusy || _cameraController == null) return;
    _isBusy = true;

    try {
      final inputImage =
          _convertCameraImage(cameraImage, _cameraController!.description);

      if (inputImage == null) {
        debugPrint("! Skipped frame: unsupported format.");
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        setState(() {
          _statusText = "No person detected";
          _pose = null;
          _currentPose = "No Pose";
        });
      } else if (poses.length > 1) {
        setState(() {
          _statusText = "Multiple people detected – skipping";
          _pose = null;
          _currentPose = "Unknown";
        });
      } else {
        final pose = poses.first;
        final poseName = _classifier.classify(pose.landmarks); // ✅ classify
        setState(() {
          _statusText = "Detected 1 person";
          _pose = pose;
          _currentPose = poseName; // ✅ update label
        });
      }
    } catch (e) {
      debugPrint("❌ Error processing image: $e");
    } finally {
      _isBusy = false;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Posture Camera"),
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_90_degrees_ccw),
            onPressed: () {
              setState(() {
                _extraRotation = (_extraRotation + 90) % 360;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip),
            onPressed: () {
              setState(() {
                _mirror = !_mirror;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh), // ✅ reset icon
            onPressed: () {
              setState(() {
                _dragOffset = Offset.zero;
              });
            },
          ),
        ],
      ),
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _dragOffset += details.delta;
          });
        },
        child: Stack(
          children: [
            CameraPreview(_cameraController!),

            if (_pose != null)
              Positioned.fill(
                child: CustomPaint(
                  painter: PosePainter(
                    _pose!,
                    _cameraController!.value.previewSize!,
                    _extraRotation,
                    _mirror,
                    _dragOffset,
                  ),
                ),
              ),

            // ✅ Supported Poses legend at top
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Supported Poses: ${_supportedPoses.join(", ")}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),

            // ✅ Show detected yoga pose at bottom
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _currentPose,
                      style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PosePainter unchanged…
class PosePainter extends CustomPainter {
  final Pose pose;
  final Size previewSize;
  final int extraRotation;
  final bool mirror;
  final Offset dragOffset;

  PosePainter(this.pose, this.previewSize, this.extraRotation, this.mirror,
      this.dragOffset);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint jointPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final Paint bonePaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    Offset _transformPoint(double x, double y) {
      double normX = x / previewSize.width;
      double normY = y / previewSize.height;

      double rotatedX, rotatedY;
      switch (extraRotation % 360) {
        case 90:
          rotatedX = normY;
          rotatedY = 1 - normX;
          break;
        case 180:
          rotatedX = 1 - normX;
          rotatedY = 1 - normY;
          break;
        case 270:
          rotatedX = 1 - normY;
          rotatedY = normX;
          break;
        default:
          rotatedX = normX;
          rotatedY = normY;
      }

      if (mirror) rotatedX = 1 - rotatedX;

      return Offset(rotatedX * size.width, rotatedY * size.height) + dragOffset;
    }

    void drawJoint(PoseLandmarkType type) {
      final lm = pose.landmarks[type];
      if (lm != null) {
        canvas.drawCircle(_transformPoint(lm.x, lm.y), 15, jointPaint);
      }
    }

    void connect(PoseLandmarkType a, PoseLandmarkType b) {
      final ja = pose.landmarks[a];
      final jb = pose.landmarks[b];
      if (ja != null && jb != null) {
        canvas.drawLine(
          _transformPoint(ja.x, ja.y),
          _transformPoint(jb.x, jb.y),
          bonePaint,
        );
      }
    }

    drawJoint(PoseLandmarkType.nose);

    drawJoint(PoseLandmarkType.leftShoulder);
    drawJoint(PoseLandmarkType.rightShoulder);
    drawJoint(PoseLandmarkType.leftElbow);
    drawJoint(PoseLandmarkType.rightElbow);
    drawJoint(PoseLandmarkType.leftWrist);
    drawJoint(PoseLandmarkType.rightWrist);

    connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
    connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
    connect(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
    connect(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
    connect(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    if (leftHip != null && rightHip != null) {
      final midHip = Offset(
        (leftHip.x + rightHip.x) / 2,
        (leftHip.y + rightHip.y) / 2,
      );
      canvas.drawCircle(_transformPoint(midHip.dx, midHip.dy), 15, jointPaint);

      final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
      if (ls != null) {
        canvas.drawLine(
            _transformPoint(ls.x, ls.y), _transformPoint(midHip.dx, midHip.dy), bonePaint);
      }
      if (rs != null) {
        canvas.drawLine(
            _transformPoint(rs.x, rs.y), _transformPoint(midHip.dx, midHip.dy), bonePaint);
      }
    }

    drawJoint(PoseLandmarkType.leftKnee);
    drawJoint(PoseLandmarkType.rightKnee);
    drawJoint(PoseLandmarkType.leftAnkle);
    drawJoint(PoseLandmarkType.rightAnkle);

    connect(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
    connect(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
    connect(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
    connect(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
