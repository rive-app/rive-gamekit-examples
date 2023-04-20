import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:goblin_slayer/extensions/cooldowns.dart';
import 'package:goblin_slayer/extensions/input.dart';
import 'package:goblin_slayer/game/components/artboard_component.dart';
import 'package:goblin_slayer/game/components/boolean_input_component.dart';
import 'package:goblin_slayer/game/components/collision_component.dart';
import 'package:goblin_slayer/game/components/number_input_component.dart';
import 'package:goblin_slayer/game/components/position_component.dart';
import 'package:goblin_slayer/game/components/trigger_input_component.dart';
import 'package:goblin_slayer/game/components/velocity_component.dart';
import 'package:goblin_slayer/game/components/player_attack_component.dart';
import 'package:goblin_slayer/game/constants.dart';
import 'package:goblin_slayer/game/state/game_state.dart';
import 'package:oxygen/oxygen.dart';

import 'package:rive_gamekit/rive_gamekit.dart' as rive;
import '../components/player_component.dart';

/// Player control system. Handles player input and movement.
class PlayerControlSystem extends System with InputSystem {
  late Query playerQuery;
  late AttackCooldown attackCooldown;
  late final Entity player;
  late final PlayerComponent playerComponent;
  late final GameState _gameState;

  PlayerControlSystem({super.priority = 1});

  static const movementSpeed = 4.5;
  static const attackCooldownDuration = Duration(milliseconds: 750);

  @override
  void init() {
    attackCooldown = AttackCooldown(
      attackCooldownDuration,
      onCooldownComplete: _onAttackCoolDownComplete,
    );
    playerQuery = createQuery([
      Has<PlayerComponent>(),
    ]);
    player = playerQuery.entities.first;
    playerComponent = player.get<PlayerComponent>()!;
    _gameState = world!.gameState;

    player.get<NumberInputComponent>()!.numberInput.value =
        PlayerDirection.down.input;

    _gameState.statusValueNotifier.addListener(_gameStateChanged);
  }

  // This is used to ensure the player does not get stuck in a corner when
  // colliding from multiple directions.
  CollisionDirection _previousCollisionDirection = CollisionDirection.none;

  bool get _doNotExecute => !_gameState.isPlaying || playerComponent.isDead;

  void _gameStateChanged() {
    if (_gameState.isNewGame) {
      resetPlayer();
    }
  }

  void resetPlayer() {
    _pressedKeys.clear();
    final velocityComponent = player.get<VelocityComponent>()!;
    final positionComponent = player.get<PositionComponent>()!;
    final directionInput = player.get<NumberInputComponent>()!.numberInput;
    final isMovingInput = player.get<BooleanInputComponent>()!.booleanInput;
    velocityComponent.velocity = rive.Vec2D.fromValues(0, 0);
    velocityComponent.goal = rive.Vec2D.fromValues(0, 0);
    positionComponent.position = rive.Vec2D.fromValues(
        world!.worldSize.width / 2, world!.worldSize.height / 2);
    directionInput.value = PlayerDirection.down.input;
    isMovingInput.value = false;

    playerComponent.alive();
    player
        .get<TriggerInputsComponent>()!
        .triggers[Constants.playerDeathInput]!
        .fire();
  }

  @override
  void execute(double delta) {
    if (_doNotExecute) {
      return;
    }

    final velocityComponent = player.get<VelocityComponent>()!;
    velocityComponent.approach(delta * 15);

    attackCooldown.update();

    final positionComponent = player.get<PositionComponent>()!;
    final collisionComponent = player.get<CollisionComponent>()!;

    _setAttackBounds(player.get<PositionComponent>()!.position);

    final normalVelocity = rive.Vec2D();
    rive.Vec2D.copy(normalVelocity, player.get<VelocityComponent>()!.velocity);
    normalVelocity.norm();
    final adjustment = (normalVelocity) * (delta * 100 * movementSpeed);

    switch (collisionComponent.obstacleCollisionDirection) {
      case CollisionDirection.none:
        positionComponent.position += adjustment;
        break;

      case CollisionDirection.up:
      case CollisionDirection.down:
        if (_previousCollisionDirection == CollisionDirection.left ||
            _previousCollisionDirection == CollisionDirection.right) {
          positionComponent.position += adjustment;
        } else {
          positionComponent.position += rive.Vec2D.fromValues(adjustment.x, 0);
        }
        break;

      case CollisionDirection.left:
      case CollisionDirection.right:
        if (_previousCollisionDirection == CollisionDirection.up ||
            _previousCollisionDirection == CollisionDirection.down) {
          positionComponent.position += adjustment;
        } else {
          positionComponent.position += rive.Vec2D.fromValues(0, adjustment.y);
        }
        break;
    }
    _previousCollisionDirection = collisionComponent.obstacleCollisionDirection;
  }

