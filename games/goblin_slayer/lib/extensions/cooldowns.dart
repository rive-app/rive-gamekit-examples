import 'dart:math';

import 'package:flutter/rendering.dart';

class AttackCooldown {
  final Duration duration;
  late DateTime lastTriggered;
  double progress = 0;
  VoidCallback? onCooldownComplete;
  CooldownState state = CooldownState.ready;

  AttackCooldown(this.duration, {this.onCooldownComplete}) {
    lastTriggered = DateTime.now().subtract(duration);
  }

  bool get isReady => state == CooldownState.ready;

  void startCooldown() {
    state = CooldownState.cooldown;
    lastTriggered = DateTime.now();
  }

  void update() {
    if (state == CooldownState.ready) return;

    final difference = DateTime.now().difference(lastTriggered);
    if (state == CooldownState.cooldown && difference >= duration) {
      onCooldownComplete?.call();
      state = CooldownState.ready;
    }
    progress = min(1, difference.inMilliseconds / duration.inMilliseconds);
  }
}

class DeathCooldown {
  final Duration duration;
  late DateTime lastTriggered;
  DeathCoolDownState state = DeathCoolDownState.none;

  DeathCooldown(this.duration) {
    lastTriggered = DateTime.now().subtract(duration);
  }

  bool get isReady => state == DeathCoolDownState.none;
  bool get isDone => state == DeathCoolDownState.done;

  void startCooldown() {
    state = DeathCoolDownState.dyingAnimation;
    lastTriggered = DateTime.now();
  }

  void update() {
    if (state == DeathCoolDownState.none) return;

    final difference = DateTime.now().difference(lastTriggered);
    if (state == DeathCoolDownState.dyingAnimation && difference >= duration) {
      state = DeathCoolDownState.done;
    }
  }
}

enum DeathCoolDownState {
  none,
  dyingAnimation,
  done,
}

enum CooldownState {
  ready,
  cooldown,
}
