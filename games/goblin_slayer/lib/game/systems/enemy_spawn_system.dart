import 'dart:math';
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:goblin_slayer/aabb_tree.dart';
import 'package:goblin_slayer/game/components/artboard_component.dart';
import 'package:goblin_slayer/game/components/club_component.dart';
import 'package:goblin_slayer/game/components/collision_component.dart';
import 'package:goblin_slayer/game/components/enemy_component.dart';
import 'package:goblin_slayer/game/components/number_input_component.dart';
import 'package:goblin_slayer/game/components/player_component.dart';
import 'package:goblin_slayer/game/components/position_component.dart';
import 'package:goblin_slayer/game/components/speed_component.dart';
import 'package:goblin_slayer/game/components/state_machine_component.dart';
import 'package:goblin_slayer/game/components/tree_proxy_component.dart';
import 'package:goblin_slayer/game/components/trigger_input_component.dart';
import 'package:goblin_slayer/game/constants.dart';
import 'package:goblin_slayer/game/state/game_state.dart';
import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import 'package:goblin_slayer/extensions/input.dart';
import 'package:uuid/uuid.dart';

/// This system spawns enemies and moves them around the screen.
class EnemySpawnSystem extends System {
  late rive.File file;

  static const minSpeed = 2; // minimum speed of enemies

  late AABBTree tree;
  late final GameState _gameState;

  late Query playerQuery;
  late Query enemyQuery;
  late Query clubQuery;
  late Entity player;

  static const maxEnemies = 200;

  @override
  void init() {
    _initEnemyData();
    playerQuery = createQuery([
      Has<PlayerComponent>(),
    ]);
    enemyQuery = createQuery([
      Has<EnemyComponent>(),
    ]);
    clubQuery = createQuery([
      Has<ClubComponent>(),
    ]);

    _gameState = world!.gameState;

    player = playerQuery.entities.first;

    tree = world!.retrieve<AABBTree>(Constants.tree)!;

    _gameState.statusValueNotifier.addListener(_gameStateChanged);
  }

  final Stopwatch _enemyCooloff = Stopwatch()..start();
  final Random rand = Random();

  void _gameStateChanged() {
    if (_gameState.status == GameStatus.playing &&
        _gameState.previousGameStatus == GameStatus.gameOver) {
      final clubs = createQuery([Has<ClubComponent>()]);
      for (final element in clubs.entities) {
        element.dispose();
      }
      final enemies = createQuery([Has<EnemyComponent>()]);
      enemies.entities.forEach(world!.entityManager.removeEntity);
      tree.clear();
    }
  }

