import 'dart:async';

import 'package:flutter/material.dart';
import 'package:goblin_slayer/extensions/queries.dart';
import 'package:oxygen/oxygen.dart';

enum GameStatus {
  startMenu,
  playing,
  paused,
  gameOver,
}

class GameState {
  final ValueNotifier<GameStatus> _status = ValueNotifier(GameStatus.startMenu);
  GameStatus get status => _status.value;
  GameStatus _previousGameStatus = GameStatus.startMenu;
  GameStatus get previousGameStatus => _previousGameStatus;
  ValueNotifier<GameStatus> get statusValueNotifier => _status;

  Timer? _timer;

  final ValueNotifier<int> _specialBuildUp = ValueNotifier(0);
  ValueNotifier<int> get specialBuildUp => _specialBuildUp;

  int _spawnCooldown = 1000;

  /// The amount of time to wait between enemy spawns.
  int get spawnCooldown => _spawnCooldown;

  bool get isPlaying => status == GameStatus.playing;
  bool get shouldAdvance =>
      status == GameStatus.playing || status == GameStatus.gameOver;
  bool get isPaused => status == GameStatus.paused;
  bool get isNewGame => previousGameStatus == GameStatus.gameOver && isPlaying;

  bool _canResetGame = false;
  bool get canResetGame => _canResetGame;

  void _setStatus(GameStatus status) {
    _previousGameStatus = _status.value;
    _status.value = status;
  }

  bool canPerformSpecialAttack() => _specialBuildUp.value >= 5;

  void resetSpecialAttack() {
    _specialBuildUp.value = 0;
  }

  void increaseSpecialBuildUp() {
    if (_specialBuildUp.value >= 5) return;
    _specialBuildUp.value++;
  }

  void pauseGame() {
    _setStatus(GameStatus.paused);
  }

  void gameOver() {
    _canResetGame = false;
    // This delay is to ensure that the player has time to react to the game
    // over screen and not accidentally start a new game.
    Future.delayed(const Duration(milliseconds: 750), () {
      _canResetGame = true;
    });

    _setStatus(GameStatus.gameOver);
  }

  void resumeGame() {
    _setStatus(GameStatus.playing);
  }

  void startGame() {
    _setStatus(GameStatus.playing);
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      _onTick,
    );
    _specialBuildUp.value = 0;
  }

  void resetGame(World world, CreateQuery createQuery) {
    if (_canResetGame) {
      startGame();
      _canResetGame = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _specialBuildUp.dispose();
    _status.dispose();
  }

  void _onTick(Timer time) {
    if (!isPlaying) return;

    if (_spawnCooldown <= 1) {
      _timer?.cancel();
      return;
    }
    _spawnCooldown -= 5;
  }
}
