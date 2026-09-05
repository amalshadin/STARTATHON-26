import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class GameSessionProvider extends ChangeNotifier {
  int _score = 0;
  bool _isActive = false;
  double _difficultyMultiplier = 1.0;

  bool get isActive => _isActive;
  int get score => _score;
  double get difficultyMultiplier => _difficultyMultiplier;

  void startGame() {
    _score = 0;
    _isActive = true;
    _difficultyMultiplier = 1.0;
    notifyListeners();
  }

  void stopGame() {
    _isActive = false;
    notifyListeners();
    // In a real app, we'd save the session summary here
  }

  void addScore(int points) {
    if (!_isActive) return;
    _score += (points * _difficultyMultiplier).round();
    notifyListeners();
  }
  
  void setDifficulty(double multiplier) {
    _difficultyMultiplier = multiplier;
    notifyListeners();
  }
}
