import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/sensor_packet.dart';
import '../services/ble_service.dart';

class BleTelemetryProvider extends ChangeNotifier {
  bool _isConnected = false;
  SensorPacket _latestPacket = SensorPacket.empty();
  Timer? _mockTimer;
  final Random _random = Random();
  String? _lastError;
  bool _isConnecting = false;
  bool _isScanning = false;
  StreamSubscription? _sensorSub;
  StreamSubscription? _connSub;
  StreamSubscription? _scanSub;
  
  List<ScanResult> _scanResults = [];
  List<ScanResult> get scanResults => _scanResults;

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isScanning => _isScanning;
  SensorPacket get latestPacket => _latestPacket;
  String? get lastError => _lastError;

  // Original mock connect for dev fallback
  void connectMock() {
    _isConnected = true;
    _lastError = null;
    notifyListeners();
    _startMockStream();
  }

  Future<void> startScan() async {
    _lastError = null;
    _scanResults = [];
    _isScanning = true;
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = BleService().scanResults.listen((results) {
      // Filter out empty named devices to keep UI clean
      _scanResults = results.where((r) => 
        r.device.platformName.isNotEmpty || r.advertisementData.advName.isNotEmpty
      ).toList();
      notifyListeners();
    });

    BleService().isScanning.listen((scanning) {
      if (_isScanning != scanning) {
        _isScanning = scanning;
        notifyListeners();
      }
    });

    await BleService().startScan(onError: (err) {
      _lastError = err;
      _isScanning = false;
      notifyListeners();
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    _lastError = null;
    _isConnecting = true;
    _isScanning = false;
    notifyListeners();
    
    // Stop mock if running
    _mockTimer?.cancel();
    
    _setupBleListeners();
    
    await BleService().connectToDevice(device, onError: (err) {
      _lastError = err;
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    });
  }

  void _setupBleListeners() {
    _connSub?.cancel();
    _sensorSub?.cancel();

    _connSub = BleService().connectionStateStream.listen((state) {
      bool isNowConnected = state == BluetoothConnectionState.connected;
      if (_isConnected != isNowConnected) {
        _isConnected = isNowConnected;
        if (!_isConnected) {
          _latestPacket = SensorPacket.empty();
        }
      }
      // If we connect or disconnect, we are no longer "connecting"
      _isConnecting = false;
      notifyListeners();
    });

    _sensorSub = BleService().sensorStream.listen((rawJson) {
      processBleJson(rawJson);
    });
  }

  void processBleJson(String rawJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson);
      
      List<double> flexAngles = [0.0, 0.0, 0.0, 0.0, 0.0];
      if (data.containsKey('f') && data['f'] is List) {
        final List<dynamic> fList = data['f'];
        for (int i = 0; i < fList.length && i < 3; i++) {
          flexAngles[i] = (fList[i] as num).toDouble();
        }
      }

      double pitch = (data['x'] ?? data['pitch'] ?? 0.0).toDouble();
      double roll = (data['y'] ?? data['roll'] ?? 0.0).toDouble();
      double yaw = (data['z'] ?? data['yaw'] ?? 0.0).toDouble();

      _latestPacket = SensorPacket(
        timestamp: DateTime.now(),
        flexValues: flexAngles,
        fsrGripPressure: 0.0,
        pitch: pitch,
        roll: roll,
        yaw: yaw,
      );
      
      // Enforce switching off the mock timer once live data flows
      _mockTimer?.cancel();
      
      notifyListeners();
    } catch (e) {
      // Silently discard malformed JSON frames
    }
  }

  void disconnect() {
    BleService().disconnect();
    _connSub?.cancel();
    _sensorSub?.cancel();
    _scanSub?.cancel();
    _isConnected = false;
    _isConnecting = false;
    _isScanning = false;
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
    _connSub?.cancel();
    _sensorSub?.cancel();
    BleService().disconnect();
    super.dispose();
  }
}