  @override
  void execute(double delta) {
    if (!_gameState.shouldAdvance) return;

    final playerPosition = player.get<PositionComponent>()!.position;
    final enemies = enemyQuery.entities;
    for (var element in enemies) {
      if (element.get<EnemyComponent>()!.isDead) {
        continue; // dead enemies don't move
      }

      final position = element.get<PositionComponent>()!.position;
      final directionInputComponent = element.get<NumberInputComponent>();

      final direction = playerPosition - position;

      // Set enemy direction
      {
        final angle = direction.atan2();
        bool playerAbove = angle < 0; // player is above the enemy

        if (angle.abs() < pi / 4) {
          directionInputComponent!.numberInput.value = 2;
        } else if (angle.abs() < pi * 3 / 4) {
          directionInputComponent!.numberInput.value = playerAbove ? 1 : 3;
        } else {
          directionInputComponent!.numberInput.value = 4;
        }
      }

      // Move enemy towards player
      {
        if (direction.length() > 200)
        // Move towards player
        {
          direction.norm();
          final speed = element.get<SpeedComponent>()!.value!;
          element.get<PositionComponent>()!.position +=
              direction * (100.0 * speed * delta);
          final bounds = element.get<ArtboardComponent>()!.artboard.bounds;
          final proxy = element.get<TreeProxyComponent>()!.value!;
          try {
            tree.placeProxy(proxy, bounds.translate(position), padding: 100);
          } catch (e) {
            debugPrint(e.toString());
          }
        }
        // Attack player
        else {
          final enemy = element.get<EnemyComponent>()!;
          if (enemy.attackCooldown.isReady) {
            final attackInput =
                element.get<TriggerInputsComponent>()!.triggers['attack']!;
            attackInput.fire();

            if (player.get<PlayerComponent>()!.isAlive) {
              world!.createEntity()
                ..add<ClubComponent, String>(enemy.enemyName)
                ..add<CollisionComponent, rive.AABB>(rive.AABB())
                ..add<PositionComponent, rive.Vec2D>(position);
            }

            enemy.attackCooldown.startCooldown();
          } else {
            enemy.attackCooldown.update();
          }
        }
      }
    }

    // Update clubs (enemy attacks)
    {
      for (final club in clubQuery.entities) {
        final clubComponent = club.get<ClubComponent>()!;
        final parent =
            world!.entityManager.getEntityByName(clubComponent.parentName!);
        if (clubComponent.shouldDestroy ||
            (parent?.get<EnemyComponent>()?.isDead ?? false)) {
          club.dispose();
        } else {
          _attackAnimation(club);
        }
      }
    }

    _conditionalSpawn();
  }

  void _attackAnimation(Entity club) {
    final parentName = club.get<ClubComponent>()!.parentName!;
    final enemyEntity = world!.entityManager.getEntityByName(parentName);
    if (enemyEntity == null) return;

    final enemy = enemyEntity.get<EnemyComponent>()!;
    final enemyPosition = enemyEntity.get<PositionComponent>()!.position;
    final enemyDirection =
        enemyEntity.get<NumberInputComponent>()!.numberInput.value;

    const lowerTimeInterval = 0.3;
    const upperTimeInterval = 0.5;

    if (enemy.attackCooldown.progress < lowerTimeInterval ||
        enemy.attackCooldown.progress > upperTimeInterval) {
      club.get<CollisionComponent>()!.value = rive.AABB();
      return;
    }

    const t = Interval(
      lowerTimeInterval,
      upperTimeInterval,
      curve: Curves.easeIn,
    );

    late rive.Vec2D clubHitBoxStart;
    late rive.Vec2D clubHitBoxEnd;
    late rive.AABB clubBounds;

    switch (enemyDirection.toInt()) {
      // UP
      case 1:
        clubHitBoxStart = rive.Vec2D.fromValues(400, 50);
        clubHitBoxEnd = rive.Vec2D.fromValues(200, 50);
        clubBounds = rive.AABB.fromMinMax(
          rive.Vec2D.fromValues(0, 0),
          rive.Vec2D.fromValues(10, 200),
        );
        break;
      // RIGHT
      case 2:
        clubHitBoxStart = rive.Vec2D.fromValues(300, 400);
        clubHitBoxEnd = rive.Vec2D.fromValues(300, 200);
        clubBounds = rive.AABB.fromMinMax(
          rive.Vec2D.fromValues(0, 0),
          rive.Vec2D.fromValues(200, 10),
        );
        break;
      // DOWN
      case 3:
        clubHitBoxStart = rive.Vec2D.fromValues(50, 300);
        clubHitBoxEnd = rive.Vec2D.fromValues(250, 300);
        clubBounds = rive.AABB.fromMinMax(
          rive.Vec2D.fromValues(0, 0),
          rive.Vec2D.fromValues(10, 200),
        );
        break;
      // LEFT
      case 4:
        clubHitBoxStart = rive.Vec2D.fromValues(30, 400);
        clubHitBoxEnd = rive.Vec2D.fromValues(30, 200);
        clubBounds = rive.AABB.fromMinMax(
          rive.Vec2D.fromValues(0, 0),
          rive.Vec2D.fromValues(200, 10),
        );
        break;
      default:
    }
    club.get<CollisionComponent>()!.value = clubBounds;

    final swingProgress = t.transform(enemy.attackCooldown.progress);
    final movingHitbox = rive.Vec2D.fromValues(
      lerpDouble(clubHitBoxStart.x, clubHitBoxEnd.x, swingProgress)!,
      lerpDouble(clubHitBoxStart.y, clubHitBoxEnd.y, swingProgress)!,
    );
    club.get<PositionComponent>()?.position = enemyPosition + movingHitbox;
  }

