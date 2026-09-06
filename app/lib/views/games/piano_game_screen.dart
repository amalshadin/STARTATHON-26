import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_tokens.dart';
import '../../providers/ble_telemetry_provider.dart';
import 'package:hapticsync/providers/calibration_provider.dart';
import 'package:hapticsync/services/patient_api_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../utils/metric_calculator.dart';
import '../../models/sensor_packet.dart';

enum Difficulty { gentle, standard, challenge }

class DifficultySettings {
  final double threshold;
  final double holdDuration; // in seconds
  final double fallSpeed; // units per second
  final double spawnDelay; // delay between spawns in seconds

  const DifficultySettings({
    required this.threshold,
    required this.holdDuration,
    required this.fallSpeed,
    required this.spawnDelay,
  });

  static const settings = {
    Difficulty.gentle: DifficultySettings(
      threshold: 0.35,
      holdDuration: 1.5,
      fallSpeed: 100.0,
      spawnDelay: 4.0,
    ),
    Difficulty.standard: DifficultySettings(
      threshold: 0.55,
      holdDuration: 2.5,
      fallSpeed: 150.0,
      spawnDelay: 3.0,
    ),
    Difficulty.challenge: DifficultySettings(
      threshold: 0.75,
      holdDuration: 3.5,
      fallSpeed: 220.0,
      spawnDelay: 2.0,
    ),
  };
}

enum RibbonState { falling, activeHold, completed, missed, broken }

class RibbonNote {
  final int lane; // 0, 1, 2
  double yPosition; // Defines the position of the activation head
  double length; // Visual length representing the hold duration
  RibbonState state;
  double holdProgress; // 0.0 to 1.0
  DateTime? lastHoldTime;
  bool isDestroyed;

  RibbonNote({
    required this.lane,
    required this.yPosition,
    required this.length,
    this.state = RibbonState.falling,
    this.holdProgress = 0.0,
    this.isDestroyed = false,
  });
}

class PianoGameScreen extends StatefulWidget {
  final Difficulty mode;

  const PianoGameScreen({super.key, this.mode = Difficulty.standard});

  @override
  State<PianoGameScreen> createState() => _PianoGameScreenState();
}

