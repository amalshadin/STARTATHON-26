import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_tokens.dart';
import '../../providers/ble_telemetry_provider.dart';
import '../../providers/calibration_provider.dart';

enum EntityType { drone, fuelCore, empWave }

class SpaceEntity {
  final String id;
  final EntityType type;
  Offset position;
  bool isDestroyed = false;
  
  // Specific to Fuel Core
  double tractorProgress = 0.0;
  bool isBeingTractored = false;

  SpaceEntity({required this.id, required this.type, required this.position});
}

class SpaceGameScreen extends StatefulWidget {
  const SpaceGameScreen({super.key});

  @override
  State<SpaceGameScreen> createState() => _SpaceGameScreenState();
}

class _SpaceGameScreenState extends State<SpaceGameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _gameLoop;
  final Random _random = Random();
  
  // State
  double _hullIntegrity = 1.0; // 100%
  double _flexThreshold = 0.5;
  
  // Ship
  Offset _shipPosition = const Offset(200, 500);
  final double _shipRadius = 30.0;
  
  // Weapons & Abilities
  double _laserCooldown = 0.0;
  bool _isShieldActive = false;
  bool _isTractorActive = false;
  
  // Entities
  final List<SpaceEntity> _entities = [];
  double _lastSpawnTime = 0.0;
  
  // Metrics
  int _dronesDestroyed = 0;
  int _dronesMissed = 0;
  int _coresHarvested = 0;
  int _shieldSuccesses = 0;
  int _shieldFailures = 0;
  
  // Smoothness tracking
  double _totalPitchRollDelta = 0.0;
  int _framesWithMovement = 0;
  double _lastPitch = 0.0;
  double _lastRoll = 0.0;
  
  Size _screenSize = Size.zero;
  
  // Debug Inputs
  bool _debugLaser = false;
  bool _debugTractor = false;
  bool _debugShield = false;

  @override
  void initState() {
    super.initState();
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

  void _resetGame({bool gentleTier = false}) {
    if (gentleTier) {
       _flexThreshold = max(0.2, _flexThreshold * 0.85);
    }
    
    setState(() {
      _hullIntegrity = 1.0;
      _entities.clear();
      _shipPosition = Offset(_screenSize.width / 2, _screenSize.height * 0.8);
      
      _dronesDestroyed = 0;
      _dronesMissed = 0;
      _coresHarvested = 0;
      _shieldSuccesses = 0;
      _shieldFailures = 0;
      _totalPitchRollDelta = 0.0;
      _framesWithMovement = 0;
      
      _gameLoop.forward();
    });
  }

  void _updateGame() {
    if (!mounted || _hullIntegrity <= 0) return;
    
    final dt = 1.0 / 60.0;
    final bleProvider = context.read<BleTelemetryProvider>();
    final calProvider = context.read<CalibrationProvider>();
    final packet = bleProvider.latestPacket;
    
    // 1. Steering & Smoothness Tracking
    if (bleProvider.isConnected) {
       double dx = packet.roll * 6.0 * dt; 
       double dy = -packet.pitch * 6.0 * dt;
       
       _shipPosition = Offset(
         (_shipPosition.dx + dx).clamp(0.0, _screenSize.width),
         (_shipPosition.dy + dy).clamp(0.0, _screenSize.height)
       );
       
       double deltaP = (packet.pitch - _lastPitch).abs();
       double deltaR = (packet.roll - _lastRoll).abs();
       if (deltaP > 0.1 || deltaR > 0.1) {
          _totalPitchRollDelta += (deltaP + deltaR);
          _framesWithMovement++;
       }
       _lastPitch = packet.pitch;
       _lastRoll = packet.roll;
    }
    
    // 2. Read Inputs (Hardware or Debug)
    bool fireLaser = _debugLaser || (calProvider.normalizeFlexValue(0, packet.flexValues[0]) >= _flexThreshold);
    bool useTractor = _debugTractor || (calProvider.normalizeFlexValue(1, packet.flexValues[1]) >= _flexThreshold);
    bool useShield = _debugShield || (calProvider.normalizeFlexValue(2, packet.flexValues[2]) >= _flexThreshold);
    
    _isShieldActive = useShield;
    _isTractorActive = useTractor;
    
    if (_laserCooldown > 0) _laserCooldown -= dt;
    
    // 3. Spawning
    _lastSpawnTime += dt;
    if (_lastSpawnTime > 3.0) { // Spawn every 3 seconds
       _lastSpawnTime = 0.0;
       double randX = 30 + _random.nextDouble() * (_screenSize.width - 60);
       
       int roll = _random.nextInt(100);
       EntityType type;
       if (roll < 60) type = EntityType.drone; // 60% Drone
       else if (roll < 85) type = EntityType.fuelCore; // 25% Core
       else type = EntityType.empWave; // 15% EMP
       
       _entities.add(SpaceEntity(id: DateTime.now().toString(), type: type, position: Offset(randX, -50)));
    }
    
    // 4. Update Entities & Collision
    bool laserFiredThisFrame = false;
    if (fireLaser && _laserCooldown <= 0) {
       laserFiredThisFrame = true;
       _laserCooldown = 0.8; // Debounce
    }
    
    for (int i = 0; i < _entities.length; i++) {
       var entity = _entities[i];
       if (entity.isDestroyed) continue;
       
       // Move down
       double speed = entity.type == EntityType.empWave ? 150.0 : 100.0;
       
       if (entity.type == EntityType.fuelCore && entity.isBeingTractored) {
          // Lock onto ship slightly but don't fall as fast
          entity.position = Offset(
            entity.position.dx + (_shipPosition.dx - entity.position.dx) * 2.0 * dt,
            entity.position.dy + 20.0 * dt
          );
       } else {
          entity.position += Offset(0, speed * dt);
       }
       
       // Missed bounds
       if (entity.position.dy > _screenSize.height + 100) {
          entity.isDestroyed = true;
          if (entity.type == EntityType.drone) _dronesMissed++;
          continue;
       }
       
       // Interactions
       double dist = (entity.position - _shipPosition).distance;
       
       if (entity.type == EntityType.drone) {
          // Shoot Drone
          if (laserFiredThisFrame && dist < 120) { // Auto-aim generous radius
             entity.isDestroyed = true;
             _dronesDestroyed++;
          }
       } 
       else if (entity.type == EntityType.fuelCore) {
          if (dist < 150 && useTractor) {
             entity.isBeingTractored = true;
             entity.tractorProgress += dt / 2.0; // 2 seconds hold
             if (entity.tractorProgress >= 1.0) {
                entity.isDestroyed = true;
                _coresHarvested++;
                _hullIntegrity = min(1.0, _hullIntegrity + 0.10);
             }
          } else {
             entity.isBeingTractored = false;
             // Progress decays rapidly if dropped
             entity.tractorProgress = max(0, entity.tractorProgress - dt);
          }
       }
       else if (entity.type == EntityType.empWave) {
          // EMP wave is a massive horizontal band. Checking if ship Y crosses it.
          // Band thickness is about 100.
          if ((_shipPosition.dy - entity.position.dy).abs() < 50) {
             if (useShield) {
                // Absorbed part of the wave
                if (!entity.isDestroyed) {
                  _shieldSuccesses++;
                  entity.isDestroyed = true; // Mark handled so we don't count multiple times per wave
                }
             } else {
                if (!entity.isDestroyed) {
                  _shieldFailures++;
                  _hullIntegrity -= 0.25;
                  entity.isDestroyed = true;
                  
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EMP Hit! Hull breached!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                }
             }
          }
       }
    }
    
    _entities.removeWhere((e) => e.isDestroyed);
    
    // Death Check
    if (_hullIntegrity <= 0) {
       _hullIntegrity = 0;
       _showDeathModal();
    }
    
    setState(() {});
  }

  void _showDeathModal() {
    _gameLoop.stop();
    BuildContext parentContext = context;
    
    double avgDelta = _framesWithMovement > 0 ? _totalPitchRollDelta / _framesWithMovement : 0;
    // Lower delta = smoother. Scale roughly so 0.0 -> 100%, 2.0 -> 0%
    int smoothScore = max(0, 100 - (avgDelta * 50).round());
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B0F19),
        title: const Text('Mission Ended', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text('Hand Rest Recommended', style: TextStyle(color: Colors.orange, fontSize: 14)),
             const SizedBox(height: 16),
             Text('Drones Neutralized: $_dronesDestroyed', style: const TextStyle(color: Colors.white70)),
             Text('Drones Missed: $_dronesMissed', style: const TextStyle(color: Colors.white70)),
             Text('Cores Harvested: $_coresHarvested', style: const TextStyle(color: Colors.cyanAccent)),
             Text('Shield Blocks: $_shieldSuccesses / ${_shieldSuccesses + _shieldFailures}', style: const TextStyle(color: Colors.amber)),
             Text('Steering Smoothness: $smoothScore%', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
             onPressed: () {
               Navigator.pop(context);
               Navigator.pop(parentContext); 
             }, 
             child: const Text('Exit to Hangar', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.primaryColor),
            onPressed: () {
              Navigator.pop(context);
              _resetGame(gentleTier: true);
            }, 
            child: const Text('Re-engage at Gentle Speed')
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Deep space black
      body: GestureDetector(
        onPanDown: (details) {
          setState(() => _shipPosition = details.localPosition);
        },
        onPanUpdate: (details) {
          setState(() => _shipPosition = details.localPosition);
        },
        child: Stack(
          children: [
            // Starfield (Simple implementation)
            ...List.generate(50, (index) {
              // Deterministic pseudo-random stars
              double x = (index * 47) % _screenSize.width;
              double y = (index * 83 + _gameLoop.value * 200) % _screenSize.height;
              return Positioned(
                left: x,
                top: y,
                child: Container(width: 2, height: 2, color: Colors.white30),
              );
            }),
            
            // HUD
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  const Text('HULL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _hullIntegrity,
                      backgroundColor: Colors.red.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(_hullIntegrity > 0.5 ? Colors.green : Colors.red),
                      minHeight: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Painter for Game Elements
            CustomPaint(
              painter: SpaceGamePainter(
                entities: _entities,
                shipPosition: _shipPosition,
                shipRadius: _shipRadius,
                isShieldActive: _isShieldActive,
                isTractorActive: _isTractorActive,
                laserCooldown: _laserCooldown,
              ),
              child: Container(),
            ),
            
            // Debug Overlay Buttons (Bottom)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDebugButton('LASER', Colors.cyan, _debugLaser, (v) => setState(() => _debugLaser = v)),
                  _buildDebugButton('TRACTOR', Colors.purpleAccent, _debugTractor, (v) => setState(() => _debugTractor = v)),
                  _buildDebugButton('SHIELD', Colors.amber, _debugShield, (v) => setState(() => _debugShield = v)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDebugButton(String label, Color color, bool active, Function(bool) onChanged) {
    return GestureDetector(
      onTapDown: (_) => onChanged(true),
      onTapUp: (_) => onChanged(false),
      onTapCancel: () => onChanged(false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? color : color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.black : color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class SpaceGamePainter extends CustomPainter {
  final List<SpaceEntity> entities;
  final Offset shipPosition;
  final double shipRadius;
  final bool isShieldActive;
  final bool isTractorActive;
  final double laserCooldown;

  SpaceGamePainter({
    required this.entities,
    required this.shipPosition,
    required this.shipRadius,
    required this.isShieldActive,
    required this.isTractorActive,
    required this.laserCooldown,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Entities
    for (var e in entities) {
      if (e.type == EntityType.drone) {
        // Red diamond
        final Paint dronePaint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
        canvas.drawCircle(e.position, 20, dronePaint);
        canvas.drawCircle(e.position, 10, Paint()..color = Colors.black);
      } else if (e.type == EntityType.fuelCore) {
        // Cyan glowing orb
        canvas.drawCircle(e.position, 25, Paint()..color = Colors.cyanAccent.withOpacity(0.3));
        canvas.drawCircle(e.position, 15, Paint()..color = Colors.cyanAccent);
        
        // Progress ring if being tractored
        if (e.isBeingTractored) {
          canvas.drawArc(
             Rect.fromCircle(center: e.position, radius: 35),
             -pi/2, 2 * pi * e.tractorProgress, false,
             Paint()..color = Colors.purpleAccent..strokeWidth = 4..style = PaintingStyle.stroke
          );
        }
      } else if (e.type == EntityType.empWave) {
        // Massive horizontal shockwave band
        final Paint wavePaint = Paint()
          ..color = Colors.amber.withOpacity(0.4)
          ..style = PaintingStyle.fill;
        canvas.drawRect(Rect.fromLTWH(0, e.position.dy - 50, size.width, 100), wavePaint);
        canvas.drawLine(Offset(0, e.position.dy), Offset(size.width, e.position.dy), Paint()..color = Colors.amber..strokeWidth = 3);
      }
    }
    
    // 2. Draw Tractor Beam Connection
    if (isTractorActive) {
       for (var e in entities) {
         if (e.type == EntityType.fuelCore && e.isBeingTractored) {
            canvas.drawLine(
              shipPosition, e.position, 
              Paint()..color = Colors.purpleAccent.withOpacity(0.5)..strokeWidth = 8
            );
            canvas.drawLine(
              shipPosition, e.position, 
              Paint()..color = Colors.white..strokeWidth = 2
            );
         }
       }
    }

    // 3. Draw Ship
    final Path shipPath = Path();
    shipPath.moveTo(shipPosition.dx, shipPosition.dy - shipRadius);
    shipPath.lineTo(shipPosition.dx + shipRadius, shipPosition.dy + shipRadius);
    shipPath.lineTo(shipPosition.dx, shipPosition.dy + shipRadius * 0.5);
    shipPath.lineTo(shipPosition.dx - shipRadius, shipPosition.dy + shipRadius);
    shipPath.close();
    
    canvas.drawPath(shipPath, Paint()..color = Colors.white..style = PaintingStyle.fill);
    
    // Laser cooldown indicator (crosshair)
    final Paint crosshairPaint = Paint()
      ..color = laserCooldown > 0 ? Colors.red : Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(shipPosition, shipRadius + 15, crosshairPaint);
    
    // 4. Draw Deflector Shield
    if (isShieldActive) {
      canvas.drawCircle(
        shipPosition, 
        shipRadius + 30, 
        Paint()..color = Colors.amber.withOpacity(0.4)..style = PaintingStyle.fill
      );
      canvas.drawCircle(
        shipPosition, 
        shipRadius + 30, 
        Paint()..color = Colors.amber..style = PaintingStyle.stroke..strokeWidth = 3
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpaceGamePainter oldDelegate) => true;
}
