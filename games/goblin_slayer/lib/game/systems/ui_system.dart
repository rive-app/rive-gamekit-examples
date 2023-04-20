import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goblin_slayer/extensions/input.dart';
import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import '../state/game_state.dart';

class UISystem extends System with InputSystem {
  final rive.File uiHudFile;
  final rive.File coverFile;
  final rive.File textFile;

  late final rive.Artboard _specialArtboard;
  late final rive.StateMachine _specialStateMachine;
  late final rive.NumberInput _specialAttackBuildUp;
  // late final rive.TriggerInput _specialAttackInput;

  late final rive.Artboard _coverArtboard;
  late final rive.StateMachine _coverStateMachine;

  late final rive.Artboard _gameOverArtboard;
  // late final rive.StateMachine _gameOverStateMachine;

  UISystem({
    required this.uiHudFile,
    required this.coverFile,
    required this.textFile,
    super.priority = 6,
  }) {
    // HUD
    _specialArtboard = uiHudFile.artboard('Special')!;
    _specialStateMachine = _specialArtboard.defaultStateMachine()!;
    _specialAttackBuildUp = _specialStateMachine.number('goblins_killed')!;

    // Cover
    _coverArtboard = coverFile.artboard('Cover')!;
    _coverStateMachine = _coverArtboard.defaultStateMachine()!;

    // Text
    _gameOverArtboard = textFile.artboard('GameOver')!;
    // _gameOverStateMachine = _gameOverArtboard.defaultStateMachine()!;
  }

  late final rive.AABB _specialBounds;
  late final rive.AABB _coverBounds;
  static const double padding = 8;

  late GameState _gameState;

  late final _paint = rive.Renderer.makePaint()..color = Colors.black45;

  @override
  void init() {
    _gameState = world!.gameState;

    _specialAttackBuildUp.value = 0;
    _gameState.specialBuildUp.addListener(_specialAttackValueChanged);

    _specialBounds = _specialArtboard.bounds;
    _coverBounds = _coverArtboard.bounds;
  }

  void _specialAttackValueChanged() {
    final state = _gameState.specialBuildUp.value;
    _specialAttackBuildUp.value = state.toDouble();
  }

  @override
  void execute(double delta) {
    final renderer = rive.Renderer.make();
    switch (world!.gameState.status) {
      case GameStatus.startMenu:
      case GameStatus.paused:
        _drawGameStart(renderer, delta);
        break;
      case GameStatus.playing:
        _drawHud(renderer, delta);
        break;
      case GameStatus.gameOver:
        _drawGameOver(renderer, delta);
        break;
    }
  }

  void _drawGameStart(rive.Renderer renderer, double delta) {
    final size = world!.windowSize;
    final screenPath = _fullScreenPath(world!.windowSize);
    renderer.drawPath(screenPath, _paint);
    _coverStateMachine.advance(delta);

    renderer.save();
    renderer.align(
      BoxFit.contain,
      Alignment.topCenter,
      rive.AABB.fromMinMax(
        rive.Vec2D.fromValues(0, 0),
        rive.Vec2D.fromValues(size.width, size.height / 2),
      ),
      _coverBounds,
    );
    _coverArtboard.draw(renderer);
    renderer.restore();
  }

  void _drawHud(rive.Renderer renderer, double delta) {
    _specialStateMachine.advance(delta);
    final windowSize = world!.windowSize;
    final minSize = min(world!.windowSize.width, world!.windowSize.height);
    final specialAttackHudSize = (minSize / 6);
    final padding = 8 * window.devicePixelRatio;
    renderer.save();
    renderer.align(
      BoxFit.contain,
      Alignment.bottomRight,
      rive.AABB
          .fromValues(0, 0, specialAttackHudSize, specialAttackHudSize)
          .offset(windowSize.width - specialAttackHudSize - padding,
              windowSize.height - specialAttackHudSize - padding),
      _specialBounds,
    );
    _specialArtboard.draw(renderer);

    renderer.restore();
  }

  void _drawGameOver(rive.Renderer renderer, double delta) {
    final windowSize = world!.windowSize;
    final screenPath = _fullScreenPath(windowSize);
    renderer.drawPath(screenPath, _paint);
    renderer.save();
    renderer.align(
      BoxFit.contain,
      Alignment.center,
      rive.AABB.fromMinMax(rive.Vec2D.fromValues(0, 0),
          rive.Vec2D.fromValues(windowSize.width, windowSize.height)),
      _gameOverArtboard.bounds,
    );
    // _gameOverStateMachine.advance(delta);
    _gameOverArtboard.draw(renderer);
    renderer.restore();
  }

  rive.RenderPath _fullScreenPath(Size size) {
    final path = rive.Renderer.makePath();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  void onKeyEvent(KeyEvent event) {
    if (_gameState.status == GameStatus.startMenu) {
      if (event is KeyUpEvent &&
          (event.logicalKey == LogicalKeyboardKey.space)) {
        _gameState.startGame();
      }
    } else if (_gameState.status == GameStatus.playing) {
      if (event is KeyUpEvent &&
          (event.logicalKey == LogicalKeyboardKey.escape)) {
        _gameState.pauseGame();
      }
    } else if (_gameState.status == GameStatus.paused) {
      if (event is KeyUpEvent &&
          (event.logicalKey == LogicalKeyboardKey.escape)) {
        _gameState.resumeGame();
      }
    } else if (_gameState.status == GameStatus.gameOver) {
      if (event is KeyUpEvent &&
          (event.logicalKey == LogicalKeyboardKey.space)) {
        _gameState.resetGame(world!, createQuery);
      }
    }

    super.onKeyEvent(event);
  }

  @override
  void dispose() {
    _gameState.specialBuildUp.removeListener(_specialAttackValueChanged);

    _specialStateMachine.dispose();
    _specialArtboard.dispose();

    _coverStateMachine.dispose();
    _coverArtboard.dispose();
    super.dispose();
  }
}