  // This is used to determine which directional animation to play for the
  // player.
  final List<PlayerDirection> _pressedKeys = [];

  @override
  void onKeyEvent(KeyEvent event) {
    if (_doNotExecute) {
      return;
    }
    if (event is KeyRepeatEvent) {
      return;
    }
    final velocityComponent = player.get<VelocityComponent>()!;
    final directionInput = player.get<NumberInputComponent>()!.numberInput;
    final isMovingInput = player.get<BooleanInputComponent>()!.booleanInput;

    double speed = 0;
    late bool isKeyDown = event is KeyDownEvent;
    if (event is KeyDownEvent) {
      speed = 1;
    } else if (event is KeyUpEvent) {
      speed = -1;
    }

    late PlayerDirection dir;
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (isKeyDown) {
        _attack();
      }
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
      if (isKeyDown && _gameState.canPerformSpecialAttack()) {
        _attack(isSpecialAttack: true);
        _gameState.resetSpecialAttack();
      }
      return;
    } else if (event.logicalKey == LogicalKeyboardKey.keyA) {
      velocityComponent.goal.x += -speed;
      dir = PlayerDirection.left;
    } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
      velocityComponent.goal.x += speed;
      dir = PlayerDirection.right;
    } else if (event.logicalKey == LogicalKeyboardKey.keyW) {
      velocityComponent.goal.y += -speed;
      dir = PlayerDirection.up;
    } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
      velocityComponent.goal.y += speed;
      dir = PlayerDirection.down;
    } else {
      return;
    }

    if (isKeyDown) {
      _pressedKeys.add(dir);
    } else {
      _pressedKeys.remove(dir);
    }
    if (_pressedKeys.isNotEmpty) {
      directionInput.value = _pressedKeys.first.input;
      _swordDirection = _pressedKeys.first;
    }

    isMovingInput.value = _pressedKeys.isNotEmpty;
  }

  Entity? _playerAttackEntity;
  late PlayerDirection _swordDirection = PlayerDirection.up;

  void _setAttackBounds(rive.Vec2D position) {
    if (_playerAttackEntity == null) return; // No player attack entity.

    // Perform special attack bounds calculation.
    void specialAttack() {
      const lowerTimeInterval = 0.0;
      const upperTimeInterval = 0.3;

      if (attackCooldown.progress < lowerTimeInterval ||
          attackCooldown.progress > upperTimeInterval) {
        _playerAttackEntity!.get<CollisionComponent>()?.value = rive.AABB();

        return;
      }

      const attackBoundsStartLength = 0;
      const attackBoundsEndLength = 550;

      const t = Interval(
        lowerTimeInterval,
        upperTimeInterval,
        curve: Curves.easeOut,
      );
      final lengthInterpolation = lerpDouble(
        attackBoundsStartLength,
        attackBoundsEndLength,
        t.transform(attackCooldown.progress),
      )!;

      final attackBounds = rive.AABB.fromValues(
        -lengthInterpolation + 250,
        -lengthInterpolation * 0.7 + 250,
        lengthInterpolation + 250,
        lengthInterpolation * 0.7 + 250,
      );

      _playerAttackEntity!.get<CollisionComponent>()?.value = attackBounds;

      _playerAttackEntity!.get<PositionComponent>()?.position = position;
    }

    // Perform normal attack bounds calculation.
    void regularAttack() {
      const lowerTimeInterval = 0.3;
      const upperTimeInterval = 0.6;

      if (attackCooldown.progress < lowerTimeInterval ||
          attackCooldown.progress > upperTimeInterval) {
        _playerAttackEntity!.get<CollisionComponent>()?.value = rive.AABB();

        return;
      }

      late rive.Vec2D attackHitboxStart;
      late rive.Vec2D attackHitboxEnd;
      late rive.AABB attackBounds;

      switch (_swordDirection) {
        case PlayerDirection.left:
          attackHitboxStart = rive.Vec2D.fromValues(-150, 500);
          attackHitboxEnd = rive.Vec2D.fromValues(-150, 0);
          attackBounds = rive.AABB.fromMinMax(
            rive.Vec2D.fromValues(0, 0),
            rive.Vec2D.fromValues(300, 20),
          );
          break;
        case PlayerDirection.right:
          attackHitboxStart = rive.Vec2D.fromValues(250, 500);
          attackHitboxEnd = rive.Vec2D.fromValues(250, 0);
          attackBounds = rive.AABB.fromMinMax(
            rive.Vec2D.fromValues(0, 0),
            rive.Vec2D.fromValues(300, 20),
          );
          break;
        case PlayerDirection.up:
          attackHitboxStart = rive.Vec2D.fromValues(500, 50);
          attackHitboxEnd = rive.Vec2D.fromValues(0, 50);
          attackBounds = rive.AABB.fromMinMax(
            rive.Vec2D.fromValues(0, 0),
            rive.Vec2D.fromValues(20, 300),
          );
          break;
        case PlayerDirection.down:
          attackHitboxStart = rive.Vec2D.fromValues(-50, 220);
          attackHitboxEnd = rive.Vec2D.fromValues(450, 220);
          attackBounds = rive.AABB.fromMinMax(
            rive.Vec2D.fromValues(0, 0),
            rive.Vec2D.fromValues(20, 300),
          );
          break;
      }

      const t = Interval(
        lowerTimeInterval,
        upperTimeInterval,
        curve: Curves.easeIn,
      );
      final swingProgress = t.transform(attackCooldown.progress);
      final movingHitbox = rive.Vec2D.fromValues(
        lerpDouble(attackHitboxStart.x, attackHitboxEnd.x, swingProgress)!,
        lerpDouble(attackHitboxStart.y, attackHitboxEnd.y, swingProgress)!,
      );

      _playerAttackEntity!.get<CollisionComponent>()?.value = attackBounds;

      _playerAttackEntity!.get<PositionComponent>()?.position =
          position + movingHitbox;
    }

    final playerAttackComponent =
        _playerAttackEntity!.get<PlayerAttackComponent>()!;

    if (playerAttackComponent.value == true) {
      specialAttack();
    } else {
      regularAttack();
    }
  }

  void _onAttackCoolDownComplete() {
    _playerAttackEntity?.dispose();
    _playerAttackEntity = null;
  }

  void _attack({bool isSpecialAttack = false}) {
    if (!attackCooldown.isReady) {
      return;
    } else {
      _playerAttackEntity?.dispose();
      attackCooldown.startCooldown();
    }

    final bounds = rive.AABB();

    _playerAttackEntity = world!.createEntity()
      ..add<PlayerAttackComponent, bool>(isSpecialAttack)
      ..add<CollisionComponent, rive.AABB>(
        bounds,
      )
      ..add<PositionComponent, rive.Vec2D>(
        player.get<PositionComponent>()!.position +
            player.get<ArtboardComponent>()!.artboard.bounds.center(),
      );

    if (isSpecialAttack) {
      player
          .get<TriggerInputsComponent>()!
          .triggers[Constants.playerSpecialAttackInput]
          ?.fire();
    } else {
      player
          .get<TriggerInputsComponent>()!
          .triggers[Constants.playerAttackInput]
          ?.fire();
    }
  }

  @override
  void dispose() {
    _gameState.statusValueNotifier.removeListener(_gameStateChanged);
    super.dispose();
  }
}

/// Maps the state machine input for the player direction to a readable enum.
enum PlayerDirection {
  left(4),
  right(2),
  up(1),
  down(3);

  const PlayerDirection(this.input);
  final double input;
}
