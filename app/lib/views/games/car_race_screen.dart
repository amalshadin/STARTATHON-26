import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_tokens.dart';
import '../../providers/ble_telemetry_provider.dart';
import 'package:hapticsync/providers/calibration_provider.dart';
import 'package:hapticsync/services/patient_api_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class Obstacle {
  Offset position;
  final double width;
  final double height;
  final Color color;

  Obstacle({
    required this.position,
    required this.width,
    required this.height,
    required this.color,
  });
}

class CarRaceScreen extends StatefulWidget {
  const CarRaceScreen({super.key});

  @override
  State<CarRaceScreen> createState() => _CarRaceScreenState();
}

class _CarRaceScreenState extends State<CarRaceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gameLoop;
  final PatientApiService _apiService = PatientApiService();

  // Game State
  bool _isPlaying = false;
  bool _isGameOver = false;
  double _distanceTraveled = 0.0;

  // Entities
  Offset _carPosition = const Offset(
    200,
    600,
  ); // Will update in didChangeDependencies
  final double _carWidth = 50;
  final double _carHeight = 80;
  final List<Obstacle> _obstacles = [];

  // Telemetry metrics
  double _totalRollAbs = 0.0;
  int _frameCount = 0;
  double _lastRoll = 0.0;
  double _totalPitchRollDelta = 0.0;

  // Environment
  Size _screenSize = const Size(400, 800);
  final math.Random _random = math.Random();
  double _spawnTimer = 0.0;

  // Submitting logic
  bool _isSubmitting = false;
  Map<String, dynamic>? _aiOverview;
  String _submitError = '';

  // Debug inputs
  bool _debugLeft = false;
  bool _debugRight = false;
  bool _debugAccel = false;

  @override
  void initState() {
    super.initState();
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 365),
    )..addListener(_updateGame);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
    if (!_isPlaying && !_isGameOver) {
      _carPosition = Offset(_screenSize.width / 2, _screenSize.height - 150);
    }
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    super.dispose();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _distanceTraveled = 0.0;
      _obstacles.clear();
      _carPosition = Offset(_screenSize.width / 2, _screenSize.height - 150);

      _totalRollAbs = 0.0;
      _frameCount = 0;
      _lastRoll = 0.0;
      _totalPitchRollDelta = 0.0;
      _spawnTimer = 0.0;

      _isSubmitting = false;
      _aiOverview = null;
      _submitError = '';
    });
    _gameLoop.forward(from: 0);
  }

  void _endGame() async {
    _gameLoop.stop();
    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isSubmitting = true;
    });

    try {
      final ble = context.read<BleTelemetryProvider>();

      double avgRoll = _frameCount > 0 ? _totalRollAbs / _frameCount : 0;
      double stability = _frameCount > 0
          ? _totalPitchRollDelta / _frameCount
          : 0;

      final metrics = {
        'game_type': 'neon_racer',
        'distance_traveled': _distanceTraveled,
        'average_roll': avgRoll,
        'stability_score': stability,
        'duration_seconds': _distanceTraveled / 100.0,
      };

      final overview = await _apiService.submitGameData(
        gameId: '00000000-0000-0000-0000-000000000001',
        startedAt: DateTime.now().subtract(
          Duration(milliseconds: (_distanceTraveled / 100.0 * 1000).toInt()),
        ),
        durationMs: (_distanceTraveled / 100.0 * 1000).toInt(),
        score: _distanceTraveled.toInt(),
        accuracy: 1.0,
        completionRate: 1.0,
        repetitions: 0,
        resultsMetrics: {'avgRoll': avgRoll, 'stability': stability},
        calculatedMetrics: metrics,
      );

      if (mounted) {
        setState(() {
          _aiOverview = overview;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitError = e.toString();
          _isSubmitting = false;
        });
      }
    }
  }

  void _updateGame() {
    if (!_isPlaying) return;

    final bleProvider = context.read<BleTelemetryProvider>();
    final calProvider = context.read<CalibrationProvider>();

    // In milliseconds, assumed 60 FPS = ~0.016
    double dt = 1 / 60.0;

    double dx = 0.0;
    double speedBase = 300.0; // Base obstacle falling speed

    if (bleProvider.isConnected) {
      var packet = bleProvider.latestPacket;
      double correctedPitch = calProvider.getCorrectedPitch(packet.pitch);
      double correctedRoll = calProvider.getCorrectedRoll(packet.roll);

      // Roll -> Left/Right Steering
      dx = correctedRoll * 0.15 * dt;

      // Pitch -> Acceleration/Braking
      // Positive pitch (extension) accelerates, negative (flexion) brakes
      // Reduced sensitivity from 0.002 to 0.0005 and max clamp to 1.8
      double speedModifier = 1.0 + (-correctedPitch * 0.0005);
      speedModifier = speedModifier.clamp(0.5, 1.8);
      speedBase = speedBase * speedModifier;

      // Telemetry
      _totalRollAbs += correctedRoll.abs();
      _totalPitchRollDelta += (correctedRoll - _lastRoll).abs();
      _lastRoll = correctedRoll;
      _frameCount++;
    } else {
      // Debug inputs
      if (_debugLeft) dx = -5.0;
      if (_debugRight) dx = 5.0;
      if (_debugAccel) speedBase = 600.0;
    }

    setState(() {
      // Move Car
      _carPosition = Offset(
        (_carPosition.dx + dx).clamp(0.0, _screenSize.width - _carWidth),
        _carPosition.dy,
      );

      // Move Obstacles
      for (var obs in _obstacles) {
        obs.position = Offset(
          obs.position.dx,
          obs.position.dy + (speedBase * dt),
        );
      }

      // Remove off-screen obstacles
      _obstacles.removeWhere((obs) => obs.position.dy > _screenSize.height);

      // Spawn Obstacles
      _spawnTimer += dt;
      // Spawn rate based on speed
      double spawnRate = 1.2 / (speedBase / 300.0).clamp(0.5, 2.5);
      if (_spawnTimer > spawnRate) {
        _spawnTimer = 0.0;
        _obstacles.add(
          Obstacle(
            position: Offset(
              _random.nextDouble() * (_screenSize.width - _carWidth),
              -100,
            ),
            width: 50 + _random.nextDouble() * 40,
            height: 30 + _random.nextDouble() * 20,
            color: Colors.redAccent,
          ),
        );
      }

      _distanceTraveled += speedBase * dt * 0.1;

      // Collision Check
      // Make collision box slightly smaller than sprite
      Rect carRect = Rect.fromLTWH(
        _carPosition.dx + 5,
        _carPosition.dy + 5,
        _carWidth - 10,
        _carHeight - 10,
      );
      for (var obs in _obstacles) {
        Rect obsRect = Rect.fromLTWH(
          obs.position.dx,
          obs.position.dy,
          obs.width,
          obs.height,
        );
        if (carRect.overlaps(obsRect)) {
          _endGame();
          break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A), // Dark asphalt
      appBar: AppBar(
        title: const Text('Neon Racer', style: DesignTokens.headingStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Road markings (moving down)
          Center(
            child: Container(
              width: 10,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white24, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Obstacles
          ..._obstacles.map(
            (obs) => Positioned(
              left: obs.position.dx,
              top: obs.position.dy,
              child: Container(
                width: obs.width,
                height: obs.height,
                decoration: BoxDecoration(
                  color: obs.color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: obs.color.withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Car
          Positioned(
            left: _carPosition.dx,
            top: _carPosition.dy,
            child: Container(
              width: _carWidth,
              height: _carHeight,
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.arrow_upward, color: Colors.black87),
              ),
            ),
          ),

          // HUD
          Positioned(
            top: 20,
            left: 20,
            child: Text(
              'Distance: ${_distanceTraveled.toStringAsFixed(0)}m',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Overlays
          if (!_isPlaying && !_isGameOver) _buildStartScreen(),

          if (_isGameOver) _buildGameOverScreen(),

          // Debug Controls
          if (const bool.fromEnvironment('dart.vm.product') == false &&
              !_isPlaying &&
              !_isGameOver)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  // Fake start
                  _startGame();
                },
                child: const Icon(Icons.play_arrow),
              ),
            ),

          // On screen debug controls while playing
          if (const bool.fromEnvironment('dart.vm.product') == false &&
              _isPlaying)
            Positioned(
              bottom: 20,
              left: 20,
              child: Row(
                children: [
                  GestureDetector(
                    onTapDown: (_) => _debugLeft = true,
                    onTapUp: (_) => _debugLeft = false,
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.white24,
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTapDown: (_) => _debugRight = true,
                    onTapUp: (_) => _debugRight = false,
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.white24,
                      child: const Icon(Icons.arrow_forward),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTapDown: (_) => _debugAccel = true,
                    onTapUp: (_) => _debugAccel = false,
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.white24,
                      child: const Icon(Icons.speed),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStartScreen() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.directions_car,
              size: 80,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 24),
            const Text(
              'Neon Racer',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Supination/Pronation (Roll) to Steer.\nFlexion/Extension (Pitch) to Accelerate/Brake.\nDodge the red obstacles!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              child: const Text(
                'START ENGINES',
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent, width: 2),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CRASHED!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Distance: ${_distanceTraveled.toStringAsFixed(0)}m',
                  style: const TextStyle(fontSize: 24, color: Colors.white),
                ),
                const SizedBox(height: 32),

                if (_isSubmitting)
                  const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.cyanAccent),
                      SizedBox(height: 16),
                      Text(
                        'Analyzing telemetry...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  )
                else if (_submitError.isNotEmpty)
                  Text(
                    'Error: $_submitError',
                    style: const TextStyle(color: Colors.redAccent),
                  )
                else if (_aiOverview != null) ...[
                  const Text(
                    'Clinical AI Overview',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    height: 150,
                    child: SingleChildScrollView(
                      child: MarkdownBody(
                        data: _aiOverview!['overview'] ?? '',
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: Colors.white70),
                          h1: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          h2: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          h3: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          listBullet: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
                  if (_aiOverview!['focus_areas'] != null &&
                      (_aiOverview!['focus_areas'] as List).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Focus Areas:',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...(_aiOverview!['focus_areas'] as List).map(
                      (area) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.arrow_right,
                              color: Colors.cyanAccent,
                              size: 16,
                            ),
                            Expanded(
                              child: Text(
                                area.toString(),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DesignTokens.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Return to Arena',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
