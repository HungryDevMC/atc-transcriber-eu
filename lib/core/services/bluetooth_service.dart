import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/audio_source.dart';

enum BluetoothConnectionState {
  unavailable,
  disabled,
  scanning,
  idle,
  connecting,
  connected,
  disconnected,
}

/// Service for managing Bluetooth connection to ATC radio hardware
class BluetoothService {
  final _stateController =
      StreamController<BluetoothConnectionState>.broadcast();
  final _devicesController = StreamController<List<AudioSource>>.broadcast();
  final _connectedDeviceController = StreamController<AudioSource?>.broadcast();

  BluetoothConnectionState _state = BluetoothConnectionState.idle;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;

  final List<AudioSource> _discoveredDevices = [];

  Stream<BluetoothConnectionState> get stateStream => _stateController.stream;
  Stream<List<AudioSource>> get devicesStream => _devicesController.stream;
  Stream<AudioSource?> get connectedDeviceStream =>
      _connectedDeviceController.stream;
  BluetoothConnectionState get state => _state;

  /// Initialize and check Bluetooth availability
  Future<void> initialize() async {
    // Check if Bluetooth is supported
    if (!await FlutterBluePlus.isSupported) {
      _setState(BluetoothConnectionState.unavailable);
      return;
    }

    // Listen to adapter state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        _setState(BluetoothConnectionState.disabled);
      } else if (state == BluetoothAdapterState.on) {
        if (_state == BluetoothConnectionState.disabled) {
          _setState(BluetoothConnectionState.idle);
        }
      }
    });

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState == BluetoothAdapterState.off) {
      _setState(BluetoothConnectionState.disabled);
    } else {
      _setState(BluetoothConnectionState.idle);
    }
  }

  /// Start scanning for Bluetooth audio devices
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (_state == BluetoothConnectionState.unavailable ||
        _state == BluetoothConnectionState.disabled) {
      throw Exception('Bluetooth not available');
    }

    _discoveredDevices.clear();
    _setState(BluetoothConnectionState.scanning);

    try {
      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: timeout,
        // Filter for audio devices if possible
        // withServices: [Guid('0000110b-0000-1000-8000-00805f9b34fb')], // A2DP
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          // Only add devices with names (likely legitimate devices)
          if (result.device.platformName.isNotEmpty) {
            final audioSource = AudioSource(
              id: result.device.remoteId.str,
              name: result.device.platformName,
              type: AudioSourceType.bluetooth,
              isConnected: false,
            );

            // Avoid duplicates
            if (!_discoveredDevices.any((d) => d.id == audioSource.id)) {
              _discoveredDevices.add(audioSource);
              _devicesController.add(List.from(_discoveredDevices));
            }
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(timeout);
      await stopScan();
    } catch (e) {
      debugPrint('Scan error: $e');
      _setState(BluetoothConnectionState.idle);
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    if (_state == BluetoothConnectionState.scanning) {
      _setState(BluetoothConnectionState.idle);
    }
  }

  /// Connect to a Bluetooth device
  Future<void> connect(AudioSource device) async {
    if (_state == BluetoothConnectionState.unavailable ||
        _state == BluetoothConnectionState.disabled) {
      throw Exception('Bluetooth not available');
    }

    _setState(BluetoothConnectionState.connecting);

    try {
      final btDevice = BluetoothDevice.fromId(device.id);
      await btDevice.connect(timeout: const Duration(seconds: 15));

      _connectedDevice = btDevice;

      // Listen for disconnection
      _connectionSubscription = btDevice.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      final connectedSource = device.copyWith(isConnected: true);
      _connectedDeviceController.add(connectedSource);
      _setState(BluetoothConnectionState.connected);
    } catch (e) {
      debugPrint('Connection error: $e');
      _setState(BluetoothConnectionState.idle);
      rethrow;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_connectedDevice == null) return;

    try {
      await _connectedDevice!.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }

    _handleDisconnection();
  }

  void _handleDisconnection() {
    _connectedDevice = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDeviceController.add(null);
    _setState(BluetoothConnectionState.disconnected);
  }

  void _setState(BluetoothConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Clean up resources
  Future<void> dispose() async {
    await stopScan();
    await disconnect();
    await _stateController.close();
    await _devicesController.close();
    await _connectedDeviceController.close();
  }
}
