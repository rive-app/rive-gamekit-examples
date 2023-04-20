import 'package:flutter/material.dart';
import 'package:goblin_slayer/game/constants.dart';
import 'package:goblin_slayer/game/state/game_state.dart';
import 'package:oxygen/oxygen.dart';

mixin InputSystem on System {
  void onKeyEvent(KeyEvent event) {}

  void onPointerEvent(PointerEvent event) {}
}

extension AccessSystem on SystemManager {
  Iterable<InputSystem> get inputSystems => systems.whereType<InputSystem>();
}

extension WorldExtension on World {
  set windowSize(Size size) {
    store(Constants.windowSize, size);
  }

  GameState get gameState => retrieve(Constants.gameState);

  Size get windowSize => retrieve(Constants.windowSize);

  Size get worldSize => retrieve(Constants.worldSize);
}
