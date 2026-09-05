import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_tokens.dart';
import '../../providers/ble_telemetry_provider.dart';
import '../../providers/calibration_provider.dart';

enum CrateState { idle, grabbed, placed }

class CargoCrate {
  final String id;
  Offset position;
  CrateState state;

  CargoCrate({required this.id, required this.position, this.state = CrateState.idle});
}

class CargoCraneScreen extends StatefulWidget {
  const CargoCraneScreen({super.key});

  @override
  State<CargoCraneScreen> createState() => _CargoCraneScreenState();
}

class _CargoCraneScreenState extends State<CargoCraneScreen> with SingleTickerProviderStateMixin {
  late AnimationController _gameLoop;
  
  // Game State
  int _shields = 3;
  double _flexThreshold = 0.5; // Required flex to grab
  double _transitTimeout = 30.0; // Seconds before timeout
  
  // Crane & Physics
  Offset _cranePosition = const Offset(200, 300);
  final double _craneRadius = 25.0;
  
  // Crates & Zones
  final List<CargoCrate> _crates = [];
  final Rect _pickZone = const Rect.fromLTWH(20, 200, 100, 400);
  final Rect _dropZone = const Rect.fromLTWH(250, 200, 120, 400); // Will scale dynamically
  CargoCrate? _grabbedCrate;
  
  // Health & Failure Timers
  double _overTiltTimer = 0.0;
  double _transitTimer = 0.0;
  
  // Metrics Tracking
  int _cratesPlaced = 0;
  double _totalTransitTime = 0.0;
  int _slipCount = 0;
  double _totalHoldBeforeSlip = 0.0;
  int _totalFrames = 0;
  int _safeFrames = 0;
  
  // Screen bounds
  Size _screenSize = Size.zero;

  // Debug controls
  bool _debugPinch = false;

