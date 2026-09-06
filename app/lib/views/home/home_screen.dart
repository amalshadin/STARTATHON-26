import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_tokens.dart';
import '../../providers/ble_telemetry_provider.dart';
import '../../providers/calibration_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'widgets/ble_connect_modal.dart';
import '../calibration/calibration_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The HapticSync', style: DesignTokens.headingStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: DesignTokens.defaultPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Calibration Banner
              Consumer<CalibrationProvider>(
                builder: (context, cal, child) {
                  if (cal.isCalibrated) return const SizedBox.shrink();
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationScreen()));
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Device Not Calibrated', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                Text('Complete initial calibration to start therapy.', style: TextStyle(color: Colors.orange[800], fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.orange),
                        ],
                      ),
                    ).animate().slideY(begin: -0.2, end: 0).fadeIn(),
                  );
                },
              ),
              
              // BLE Connection Pill
              Consumer<BleTelemetryProvider>(
                builder: (context, ble, child) {
                  return Card(
                    color: ble.isConnected ? DesignTokens.successColor.withOpacity(0.1) : DesignTokens.errorColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.borderRadiusLarge)),
                    child: ListTile(
                      leading: Icon(
                        ble.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                        color: ble.isConnected ? DesignTokens.successColor : DesignTokens.errorColor,
                        size: 32,
                      ),
                      title: Text(
                        ble.isConnected ? 'Glove Connected' : 'Glove Disconnected',
                        style: DesignTokens.bodyStyle.copyWith(fontWeight: FontWeight.bold),
                      ),
                      trailing: Switch(
                        value: ble.isConnected,
                        onChanged: (val) {
                          if (val) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const BleConnectModal(),
                            );
                          } else {
                            ble.disconnect();
                          }
                        },
                      ),
                    ),
                  ).animate(target: ble.isConnected ? 1 : 0).shimmer(duration: 1000.ms);
                },
              ),
              const SizedBox(height: 24),
              
              const SizedBox(height: 40),
              
              Icon(
                Icons.health_and_safety_rounded, 
                size: 80, 
                color: DesignTokens.primaryColor.withValues(alpha: 0.5)
              ),
              const SizedBox(height: 16),
              Text(
                'Ready for Therapy?', 
                textAlign: TextAlign.center,
                style: DesignTokens.headingStyle.copyWith(color: Colors.grey)
              ),
              const SizedBox(height: 8),
              Text(
                'Connect your glove and press Quick Start below.', 
                textAlign: TextAlign.center, 
                style: DesignTokens.bodyStyle.copyWith(color: Colors.grey)
              ),
              
              const SizedBox(height: 40),
              
              // Quick Start Card
              Consumer<CalibrationProvider>(
                builder: (context, cal, child) {
                  return ElevatedButton.icon(
                    onPressed: () {
                      if (!cal.isCalibrated) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalibrationScreen()));
                      } else {
                        // TODO: Route to games arena or quick start logic
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 32),
                    label: Text(cal.isCalibrated ? 'Quick Start Workout' : 'Calibrate Glove', style: DesignTokens.headingStyle),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DesignTokens.secondaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ).animate().slideY(begin: 1.0, end: 0.0, curve: Curves.easeOut, duration: 500.ms);
                },
              ),
              const SizedBox(height: 80), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }
}
