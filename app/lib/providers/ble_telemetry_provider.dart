import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/sensor_packet.dart';

class BleTelemetryProvider extends ChangeNotifier {
  bool _isConnected = false;
  SensorPacket _latestPacket = SensorPacket.empty();
  Timer? _mockTimer;
  final Random _random = Random();

  bool get isConnected => _isConnected;
  SensorPacket get latestPacket => _latestPacket;

  void connect() {
    _isConnected = true;
    notifyListeners();
    _startMockStream();
  }

  void disconnect() {
    _isConnected = false;
    _mockTimer?.cancel();
    _latestPacket = SensorPacket.empty();
    notifyListeners();
  }

  void _startMockStream() {
    _mockTimer?.cancel();
    // 20Hz means 50ms per tick
    _mockTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      
      // Generate some somewhat smooth random values
      final flexValues = List.generate(5, (index) {
        double previous = _latestPacket.flexValues[index];
        // Add random walk bounded between 0 and 1023
        double next = previous + (_random.nextDouble() * 20 - 10);
        return next.clamp(0.0, 1023.0);
      });

      _latestPacket = SensorPacket(
        timestamp: DateTime.now(),
        flexValues: flexValues,
        fsrGripPressure: _latestPacket.fsrGripPressure + (_random.nextDouble() * 10 - 5).clamp(0.0, 1023.0),
        pitch: (_random.nextDouble() * 180 - 90),
        roll: (_random.nextDouble() * 180 - 90),
        yaw: (_random.nextDouble() * 360 - 180),
      );
      
      notifyListeners();
    });
  }
  
  @override
  void dispose() {
    _mockTimer?.cancel();
    super.dispose();
  }
}