  @override
  void initState() {
    super.initState();
    _spawnCrates();
    
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 99),
    )..addListener(_updateGame);
    
    _gameLoop.forward();
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    super.dispose();
  }
  
  void _spawnCrates() {
    _crates.clear();
    for (int i = 0; i < 7; i++) {
       _crates.add(CargoCrate(
         id: 'crate_$i',
         position: Offset(_pickZone.center.dx, _pickZone.top + 50 + (i * 50)),
       ));
    }
  }

  void _resetGame({bool gentleTier = false}) {
    if (gentleTier) {
      _flexThreshold *= 0.85; // Lower flex threshold by 15%
      _transitTimeout = 45.0; // Increase transit timer
    }
    
    setState(() {
      _shields = 3;
      _cranePosition = Offset(_screenSize.width / 2, _screenSize.height / 2);
      _grabbedCrate = null;
      _overTiltTimer = 0.0;
      _transitTimer = 0.0;
      
      _cratesPlaced = 0;
      _totalTransitTime = 0.0;
      _slipCount = 0;
      _totalHoldBeforeSlip = 0.0;
      _totalFrames = 0;
      _safeFrames = 0;
      
      _spawnCrates();
      
      _gameLoop.forward();
    });
  }

  void _triggerFailure(String reason) {
    if (_shields <= 0) return; // Game already over
    
    setState(() {
      _shields--;
      if (_grabbedCrate != null) {
        // Respawn the crate
        _grabbedCrate!.state = CrateState.idle;
        _grabbedCrate!.position = Offset(_pickZone.center.dx, _pickZone.center.dy);
        _grabbedCrate = null;
      }
      _transitTimer = 0.0;
      _overTiltTimer = 0.0;
    });
    
    // Haptic/Warning overlay would go here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Warning: $reason', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        duration: const Duration(seconds: 2),
      )
    );
    
    if (_shields <= 0) {
      _showEndOfShiftModal();
    }
  }

  void _showEndOfShiftModal() {
    _gameLoop.stop();
    BuildContext parentContext = context;
    
    final int avgTransit = _cratesPlaced > 0 ? (_totalTransitTime / _cratesPlaced).round() : 0;
    final int avgHoldSlip = _slipCount > 0 ? (_totalHoldBeforeSlip / _slipCount).round() : 0;
    final int stability = _totalFrames > 0 ? ((_safeFrames / _totalFrames) * 100).round() : 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Harbor Shift Concluded', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$_cratesPlaced / 7 Crates Delivered', style: const TextStyle(color: DesignTokens.secondaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Avg Transit Time: ${avgTransit}s', style: const TextStyle(color: Colors.white70)),
            Text('Avg Grip Before Slip: ${avgHoldSlip}s', style: const TextStyle(color: Colors.white70)),
            Text('Wrist Stability Score: $stability%', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Fatigue Warning: Sustained pinch weakened during transit. Recommend a 60-second rest period.', style: TextStyle(color: Colors.orange, fontSize: 13))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
             onPressed: () {
               Navigator.pop(context);
               Navigator.pop(parentContext); // Return to Arena
             }, 
             child: const Text('Return to Arena Hub', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _resetGame(gentleTier: true);
            }, 
            child: const Text('Try on Gentle Tier')
          ),
        ],
      ),
    );
  }

  void _updateGame() {
    if (!mounted || _shields <= 0) return;
    
    final dt = 1.0 / 60.0;
    _totalFrames++;
    
    final bleProvider = context.read<BleTelemetryProvider>();
    final calProvider = context.read<CalibrationProvider>();
    final packet = bleProvider.latestPacket;
    
    // 1. Posture / Ergonomics Check
    bool isOverTilted = packet.pitch.abs() > 45 || packet.roll.abs() > 50;
    if (!isOverTilted) {
       _safeFrames++;
       _overTiltTimer = 0.0; // Reset if posture normalizes
    } else {
       _overTiltTimer += dt;
       if (_overTiltTimer > 2.5) {
          _triggerFailure("Severe ergonomic over-tilt detected!");
          return;
       }
    }
    
    // 2. Crane Movement (Map IMU to screen, or use touch debug)
    // If not using touch drag, we map IMU pitch/roll to movement
    if (!_debugPinch && bleProvider.isConnected) {
       // Pitch (up/down) -> Y axis. Roll (left/right) -> X axis.
       double dx = packet.roll * 5.0 * dt; 
       double dy = -packet.pitch * 5.0 * dt; // Invert pitch usually
       
       _cranePosition = Offset(
         (_cranePosition.dx + dx).clamp(0.0, _screenSize.width),
         (_cranePosition.dy + dy).clamp(0.0, _screenSize.height)
       );
    }
    
    // 3. Pinch Input (Index finger flex)
    // Defaulting to flex sensor 0 (Thumb/Index). Can also use FSR.
    double rawFlex = packet.flexValues[0];
    double flexNormalized = calProvider.normalizeFlexValue(0, rawFlex);
    
    bool isPinching = flexNormalized >= _flexThreshold || _debugPinch;
    
    // 4. Object Interaction Logic
    if (_grabbedCrate == null) {
      // Trying to grab
      if (isPinching) {
        // Find closest idle crate
        for (var crate in _crates) {
           if (crate.state == CrateState.idle) {
              double distance = (crate.position - _cranePosition).distance;
              if (distance < _craneRadius + 20) {
                 _grabbedCrate = crate;
                 crate.state = CrateState.grabbed;
                 _transitTimer = 0.0;
                 break;
              }
           }
        }
      }
    } else {
      // Holding a crate
      _grabbedCrate!.position = _cranePosition;
      _transitTimer += dt;
      
      // Dynamic drop zone bounds based on screen size
      final dynamicDropZone = Rect.fromLTWH(
        _screenSize.width - 150, 
        _screenSize.height * 0.2, 
        130, 
        _screenSize.height * 0.6
      );
      
      if (!isPinching) {
         // Dropped it
         if (dynamicDropZone.contains(_cranePosition)) {
            // Success
            _grabbedCrate!.state = CrateState.placed;
            _cratesPlaced++;
            _totalTransitTime += _transitTimer;
            _grabbedCrate = null;
            _transitTimer = 0.0;
            
            // Check win condition
            if (_cratesPlaced == 7) {
               _showEndOfShiftModal();
            }
         } else {
            // Mid-Transit Drop Failure
            _slipCount++;
            _totalHoldBeforeSlip += _transitTimer;
            _triggerFailure("Grip slipped during transit!");
         }
      } else if (_transitTimer > _transitTimeout) {
         // Transport Timeout Failure
         _triggerFailure("Transport timeout! Move faster.");
      }
    }
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    
    final dynamicDropZone = Rect.fromLTWH(
      _screenSize.width - 150, 
      _screenSize.height * 0.2, 
      130, 
      _screenSize.height * 0.6
    );
    
    final dynamicPickZone = Rect.fromLTWH(
      20, 
      _screenSize.height * 0.2, 
      130, 
      _screenSize.height * 0.6
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Harbor aesthetic
      appBar: AppBar(
        title: const Text('Cargo Crane', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Cargo Shields
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: List.generate(3, (index) {
                return Icon(
                  Icons.shield, 
                  color: index < _shields ? DesignTokens.secondaryColor : Colors.grey.withOpacity(0.3),
                  size: 28,
                );
              }),
            ),
          )
        ],
      ),
      body: GestureDetector(
        onPanDown: (details) {
          setState(() {
            _cranePosition = details.localPosition;
            _debugPinch = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _cranePosition = details.localPosition;
            _debugPinch = true;
          });
        },
        onPanEnd: (_) => setState(() => _debugPinch = false),
        onPanCancel: () => setState(() => _debugPinch = false),
        onTapDown: (details) {
          setState(() {
            _cranePosition = details.localPosition;
            _debugPinch = true;
          });
        },
        onTapUp: (_) => setState(() => _debugPinch = false),
        onTapCancel: () => setState(() => _debugPinch = false),
        child: Stack(
          children: [
            // Background / Water / Concrete
            Container(color: const Color(0xFF1E293B)),
            
            // Pick Zone
            Positioned.fromRect(
              rect: dynamicPickZone,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 3),
                  color: Colors.blueAccent.withOpacity(0.1),
                ),
                child: const Center(child: RotatedBox(quarterTurns: 3, child: Text('PICK ZONE', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, letterSpacing: 5)))),
              ),
            ),
            
            // Drop Zone
            Positioned.fromRect(
              rect: dynamicDropZone,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: DesignTokens.secondaryColor.withOpacity(0.5), width: 3),
                  color: DesignTokens.secondaryColor.withOpacity(0.1),
                ),
                child: const Center(child: RotatedBox(quarterTurns: 1, child: Text('DROP BIN', style: TextStyle(color: DesignTokens.secondaryColor, fontWeight: FontWeight.bold, letterSpacing: 5)))),
              ),
            ),
            
            // Game Elements (Painter)
            CustomPaint(
              painter: CargoCranePainter(
                crates: _crates,
                cranePosition: _cranePosition,
                craneRadius: _craneRadius,
                isPinching: _debugPinch || (context.read<BleTelemetryProvider>().latestPacket.flexValues[0] >= _flexThreshold),
              ),
              child: Container(), // Fills screen
            ),
            
            // HUD / Over-tilt warning overlay
            if (_overTiltTimer > 0)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'POSTURE WARNING: NORMALISE WRIST (${(2.5 - _overTiltTimer).toStringAsFixed(1)}s)', 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ),
              
            // Debug Text
            const Positioned(
              bottom: 20,
              left: 20,
              child: Text('Tap/Drag to emulate Crane + Pinch', style: TextStyle(color: Colors.white30)),
            )
          ],
        ),
      ),
    );
  }
}

