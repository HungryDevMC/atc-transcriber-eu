import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/audio_source.dart';
import '../../core/providers/providers.dart';
import '../../core/services/bluetooth_service.dart';
import '../../shared/theme/app_theme.dart';

class BluetoothScreen extends ConsumerStatefulWidget {
  const BluetoothScreen({super.key});

  @override
  ConsumerState<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends ConsumerState<BluetoothScreen> {
  List<AudioSource> _devices = [];
  AudioSource? _connectedDevice;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    final bluetoothService = ref.read(bluetoothServiceProvider);

    bluetoothService.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });

    bluetoothService.connectedDeviceStream.listen((device) {
      if (mounted) setState(() => _connectedDevice = device);
    });

    bluetoothService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isScanning = state == BluetoothConnectionState.scanning;
        });
      }
    });
  }

  Future<void> _startScan() async {
    try {
      await ref.read(bluetoothServiceProvider).startScan();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $e')),
        );
      }
    }
  }

  Future<void> _connect(AudioSource device) async {
    try {
      await ref.read(bluetoothServiceProvider).connect(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await ref.read(bluetoothServiceProvider).disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final btState = ref.watch(bluetoothStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Audio'),
        actions: [
          if (!_isScanning)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScan,
            ),
        ],
      ),
      body: btState.when(
        data: (state) => _buildContent(state),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.unavailable) {
      return _buildUnavailableView();
    }

    if (state == BluetoothConnectionState.disabled) {
      return _buildDisabledView();
    }

    return Column(
      children: [
        if (_connectedDevice != null) _buildConnectedDevice(),
        if (_isScanning) _buildScanningIndicator(),
        Expanded(child: _buildDeviceList()),
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildUnavailableView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Bluetooth not available',
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'This device does not support Bluetooth',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text(
            'Bluetooth is disabled',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please enable Bluetooth in your device settings',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Platform-specific: open Bluetooth settings
            },
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDevice() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.connectedColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.connectedColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.bluetooth_connected, color: AppTheme.connectedColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectedDevice!.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Connected',
                  style: TextStyle(
                    color: AppTheme.connectedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _disconnect,
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Scanning for devices...'),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty && !_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No devices found',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.search),
              label: const Text('Start Scan'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        final isConnected = _connectedDevice?.id == device.id;

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.bluetooth,
              color: isConnected ? AppTheme.connectedColor : null,
            ),
            title: Text(device.name),
            subtitle: Text(
              device.id,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isConnected
                ? const Icon(Icons.check_circle, color: AppTheme.connectedColor)
                : TextButton(
                    onPressed: () => _connect(device),
                    child: const Text('Connect'),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: Colors.grey),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Connect to your ATC radio audio interface to receive transmissions.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
