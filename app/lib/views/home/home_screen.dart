import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_tokens.dart';
import '../../providers/ble_telemetry_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
        child: Padding(
          padding: DesignTokens.defaultPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                            ble.connect();
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
              
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.health_and_safety_rounded, 
                        size: 80, 
                        color: DesignTokens.primaryColor.withValues(alpha: 0.5)
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Ready for Therapy?', 
                        style: DesignTokens.headingStyle.copyWith(color: Colors.grey)
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect your glove and press Quick Start below.', 
                        textAlign: TextAlign.center, 
                        style: DesignTokens.bodyStyle.copyWith(color: Colors.grey)
                      ),
                    ],
                  ),
                ),
              ),
              
              // Quick Start Card
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow_rounded, size: 32),
                label: const Text('Quick Start Workout', style: DesignTokens.headingStyle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ).animate().slideY(begin: 1.0, end: 0.0, curve: Curves.easeOut, duration: 500.ms),
              const SizedBox(height: 80), // Space for bottom nav
            ],
          ),
        ),
      ),
    );
  }
}
