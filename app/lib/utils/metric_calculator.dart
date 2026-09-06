import 'dart:math';
import '../models/sensor_packet.dart';
import '../models/calibration_data.dart';

class MetricCalculator {
  static Map<String, dynamic> computeSessionMetrics(List<SensorPacket> packets, CalibrationData calibration) {
    if (packets.isEmpty) return _emptyMetrics();

    double maxThumb = 0.0, maxIndex = 0.0, maxMiddle = 0.0;
    double minPitch = double.infinity, maxPitch = double.negativeInfinity;
    double minRoll = double.infinity, maxRoll = double.negativeInfinity;
    
    double jitterSum = 0.0;
    List<double> accMags = [];

    for (int i = 0; i < packets.length; i++) {
      final p = packets[i];
      
      // Flex Max Tracking (0: Thumb, 1: Index, 2: Middle)
      maxThumb = max(maxThumb, p.flexValues[0]);
      maxIndex = max(maxIndex, p.flexValues[1]);
      maxMiddle = max(maxMiddle, p.flexValues[2]);

      // Wrist ROM
      minPitch = min(minPitch, p.pitch);
      maxPitch = max(maxPitch, p.pitch);
      minRoll = min(minRoll, p.roll);
      maxRoll = max(maxRoll, p.roll);

      // Jitter & Velocity
      if (i > 0) {
        final prev = packets[i - 1];
        double dPitch = (p.pitch - prev.pitch).abs();
        double dRoll = (p.roll - prev.roll).abs();
        double diff = dPitch + dRoll;
        jitterSum += diff;
        accMags.add(diff);
      }
    }

    // ROM % = ((peakFlex - flexMin) / (flexMax - flexMin) * 100).clamp(0, 100)
    double calcRom(int fingerIdx, double peakFlex) {
      if (fingerIdx >= calibration.flexMin.length) return 0.0;
      double fMin = calibration.flexMin[fingerIdx];
      double fMax = calibration.flexMax[fingerIdx];
      if (fMax - fMin == 0) return 0.0;
      return ((peakFlex - fMin) / (fMax - fMin) * 100).clamp(0.0, 100.0);
    }

    double thumbRom = calcRom(0, maxThumb);
    double indexRom = calcRom(1, maxIndex);
    double middleRom = calcRom(2, maxMiddle);

    double pitchRom = minPitch == double.infinity ? 0.0 : (maxPitch - minPitch).abs();
    double rollRom = minRoll == double.infinity ? 0.0 : (maxRoll - minRoll).abs();

    double avgJitter = packets.length > 1 ? jitterSum / (packets.length - 1) : 0.0;
    // Normalize smoothness (1.0 is perfectly smooth, 0.0 is very jittery)
    double smoothnessScore = (1.0 - (avgJitter / 10.0)).clamp(0.0, 1.0);

    // Tremor power (variance of jitter)
    double tremorPower = 0.0;
    if (accMags.length > 1) {
      double mean = accMags.reduce((a, b) => a + b) / accMags.length;
      double sumSq = accMags.fold(0.0, (val, e) => val + pow(e - mean, 2));
      tremorPower = sumSq / accMags.length;
    }

    return {
      "thumb_rom_pct": double.parse(thumbRom.toStringAsFixed(1)),
      "index_rom_pct": double.parse(indexRom.toStringAsFixed(1)),
      "middle_rom_pct": double.parse(middleRom.toStringAsFixed(1)),
      "sustained_hold_stability": double.parse(smoothnessScore.toStringAsFixed(2)),
      "pitch_rom_deg": double.parse(pitchRom.toStringAsFixed(1)),
      "roll_rom_deg": double.parse(rollRom.toStringAsFixed(1)),
      "movement_velocity_mean": double.parse(avgJitter.toStringAsFixed(1)),
      "smoothness_score": double.parse(smoothnessScore.toStringAsFixed(2)),
      "tremor_power": double.parse(tremorPower.toStringAsFixed(3)),
    };
  }

  static Map<String, dynamic> _emptyMetrics() {
    return {
      "thumb_rom_pct": 0.0,
      "index_rom_pct": 0.0,
      "middle_rom_pct": 0.0,
      "sustained_hold_stability": 1.0,
      "pitch_rom_deg": 0.0,
      "roll_rom_deg": 0.0,
      "movement_velocity_mean": 0.0,
      "smoothness_score": 1.0,
      "tremor_power": 0.0,
    };
  }
}
