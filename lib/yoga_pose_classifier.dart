import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class YogaPoseClassifier {
  // Compute angle between 3 landmarks (in degrees)
  double _angleBetween(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final ab = Offset(a.x - b.x, a.y - b.y);
    final cb = Offset(c.x - b.x, c.y - b.y);

    final dot = ab.dx * cb.dx + ab.dy * cb.dy;
    final magAb = sqrt(ab.dx * ab.dx + ab.dy * ab.dy);
    final magCb = sqrt(cb.dx * cb.dx + cb.dy * cb.dy);

    if (magAb == 0 || magCb == 0) return 0;

    double cosAngle = dot / (magAb * magCb);
    cosAngle = cosAngle.clamp(-1.0, 1.0);

    return acos(cosAngle) * 180 / pi;
  }

  /// Classify pose based on landmark angles
  String classify(Map<PoseLandmarkType, PoseLandmark> lm) {
    if (lm.isEmpty) return "No Pose";

    // Arm angles
    final leftArm = _angleBetween(
      lm[PoseLandmarkType.leftShoulder]!,
      lm[PoseLandmarkType.leftElbow]!,
      lm[PoseLandmarkType.leftWrist]!,
    );

    final rightArm = _angleBetween(
      lm[PoseLandmarkType.rightShoulder]!,
      lm[PoseLandmarkType.rightElbow]!,
      lm[PoseLandmarkType.rightWrist]!,
    );

    // Torso angles
    final leftTorso = _angleBetween(
      lm[PoseLandmarkType.leftElbow]!,
      lm[PoseLandmarkType.leftShoulder]!,
      lm[PoseLandmarkType.leftHip]!,
    );

    final rightTorso = _angleBetween(
      lm[PoseLandmarkType.rightElbow]!,
      lm[PoseLandmarkType.rightShoulder]!,
      lm[PoseLandmarkType.rightHip]!,
    );

    // Leg angles
    final leftLeg = _angleBetween(
      lm[PoseLandmarkType.leftHip]!,
      lm[PoseLandmarkType.leftKnee]!,
      lm[PoseLandmarkType.leftAnkle]!,
    );

    final rightLeg = _angleBetween(
      lm[PoseLandmarkType.rightHip]!,
      lm[PoseLandmarkType.rightKnee]!,
      lm[PoseLandmarkType.rightAnkle]!,
    );

    // ✅ Simple classification rules
    if ((leftArm > 150 && rightArm > 150) &&
        (leftTorso > 60 && rightTorso > 60)) {
      return "T-Pose";
    }

    if ((leftLeg > 160 && rightLeg > 160) &&
        (leftArm > 150 && rightArm > 150)) {
      return "Mountain Pose";
    }

    if ((leftLeg < 100 && rightLeg > 150) ||
        (rightLeg < 100 && leftLeg > 150)) {
      return "Tree Pose";
    }

    if ((leftLeg < 100 && rightLeg > 150) &&
        (leftArm > 150 && rightArm > 150)) {
      return "Warrior Pose";
    }

    return "Unknown";
  }
}