class CargoCranePainter extends CustomPainter {
  final List<CargoCrate> crates;
  final Offset cranePosition;
  final double craneRadius;
  final bool isPinching;

  CargoCranePainter({
    required this.crates, 
    required this.cranePosition,
    required this.craneRadius,
    required this.isPinching,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Crates
    final Paint cratePaint = Paint()..color = Colors.orange[300]!;
    final Paint cratePlacedPaint = Paint()..color = DesignTokens.secondaryColor.withOpacity(0.5);
    final Paint crateBorder = Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 2;
    
    for (var crate in crates) {
      if (crate.state == CrateState.placed) {
         canvas.drawRect(Rect.fromCenter(center: crate.position, width: 40, height: 40), cratePlacedPaint);
      } else {
         canvas.drawRect(Rect.fromCenter(center: crate.position, width: 40, height: 40), cratePaint);
         canvas.drawRect(Rect.fromCenter(center: crate.position, width: 40, height: 40), crateBorder);
         
         // Wood crate lines
         canvas.drawLine(crate.position + const Offset(-15, -15), crate.position + const Offset(15, 15), crateBorder);
         canvas.drawLine(crate.position + const Offset(15, -15), crate.position + const Offset(-15, 15), crateBorder);
      }
    }
    
    // 2. Draw Crane Cable (from top of screen)
    final Paint cablePaint = Paint()..color = Colors.grey[700]!..strokeWidth = 4;
    canvas.drawLine(Offset(cranePosition.dx, -50), cranePosition, cablePaint);

    // 3. Draw Crane Claw
    final Paint clawPaint = Paint()
      ..color = isPinching ? DesignTokens.primaryColor : Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
      
    // A simple claw visualization (open/closed)
    canvas.drawCircle(cranePosition, craneRadius, Paint()..color = Colors.black87); // Center hub
    
    double clawSpread = isPinching ? 10.0 : 25.0;
    
    // Left claw
    canvas.drawLine(cranePosition, cranePosition + Offset(-clawSpread, 20), clawPaint);
    canvas.drawLine(cranePosition + Offset(-clawSpread, 20), cranePosition + Offset(-clawSpread, 35), clawPaint);
    
    // Right claw
    canvas.drawLine(cranePosition, cranePosition + Offset(clawSpread, 20), clawPaint);
    canvas.drawLine(cranePosition + Offset(clawSpread, 20), cranePosition + Offset(clawSpread, 35), clawPaint);
  }

  @override
  bool shouldRepaint(covariant CargoCranePainter oldDelegate) => true;
}