  Future<void> _initEnemyData() async {
    final data = await rootBundle.load('assets/goblin.riv');
    final bytes = data.buffer.asUint8List();
    file = rive.File.decode(bytes)!;
  }

  void _conditionalSpawn() {
    if (!_gameState.isPlaying ||
        _enemyCooloff.elapsedMilliseconds < world!.gameState.spawnCooldown ||
        enemyQuery.entities.length >= maxEnemies) {
      return;
    }
    _enemyCooloff
      ..reset()
      ..start();

    _spawn();
    _spawn();
  }

  void _spawn() {
    _enemyCooloff
      ..reset()
      ..start();

    final artboard = file.artboard("goblin solos")!;
    final stateMachine = artboard.defaultStateMachine()!;
    final direction = stateMachine.number('Direction')!;
    final deadInput = stateMachine.trigger('dead')!;
    final attackInput = stateMachine.trigger('attack')!;

    final worldSize = world!.worldSize;

    final spawnDirection = rand.nextInt(4) + 1;

    late rive.Vec2D position;
    switch (spawnDirection) {
      // UP
      case 1:
        position = rive.Vec2D.fromValues(
          rand.nextDouble() * worldSize.width * 1.5,
          -500 - (rand.nextDouble() * 900),
        );
        break;
      // RIGHT
      case 2:
        position = rive.Vec2D.fromValues(
          worldSize.width + rand.nextDouble() * 900,
          rand.nextDouble() * worldSize.height * 1.5,
        );
        break;
      // DOWN
      case 3:
        position = rive.Vec2D.fromValues(
          rand.nextDouble() * worldSize.width * 1.5,
          worldSize.height + rand.nextDouble() * 900,
        );
        break;
      // LEFT
      case 4:
        position = rive.Vec2D.fromValues(
          -500 - rand.nextDouble() * 900,
          rand.nextDouble() * worldSize.height * 1.5,
        );
        break;
      default:
        break;
    }

    final bounds = artboard.bounds;
    final collisionBounds = rive.AABB.fromValues(0, 0, 200, 150);

    const uuid = Uuid();
    final goblinName = uuid.v4();
    final goblin = world!.createEntity(goblinName)
      ..add<EnemyComponent, String>(goblinName)
      ..add<PositionComponent, rive.Vec2D>(position)
      ..add<CollisionComponent, rive.AABB>(
        collisionBounds.translate(
          rive.Vec2D.fromValues(bounds.centerX - collisionBounds.centerX,
              bounds.centerY - collisionBounds.centerY + 50),
        ),
      )
      ..add<SpeedComponent, int>(minSpeed + rand.nextInt(2))
      ..add<ArtboardComponent, rive.Artboard>(artboard)
      ..add<StateMachineComponent, rive.StateMachine>(stateMachine)
      ..add<NumberInputComponent, rive.NumberInput>(direction)
      ..add<TriggerInputsComponent, Map<String, rive.TriggerInput>>({
        'dead': deadInput,
        'attack': attackInput,
      });

    final proxyId = tree.createProxy(bounds.translate(position), goblin);

    goblin.add<TreeProxyComponent, int>(proxyId);
  }

  @override
  void dispose() {
    file.dispose();
    _gameState.statusValueNotifier.removeListener(_gameStateChanged);
    super.dispose();
  }
}
