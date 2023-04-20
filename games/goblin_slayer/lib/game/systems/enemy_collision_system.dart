import 'dart:collection';

import 'package:goblin_slayer/aabb_tree.dart';
import 'package:goblin_slayer/extensions/input.dart';
import 'package:goblin_slayer/game/components/collision_component.dart';
import 'package:goblin_slayer/game/components/enemy_component.dart';
import 'package:goblin_slayer/game/components/position_component.dart';
import 'package:goblin_slayer/game/components/player_attack_component.dart';
import 'package:goblin_slayer/game/components/tree_proxy_component.dart';
import 'package:goblin_slayer/game/components/trigger_input_component.dart';
import 'package:goblin_slayer/game/constants.dart';
import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import '../state/game_state.dart';

class EnemyCollisionSystem extends System {
  late final Query weaponQuery;
  late final Query enemyQuery;
  late final AABBTree<Entity> tree;
  late final GameState _gameState;

  @override
  void init() {
    tree = world!.retrieve(Constants.tree);
    _gameState = world!.gameState;

    weaponQuery = createQuery([
      Has<PlayerAttackComponent>(),
    ]);
    enemyQuery = createQuery([
      Has<EnemyComponent>(),
    ]);

    _gameState.statusValueNotifier.addListener(onGameStateChange);
  }

  void onGameStateChange() {
    if (_gameState.status == GameStatus.gameOver) {
      _deadEnemies.clear();
      _enemiesToRemove.clear();
    }
  }

  final HashSet<Entity> _deadEnemies = HashSet();
  final HashSet<Entity> _enemiesToRemove = HashSet();

  @override
  void execute(double delta) {
    if (!_gameState.isPlaying) return;

    for (final element in _enemiesToRemove) {
      final proxyId = element.get<TreeProxyComponent>()!.value!;
      _deadEnemies.remove(element);
      tree.removeLeaf(proxyId);
      world!.entityManager.removeEntity(element);
    }

    _enemiesToRemove.clear();

    for (final deadEnemy in _deadEnemies) {
      final enemy = deadEnemy.get<EnemyComponent>()!;

      enemy.deathCooldown.update();

      if (enemy.deathCooldown.isDone) {
        _enemiesToRemove.add(deadEnemy);
      }
    }

    if (weaponQuery.entities.isEmpty) {
      return;
    }

    final weapon = weaponQuery.entities.first;
    final weaponPosition = weapon.get<PositionComponent>()!.position;
    final weaponAABB = weapon.get<CollisionComponent>()!.value!;
    final weaponBounds = weaponAABB.offset(weaponPosition.x, weaponPosition.y);
    final playerAttackComponent = createQuery([
      Has<PlayerAttackComponent>(),
    ]).entities.first.get<PlayerAttackComponent>()!;

    tree.query(weaponBounds, (id, object) {
      if (object.has<EnemyComponent>()) {
        final enemy = object.get<EnemyComponent>()!;
        if (enemy.isDead) {
          return true;
        }

        final enemyPosition = object.get<PositionComponent>()!.position;
        final collisionBounds = object.get<CollisionComponent>()!.value!.offset(
              enemyPosition.x,
              enemyPosition.y,
            );

        if (rive.AABB.testOverlap(weaponBounds, collisionBounds)) {
          _deadEnemies.add(object);
          object.get<TriggerInputsComponent>()!.triggers['dead']!.fire();
          enemy.deathCooldown.startCooldown();

          // Only increase the special build up if the player is not using
          // the special attack.
          if (!playerAttackComponent.value!) {
            _gameState.increaseSpecialBuildUp();
          }
        }
      }
      return true;
    });
  }

  @override
  void dispose() {
    _gameState.statusValueNotifier.removeListener(onGameStateChange);
    super.dispose();
  }
}
