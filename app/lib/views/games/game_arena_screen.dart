import 'package:flutter/material.dart';
import '../../core/design_tokens.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_telemetry_provider.dart';
import 'dart:math' as math;

import 'piano_game_screen.dart';
import 'cargo_crane_screen.dart';
import 'space_game_screen.dart';

class GameArenaScreen extends StatelessWidget {
  const GameArenaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Arena', style: DesignTokens.headingStyle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: DesignTokens.defaultPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Available Exercises', style: DesignTokens.headingStyle.copyWith(color: DesignTokens.primaryColor)),
              const SizedBox(height: 16),
              _buildGameCard(
                context, 
                'Piano Tiles', 
                'Flexion & Extension Training', 
                Icons.piano,
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PianoGameScreen())),
              ),
              const SizedBox(height: 16),
              _buildGameCard(
                context, 
                'Cargo Crane', 
                'Spatial Pinch Training', 
                Icons.pan_tool, 
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CargoCraneScreen())),
              ),
              const SizedBox(height: 16),
              _buildGameCard(
                context, 
                'AstroShield', 
                'Multi-Sensor Reflex Training', 
                Icons.rocket_launch, 
                () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpaceGameScreen())),
              ),
              
              const SizedBox(height: 40),
              const Text('Live Glove Telemetry (Debug)', style: TextStyle(fontWeight: FontWeight.bold)),
              Consumer<BleTelemetryProvider>(
                builder: (context, ble, child) {
                  if (!ble.isConnected) {
                    return const Text('Connect glove on Home screen to see data');
                  }
                  
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Fingers: ${ble.latestPacket.flexValues.map((v) => v.toStringAsFixed(0)).join(', ')}'),
                        Text('Grip: ${ble.latestPacket.fsrGripPressure.toStringAsFixed(1)}'),
                        Text('Pitch: ${ble.latestPacket.pitch.toStringAsFixed(1)} | Roll: ${ble.latestPacket.roll.toStringAsFixed(1)}'),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGameCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignTokens.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DesignTokens.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: DesignTokens.primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DesignTokens.headingStyle.copyWith(fontSize: 20)),
                    Text(subtitle, style: DesignTokens.bodyStyle.copyWith(color: Colors.grey[700])),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}
