import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../../../core/design_tokens.dart';
import '../../../providers/ble_telemetry_provider.dart';

class BleConnectModal extends StatelessWidget {
  const BleConnectModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Consumer<BleTelemetryProvider>(
          builder: (context, ble, child) {
            if (ble.isConnected) {
              return _buildConnectedState(context);
            }
            return _buildConnectState(context, ble);
          },
        ),
      ),
    );
  }

  Widget _buildConnectState(BuildContext context, BleTelemetryProvider ble) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 24),
        const Icon(Icons.bluetooth_searching, size: 64, color: DesignTokens.primaryColor)
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(duration: 2000.ms)
            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1000.ms, curve: Curves.easeInOut),
        const SizedBox(height: 24),
        const Text('Connect Smart Glove', style: DesignTokens.headingStyle),
        const SizedBox(height: 8),
        Text('Turn on your ESP32 HapticSync glove and tap connect.',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyStyle.copyWith(color: Colors.grey[600])),
        if (ble.lastError != null) ...[
          const SizedBox(height: 16),
          Text(ble.lastError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesignTokens.errorColor, fontWeight: FontWeight.bold)),
        ],
        const SizedBox(height: 16),
        // Scan Results List
        if (ble.scanResults.isNotEmpty)
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: ble.scanResults.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final r = ble.scanResults[index];
                final name = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
                return ListTile(
                  title: Text(name.isNotEmpty ? name : 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(r.device.remoteId.toString(), style: const TextStyle(fontSize: 12)),
                  trailing: ble.isConnecting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : ElevatedButton(
                          onPressed: () => ble.connectToDevice(r.device),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DesignTokens.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Connect'),
                        ),
                );
              },
            ),
          ),
        
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: ble.isScanning || ble.isConnecting ? null : () {
              ble.startScan();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: ble.isScanning
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : const Text('Scan for Devices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => ble.connectMock(), // Dev mock fallback
          child: const Text('Use Mock Data Simulator', style: TextStyle(color: Colors.grey)),
        )
      ],
    );
  }

  Widget _buildConnectedState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.bluetooth_connected, size: 64, color: DesignTokens.successColor)
            .animate().scale(curve: Curves.elasticOut),
        const SizedBox(height: 24),
        const Text('Glove Connected!', style: DesignTokens.headingStyle),
        const SizedBox(height: 8),
        const Text('Your hardware is actively streaming data.',
            textAlign: TextAlign.center,
            style: DesignTokens.bodyStyle),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Continue to Therapy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
