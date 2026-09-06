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

    _sensorSub = BleService().sensorStream.listen((bytes) {
      processBleBytes(bytes);
    });
  }

  void processBleBytes(List<int> bytes) {
    if (bytes.isEmpty) return;

    try {
      // Attempt to parse as comma-separated string first
      String str = String.fromCharCodes(bytes).replaceAll('\x00', '').trim();
      if (str.contains(',') && RegExp(r'^[0-9\., \-]+$').hasMatch(str)) {
        List<String> parts = str.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        if (parts.length >= 3) {
          double flex1 = double.tryParse(parts[0]) ?? 0;
          double flex2 = double.tryParse(parts[1]) ?? 0;
          double flex3 = double.tryParse(parts[2]) ?? 0;
          
          double pitch = parts.length > 3 ? (double.tryParse(parts[3]) ?? 0) : 0;
          double roll = parts.length > 4 ? (double.tryParse(parts[4]) ?? 0) : 0;
          double yaw = parts.length > 5 ? (double.tryParse(parts[5]) ?? 0) : 0;

          _latestPacket = SensorPacket(
            timestamp: DateTime.now(),
            flexValues: [flex1, flex2, flex3, 0.0, 0.0],
            fsrGripPressure: 0.0,
            pitch: pitch,
            roll: roll,
            yaw: yaw,
          );
          _mockTimer?.cancel();
          _lastError = null;
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      // Fallback to binary parsing
    }

    if (bytes.length < 20) {
      // Incomplete packet
      return;
    }

    try {
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      
      // MPU data is sent first (14 bytes)
      int accX = byteData.getInt16(0, Endian.little);
      int accY = byteData.getInt16(2, Endian.little);
      int accZ = byteData.getInt16(4, Endian.little);
      int tempRaw = byteData.getInt16(6, Endian.little);
      int gyroX = byteData.getInt16(8, Endian.little);
      int gyroY = byteData.getInt16(10, Endian.little);
      int gyroZ = byteData.getInt16(12, Endian.little);

      // FlexData is sent second (6 bytes)
      int flex1 = byteData.getUint16(14, Endian.little);
      int flex2 = byteData.getUint16(16, Endian.little);
      int flex3 = byteData.getUint16(18, Endian.little);

      List<double> flexAngles = [flex1.toDouble(), flex2.toDouble(), flex3.toDouble(), 0.0, 0.0];

      double pitch = accX.toDouble();
      double roll = accY.toDouble();
      double yaw = gyroZ.toDouble();

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
      _lastError = null; // Clear any previous errors on success
      notifyListeners();
    } catch (e) {
      _lastError = 'Binary parse error. Check struct packing.';
      notifyListeners();
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
