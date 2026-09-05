import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  BluetoothDevice? _connectedDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _characteristicSubscription;

  final _sensorStreamController = StreamController<String>.broadcast();
  Stream<String> get sensorStream => _sensorStreamController.stream;

  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _connectedDevice != null && _connectedDevice!.isConnected;
  
  String get _targetServiceUuid => dotenv.env['BLE_SERVICE_UUID'] ?? '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  String get _targetCharacteristicUuid => dotenv.env['BLE_CHARACTERISTIC_UUID'] ?? 'beb5483e-36e1-4688-b7f5-ea07361b26a8';

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = true;
    for (var status in statuses.values) {
      if (!status.isGranted) {
        allGranted = false;
      }
    }
    return allGranted;
  }

  Future<void> startScan({Function(String)? onError}) async {
    try {
      bool hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        onError?.call('Bluetooth or Location permissions denied.');
        return;
      }

      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        onError?.call('Bluetooth is turned off.');
        return;
      }

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      onError?.call('Error scanning for devices: $e');
    }
  }

  Future<void> connectToDevice(BluetoothDevice device, {Function(String)? onError}) async {
    try {
      await FlutterBluePlus.stopScan();
      _connectedDevice = device;
      
      _connectionStateSubscription = device.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _cleanUp();
        }
      });

      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));
      
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(256);
        } catch (e) {
          debugPrint('MTU request failed: $e');
        }
      }
      
      await discoverAndSubscribe(onError: onError);
    } catch (e) {
      onError?.call('Failed to connect: $e');
      _cleanUp();
    }
  }

  Future<void> discoverAndSubscribe({Function(String)? onError}) async {
    if (_connectedDevice == null) return;
    
    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      
      BluetoothCharacteristic? targetCharacteristic;
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == _targetServiceUuid.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == _targetCharacteristicUuid.toLowerCase()) {
              targetCharacteristic = characteristic;
              break;
            }
          }
        }
      }

      if (targetCharacteristic != null) {
        await targetCharacteristic.setNotifyValue(true);
        String _buffer = '';
        _characteristicSubscription = targetCharacteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            final decodedString = utf8.decode(value, allowMalformed: true);
            _buffer += decodedString;
            if (_buffer.contains('\n')) {
              final lines = _buffer.split('\n');
              for (int i = 0; i < lines.length - 1; i++) {
                if (lines[i].trim().isNotEmpty) {
                  _sensorStreamController.add(lines[i].trim());
                }
              }
              _buffer = lines.last;
            }
          }
        });
      } else {
        onError?.call('Target characteristic not found. Please check UUIDs.');
        await disconnect();
      }
    } catch (e) {
      onError?.call('Error discovering services: $e');
      await disconnect();
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }
    _cleanUp();
  }

  void _cleanUp() {
    _characteristicSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _connectedDevice = null;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
  }
}
