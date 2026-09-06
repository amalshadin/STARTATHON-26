import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/design_tokens.dart';
import '../../providers/ble_telemetry_provider.dart';
import '../../providers/calibration_provider.dart';
import '../../models/sensor_packet.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  int _currentStage = 1;
  int _countdown = 3;
  bool _isRecording = false;
  Timer? _timer;
  final List<SensorPacket> _samples = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRecording(BleTelemetryProvider ble, CalibrationProvider cal, int stage) {
    setState(() {
      _isRecording = true;
      _countdown = 3;
      _samples.clear();
    });

    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (ble.latestPacket.timestamp.year > 2000) {
        _samples.add(ble.latestPacket);
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdown--;
      });

      if (_countdown <= 0) {
        timer.cancel();
        setState(() {
          _isRecording = false;
        });

        if (stage == 1) {
          cal.recordNeutralBaseline(_samples);
          setState(() {
            _currentStage = 2;
          });
        } else if (stage == 2) {
          cal.recordMaxFlexion(_samples);
          setState(() {
            _currentStage = 3;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ble = context.watch<BleTelemetryProvider>();
    final cal = context.watch<CalibrationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D), // Dark theme
      appBar: AppBar(
        title: const Text('Hand Calibration', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStageIndicator(1, _currentStage >= 1),
                  _buildStageDivider(),
                  _buildStageIndicator(2, _currentStage >= 2),
                  _buildStageDivider(),
                  _buildStageIndicator(3, _currentStage >= 3),
                ],
              ),
              const SizedBox(height: 40),

              // Stage Content
              Expanded(
                child: _buildStageContent(ble, cal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageIndicator(int stage, bool isActive) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? DesignTokens.primaryColor : Colors.grey[800],
      ),
      child: Center(
        child: Text(
          '$stage',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[500],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildStageDivider() {
    return Container(
      width: 40,
      height: 2,
      color: Colors.grey[800],
    );
  }

  Widget _buildStageContent(BleTelemetryProvider ble, CalibrationProvider cal) {
    if (!ble.isConnected) {
      return const Center(
        child: Text(
          'Please connect the glove first.',
          style: TextStyle(color: Colors.redAccent, fontSize: 18),
        ),
      );
    }

    if (_currentStage == 1) {
      return _buildStage1(ble, cal);
    } else if (_currentStage == 2) {
      return _buildStage2(ble, cal);
    } else {
      return _buildStage3(cal);
    }
  }

  Widget _buildStage1(BleTelemetryProvider ble, CalibrationProvider cal) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.back_hand, size: 80, color: Colors.white54),
          const SizedBox(height: 24),
          const Text(
            'Rest & Zero',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rest your hand flat on the table in a comfortable neutral position. Keep still.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImuGauge('Pitch', ble.latestPacket.pitch, Colors.purpleAccent),
              _buildImuGauge('Roll', ble.latestPacket.roll, Colors.deepPurpleAccent),
              _buildImuGauge('Yaw', ble.latestPacket.yaw, Colors.indigoAccent),
            ],
          ),
          const SizedBox(height: 24),
          
          ...List.generate(3, (index) => _buildLiveBar('Finger ${index + 1} (${ble.latestPacket.flexValues[index].toInt()})', ble.latestPacket.flexValues[index] / 4095.0, Colors.blue)),
          const SizedBox(height: 40),

          if (_isRecording)
            _buildCountdown()
          else
            ElevatedButton(
              onPressed: () => _startRecording(ble, cal, 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text('Start Baseline', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildStage2(BleTelemetryProvider ble, CalibrationProvider cal) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_mma, size: 80, color: Colors.white54),
          const SizedBox(height: 24),
          const Text(
            'Active Flexion',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Slowly close your hand or curl your fingers as far as comfortable. Squeeze gently.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 40),
          
          ...List.generate(3, (index) => _buildLiveBar('Finger ${index + 1} (${ble.latestPacket.flexValues[index].toInt()})', ble.latestPacket.flexValues[index] / 4095.0, Colors.green)),
          const SizedBox(height: 40),

          if (_isRecording)
            _buildCountdown()
          else
            ElevatedButton(
              onPressed: () => _startRecording(ble, cal, 2),
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Text('Start Flexion', style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildStage3(CalibrationProvider cal) {
    bool isValid = true;
    for (int i = 0; i < 3; i++) {
      double delta = cal.calibrationData.flexMax[i] - cal.calibrationData.flexMin[i];
      if (delta < 300) {
        isValid = false;
        break;
      }
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isValid ? Icons.check_circle_outline : Icons.warning_amber_rounded, 
               size: 80, color: isValid ? Colors.green : Colors.orange),
          const SizedBox(height: 24),
          Text(
            isValid ? 'Calibration Successful' : 'Low Movement Detected',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          if (!isValid)
            const Text(
              'Low movement detected on one or more fingers. Check glove fit or adjust sensor alignment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.orangeAccent),
            )
          else
            const Text(
              'Your dynamic range and IMU offsets have been configured successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          const SizedBox(height: 40),
  
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStage = 1;
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Recalibrate'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  cal.saveAndUploadCalibration();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isValid ? DesignTokens.successColor : DesignTokens.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Save & Continue', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildLiveBar(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.white12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImuGauge(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: 80,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              value.toStringAsFixed(1),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: DesignTokens.primaryColor, width: 4),
      ),
      child: Center(
        child: Text(
          '$_countdown',
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    ).animate(key: ValueKey(_countdown)).scale(duration: 200.ms, curve: Curves.easeOutBack);
  }
}
