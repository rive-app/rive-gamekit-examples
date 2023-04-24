import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;
import 'package:space_invaders_bug/projectile.dart';

import 'package:space_invaders_bug/utils.dart';

class Boss {
  final rive.File bossFile;
  final rive.Artboard artboard;
  final rive.StateMachine stateMachine;
  late rive.TriggerInput bossHitTrigger;
  late rive.TriggerInput bossAttackTrigger;
  late rive.NumberInput bossHealthInput;

  final rive.AABB bounds;
  final rive.Mat2D bossTransform;
  late rive.Vec2D position = rive.Vec2D.fromValues(0, 0);
  late rive.Vec2D centerPosition;

  double _deadTime = 0;

  double timeSinceMoveDown = 0;
  final double timeTillMoveDown = 10;

  bool hasMovedIn = false;

  final Set<MinionProjectile> minionProjectileList = {};
  final Set<MinionProjectile> minionsReadyToBeRemoved = {};

  Boss(
    this.bossFile,
    this.artboard,
    this.stateMachine, {
    required this.bounds,
    required this.bossTransform,
  })  : bossHitTrigger = stateMachine.trigger("hit")!,
        bossAttackTrigger = stateMachine.trigger("Attack")!,
        bossHealthInput = stateMachine.number("health")!;

  bool get isDead => _deadTime > 0.75;

  void advanceAndDraw(rive.Renderer renderer, double elapsedSeconds) {
    renderer.save();
    artboard.renderTransform = bossTransform;
    renderer.transform(bossTransform);
    stateMachine.advance(elapsedSeconds);
    if (bossHealthInput.value <= 0) {
      _deadTime += elapsedSeconds;
    }
    artboard.draw(renderer);
    renderer.restore();
  }

  void moveIn() {
    hasMovedIn = true;
  }

  void takeDamage() {
    bossHitTrigger.fire();
    bossHealthInput.value -= 1;
  }

  // When the Boss fires, spawn 20 MinionProjectile entities from set locations
  // in the Boss artboard
  void fire(rive.Component shipComponent) {
    bossAttackTrigger.fire();
    for (var i = 1; i < 21; i++) {
      var locationComponent = artboard.component("location$i")!;
      var minionSpawn = bossFile.artboard("Minion")!;
      minionSpawn.frameOrigin = false;
      minionProjectileList.add(MinionProjectile(
        minionSpawn,
        artboard,
        locationComponent,
      ));
    }
  }

  // Batch advance and render all the minions over time
  void advanceMinions(
    rive.Renderer renderer,
    double elapsedSeconds,
    rive.Component shipComponent,
  ) {
    Set<rive.StateMachine> minionSetToBatchAdvance = {};
    for (var minion in minionProjectileList) {
      if (minion.isDone) {
        minion.dispose();
        minionsReadyToBeRemoved.add(minion);
      } else {
        var shouldMove = minion.timeSinceSpawn >= minion.timeUntilAttack;
        minion.drawNextTransform(shipComponent, renderer, elapsedSeconds);
        if (shouldMove) {
          minionSetToBatchAdvance.add(minion.minionSm);
        }
      }
    }
    rive.Rive.batchAdvanceAndRender(
        minionSetToBatchAdvance, elapsedSeconds, renderer);
  }

  // Test if any minions hit the ship artboard bounds and remove any minions
  // that do hit it
  bool testHitDetection(rive.Artboard shipArtboard) {
    var minionHasHitShip = false;
    for (var minion in minionProjectileList) {
      if (!minion.isDone && minion.testHitDetection(shipArtboard)) {
        minionHasHitShip = true;
        minion.dispose();
        minionsReadyToBeRemoved.add(minion);
      }
    }
    return minionHasHitShip;
  }

  void removeDeadMinions() {
    minionProjectileList.removeAll(minionsReadyToBeRemoved);
    minionsReadyToBeRemoved.clear();
  }

  void dispose() {
    artboard.dispose();
    stateMachine.dispose();
    // Dispose any leftover Rive references in the Boss minions
    for (var minion in minionProjectileList) {
      minion.dispose();
    }
  }
}