class _PianoGameScreenState extends State<PianoGameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gameLoop;
  late Difficulty _currentDifficulty;
  DifficultySettings get _settings =>
      DifficultySettings.settings[_currentDifficulty]!;
  final PatientApiService _apiService = PatientApiService();

  DateTime _startTime = DateTime.now();
  bool _isSubmitting = false;

  final List<RibbonNote> _activeNotes = [];
  final List<SensorPacket> _sessionPackets = [];
  final Random _random = Random();

  int _score = 0;
  int _combo = 0;
  double _totalHoldDuration = 0.0;
  double _scoreAccumulator = 0.0;
  int _hits = 0;
  int _misses = 0;

  double _lastSpawnTime = 0;
  final double _hitZoneY = 600.0; // Fixed hit zone near the bottom

  // Debug simulation inputs
  final List<bool> _debugHolds = [false, false, false];

  // Anti-cheat tracking
  final List<bool> _laneReadyToHit = [true, true, true];

  @override
  void initState() {
    super.initState();
    _currentDifficulty = widget.mode;
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 99), // Run endlessly
    )..addListener(_updateGame);

    _gameLoop.forward();
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    super.dispose();
  }

  void _updateGame() {
    if (!mounted) return;

    final bleProvider = context.read<BleTelemetryProvider>();
    final calProvider = context.read<CalibrationProvider>();

    final dt = 1.0 / 60.0; // Approx 60fps delta time for logic

    _sessionPackets.add(bleProvider.latestPacket);

    // 1. Spawn new notes
    _lastSpawnTime += dt;
    if (_lastSpawnTime > _settings.spawnDelay && _activeNotes.length < 3) {
      _lastSpawnTime = 0;
      _activeNotes.add(
        RibbonNote(
          lane: _random.nextInt(3),
          yPosition: -100, // Spawn above screen
          length:
              _settings.holdDuration *
              _settings.fallSpeed, // Length proportional to required hold
        ),
      );
    }

    // 2. Update and process notes
    final now = DateTime.now();
    for (int i = 0; i < _activeNotes.length; i++) {
      var note = _activeNotes[i];

      if (note.state == RibbonState.falling ||
          note.state == RibbonState.missed ||
          note.state == RibbonState.broken) {
        note.yPosition += _settings.fallSpeed * dt;
      }

      // Determine actual flex input (hardware or debug overlay)
      double flexValue = 0.0;
      if (_debugHolds[note.lane]) {
        flexValue = 1.0; // Simulated full flex
      } else {
        // Hardware telemetry (indexes 0, 1, 2 for thumb/index, middle, ring)
        double rawVal = bleProvider.latestPacket.flexValues[note.lane];
        flexValue = calProvider.normalizeFlexValue(note.lane, rawVal);
      }

      bool isHolding = flexValue >= _settings.threshold;
      // Make it slightly more forgiving (0.75 instead of 0.6)
      bool isRelaxed =
          flexValue < (_settings.threshold * 0.75); // Release threshold

      if (isRelaxed) {
        _laneReadyToHit[note.lane] = true;
      }

      // Hit detection
      if (note.state == RibbonState.falling &&
          note.yPosition >= _hitZoneY - 30 &&
          note.yPosition <= _hitZoneY + 30) {
        if (isHolding && _laneReadyToHit[note.lane]) {
          note.state = RibbonState.activeHold;
          note.lastHoldTime = now;
          _laneReadyToHit[note.lane] =
              false; // Must relax before hitting another
        }
      } else if (note.state == RibbonState.falling &&
          note.yPosition > _hitZoneY + 50) {
        // Missed the activation window
        note.state = RibbonState.missed;
      }

      // Hold phase logic
      if (note.state == RibbonState.activeHold) {
        // Stop falling visually, conceptually we "consume" the ribbon
        note.yPosition = _hitZoneY;
        note.length -= _settings.fallSpeed * dt;

        if (isHolding) {
          note.lastHoldTime = now;
          note.holdProgress += dt / _settings.holdDuration;
          _totalHoldDuration += dt;

          _scoreAccumulator += dt;
          if (_scoreAccumulator >= 0.1) {
            _score += 10 + _combo;
            _scoreAccumulator -= 0.1;
          }

          if (note.holdProgress >= 1.0 || note.length <= 0) {
            note.state = RibbonState.completed;
            _score += 100 + (_combo * 10);
            _combo++;
            _hits++;
          }
        } else {
          // Grace period check (300ms)
          if (note.lastHoldTime != null &&
              now.difference(note.lastHoldTime!).inMilliseconds > 300) {
            note.state = RibbonState.broken;
            _combo = 0;
            _misses++;
          }
        }
      }

      if (note.state == RibbonState.missed ||
          note.state == RibbonState.completed ||
          note.state == RibbonState.broken ||
          note.yPosition > 1000) {
        if (note.state == RibbonState.missed) {
          _misses++;
          _combo = 0;
        }
        note.isDestroyed = true;
      }
    }

    // Remove completed or off-screen notes
    _activeNotes.removeWhere((n) => n.isDestroyed);

    // For demo purposes, end game if score > 10000
    if (_score > 10000) {
      _handleGameEnd();
    }

    setState(() {});
  }

  Future<void> _handleGameEnd() async {
    if (_isSubmitting) return;

    _gameLoop.stop();
    setState(() => _isSubmitting = true);

    final calProvider = context.read<CalibrationProvider>();
    final metrics = MetricCalculator.computeSessionMetrics(
      _sessionPackets,
      calProvider.calibrationData!,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const CircularProgressIndicator(color: DesignTokens.primaryColor),
            const SizedBox(width: 20),
            const Expanded(
              child: Text(
                "Analyzing your hand movement & generating AI clinical overview...",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    Map<String, dynamic> aiOverview = {};
    try {
      final accuracy = _hits + _misses > 0 ? (_hits / (_hits + _misses)) : 0.0;
      aiOverview = await _apiService.submitGameData(
        gameId: 'edbc37b3-da00-4316-a56b-b1ca35cc58bd', // Placeholder UUID
        startedAt: _startTime,
        durationMs: DateTime.now().difference(_startTime).inMilliseconds,
        score: _score,
        accuracy: accuracy,
        completionRate: 1.0,
        repetitions: _hits,
        resultsMetrics: {
          'max_combo': _combo,
          'total_hold_time_s': _totalHoldDuration,
        },
        calculatedMetrics: metrics,
      );
    } catch (e) {
      debugPrint('Failed to submit game data: $e');
    }

    if (mounted) {
      Navigator.pop(context); // close spinner
      setState(() => _isSubmitting = false);
      _showSummary(aiOverview);
    }
  }

  void _showSummary(Map<String, dynamic> aiOverview) {
    BuildContext parentContext = context;

    String summary = aiOverview['overview'] ?? "AI Overview unavailable.";
    List<dynamic> focusAreas = aiOverview['focus_areas'] ?? [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Clinical AI Overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score: $_score | Accuracy: ${_hits + _misses > 0 ? ((_hits / (_hits + _misses)) * 100).toStringAsFixed(1) : 0}%',
                style: const TextStyle(
                  color: DesignTokens.secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'AI Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              MarkdownBody(
                data: summary,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.white70),
                  h1: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  h3: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  listBullet: const TextStyle(color: Colors.white70),
                ),
              ),
              if (focusAreas.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Focus Areas',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...focusAreas.map((area) => Text('• $area', style: const TextStyle(color: Colors.white70))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(parentContext); // Go back to arena
            },
            child: const Text(
              'Return to Dashboard',
              style: TextStyle(color: DesignTokens.secondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFF0F172A,
      ), // Dark medical cyberpunk palette
      appBar: AppBar(
        title: const Text(
          'Sustained Hold',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          DropdownButton<Difficulty>(
            value: _currentDifficulty,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            icon: const Icon(Icons.tune, color: Colors.white),
            items: Difficulty.values.map((d) {
              return DropdownMenuItem(
                value: d,
                child: Text(d.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _currentDifficulty = val);
              }
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.stop_circle_outlined,
              color: DesignTokens.errorColor,
            ),
            onPressed: _handleGameEnd,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Game Board
          CustomPaint(
            painter: PianoGamePainter(notes: _activeNotes, hitZoneY: _hitZoneY),
            child: Container(),
          ),

          // HUD
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Score: $_score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Combo: $_combo x',
                  style: const TextStyle(
                    color: DesignTokens.secondaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Debug Overlay for PC/Mac/Emulator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => _debugHolds[index] = true,
                    onTapUp: (_) => _debugHolds[index] = false,
                    onTapCancel: () => _debugHolds[index] = false,
                    child: Container(
                      color: _debugHolds[index]
                          ? Colors.white.withOpacity(0.1)
                          : Colors.transparent,
                      child: const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            'HOLD (Debug)',
                            style: TextStyle(color: Colors.white30),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class PianoGamePainter extends CustomPainter {
  final List<RibbonNote> notes;
  final double hitZoneY;

  PianoGamePainter({required this.notes, required this.hitZoneY});

  @override
  void paint(Canvas canvas, Size size) {
    final double laneWidth = size.width / 3;

    // Draw Lanes
    final Paint laneDividerPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 2;

    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(laneWidth * i, 0),
        Offset(laneWidth * i, size.height),
        laneDividerPaint,
      );
    }

    // Draw Hit Zone
    final Paint hitZonePaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, hitZoneY - 40, size.width, 80),
      hitZonePaint,
    );

    final Paint hitZoneLinePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, hitZoneY),
      Offset(size.width, hitZoneY),
      hitZoneLinePaint,
    );

    // Draw Notes
    final List<Color> laneColors = [
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFF1DE9B6), // Teal
      const Color(0xFFD500F9), // Purple
    ];

    for (var note in notes) {
      final double xCenter = (note.lane * laneWidth) + (laneWidth / 2);
      final double tileWidth = laneWidth * 0.8;
      final double tileLeft = xCenter - (tileWidth / 2);

      Color tileColor = Colors.black87; // Classic piano tile look
      Color borderColor = Colors.white24;

      if (note.state == RibbonState.missed ||
          note.state == RibbonState.broken) {
        tileColor = Colors.red.withOpacity(0.5);
      } else if (note.state == RibbonState.activeHold) {
        tileColor = laneColors[note.lane]; // Fill with neon color during hold
        borderColor = Colors.white;
      }

      // Draw Tile (Rectangular)
      final Paint tilePaint = Paint()
        ..color = tileColor
        ..style = PaintingStyle.fill;

      final Paint borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final Rect tileRect = Rect.fromLTRB(
        tileLeft,
        note.yPosition - note.length, // Top of the tile
        tileLeft + tileWidth,
        note.yPosition, // Bottom of the tile (Activation head)
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(tileRect, const Radius.circular(8)),
        tilePaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tileRect, const Radius.circular(8)),
        borderPaint,
      );

      // Draw Progress Ring (if holding)
      if (note.state == RibbonState.activeHold) {
        final Paint progressPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;

        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(xCenter, note.yPosition - 30),
            radius: 25,
          ),
          -pi / 2, // Start at top
          2 * pi * note.holdProgress,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PianoGamePainter oldDelegate) => true; // Always repaint on tick
}
