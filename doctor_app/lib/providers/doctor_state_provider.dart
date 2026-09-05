import 'package:flutter/foundation.dart';
import '../models/patient.dart';
import 'dart:math';

class DoctorStateProvider extends ChangeNotifier {
  List<Patient> _patients = [];

  List<Patient> get patients => _patients;

  DoctorStateProvider() {
    _loadMockData();
  }

  void _loadMockData() {
    final now = DateTime.now();
    _patients = [
      Patient(
        id: 'HS-9042',
        name: 'John Doe',
        age: 62,
        affectedHand: 'Right',
        strokeSubtype: 'Ischemic',
        complianceStreak: 12,
        latestSessionScore: 78.5,
        baselineCalibration: {'Thumb': 45.0, 'Index': 50.0, 'Middle': 48.0},
        needsAttention: true,
        alertMessage: '28% velocity drop detected in today\'s session',
        reports: [
          SBARReport(
            date: now.subtract(const Duration(days: 1)),
            situation: 'Patient reports increased stiffness in right wrist during morning exercises.',
            background: '62yo male, 4 weeks post-ischemic stroke. Currently on daily HapticSync protocol.',
            assessment: 'Observed 28% velocity drop and compensatory shoulder movement during pinch tasks.',
            recommendation: 'Reduce resistance level by 20% for the next 3 sessions and monitor fatigue.',
          ),
          SBARReport(
            date: now.subtract(const Duration(days: 5)),
            situation: 'Routine weekly check-in.',
            background: 'Patient has been compliant with daily sessions.',
            assessment: 'Steady progress in range of motion. Grip strength improving.',
            recommendation: 'Continue current protocol. Re-evaluate in 1 week.',
          ),
        ],
        telemetry: _generateMockTelemetry(now, 30, 40, 60),
      ),
      Patient(
        id: 'HS-8123',
        name: 'Sarah Smith',
        age: 55,
        affectedHand: 'Left',
        strokeSubtype: 'Hemorrhagic',
        complianceStreak: 21,
        latestSessionScore: 92.0,
        baselineCalibration: {'Thumb': 55.0, 'Index': 60.0, 'Middle': 58.0},
        needsAttention: false,
        reports: [
          SBARReport(
            date: now.subtract(const Duration(days: 2)),
            situation: 'Excellent performance in latest session.',
            background: '55yo female, progressing well in rehabilitation.',
            assessment: 'AROM has increased by 15% over the last two weeks.',
            recommendation: 'Increase difficulty level for fine motor tasks.',
          ),
        ],
        telemetry: _generateMockTelemetry(now, 30, 50, 75),
      ),
      Patient(
        id: 'HS-7456',
        name: 'Robert Jones',
        age: 71,
        affectedHand: 'Right',
        strokeSubtype: 'Ischemic',
        complianceStreak: 3,
        latestSessionScore: 61.2,
        baselineCalibration: {'Thumb': 30.0, 'Index': 35.0, 'Middle': 32.0},
        needsAttention: true,
        alertMessage: 'Flagged for spastic fatigue.',
        reports: [
          SBARReport(
            date: now.subtract(const Duration(days: 0)),
            situation: 'Patient struggling to complete full session.',
            background: '71yo male, history of fatigue.',
            assessment: 'Data indicates early onset of spastic fatigue during repetitive tasks.',
            recommendation: 'Break daily session into two shorter sessions.',
          ),
        ],
        telemetry: _generateMockTelemetry(now, 7, 30, 45),
      ),
      Patient(
        id: 'HS-6789',
        name: 'Emily Davis',
        age: 48,
        affectedHand: 'Left',
        strokeSubtype: 'Ischemic',
        complianceStreak: 8,
        latestSessionScore: 85.0,
        baselineCalibration: {'Thumb': 50.0, 'Index': 52.0, 'Middle': 50.0},
        needsAttention: false,
        reports: [
          SBARReport(
             date: now.subtract(const Duration(days: 4)),
             situation: 'Consistent progress.',
             background: '48yo female.',
             assessment: 'Patient is hitting all target metrics for current phase.',
             recommendation: 'Maintain current protocol.',
          )
        ],
        telemetry: _generateMockTelemetry(now, 30, 45, 65),
      ),
    ];
    notifyListeners();
  }

  List<TelemetryData> _generateMockTelemetry(DateTime endDate, int days, double minVal, double maxVal) {
    List<TelemetryData> data = [];
    final random = Random();
    for (int i = days; i >= 0; i--) {
      // Simulate an upward trend with some noise
      double progress = (days - i) / days; 
      double baseVal = minVal + (maxVal - minVal) * progress;
      double noise = (random.nextDouble() - 0.5) * 10; // +/- 5 variance
      double val = baseVal + noise;
      val = val.clamp(0.0, 100.0); // Ensure it stays within reasonable bounds
      
      data.add(TelemetryData(
        date: endDate.subtract(Duration(days: i)),
        arom: double.parse(val.toStringAsFixed(1)),
      ));
    }
    return data;
  }

  void addPatient(Patient patient) {
    _patients.add(patient);
    notifyListeners();
  }
}
