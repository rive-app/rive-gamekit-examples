import 'package:goblin_slayer/extensions/input.dart';
import 'package:goblin_slayer/game/components/club_component.dart';
import 'package:goblin_slayer/game/components/collision_component.dart';
import 'package:goblin_slayer/game/components/player_component.dart';
import 'package:goblin_slayer/game/components/position_component.dart';
import 'package:goblin_slayer/game/components/trigger_input_component.dart';
import 'package:goblin_slayer/game/constants.dart';
import 'package:goblin_slayer/game/state/game_state.dart';
import 'package:oxygen/oxygen.dart';

import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class PlayerCollisionSystem extends System {
  late final GameState _gameState;
  late final Query playerQuery;
  late final Entity player;
  late PlayerComponent playerComponent;
  late final Query clubQuery;

  @override
  void init() {
    _gameState = world!.gameState;
    playerQuery = createQuery([Has<PlayerComponent>()]);
    player = playerQuery.entities.first;
    playerComponent = player.get<PlayerComponent>()!;
    clubQuery = createQuery([Has<ClubComponent>()]);
  }

  @override
  void execute(double delta) {
    if (!_gameState.isPlaying) return;

    final clubEntities = clubQuery.entities;
    if (clubQuery.entities.isEmpty || playerComponent.isDead) {
      return;
    }

    final playerBounds = player.get<CollisionComponent>()!.value!;
    final playerPosition = player.get<PositionComponent>()!.position;
    for (final entity in clubEntities) {
      final clubBounds = entity.get<CollisionComponent>()!.value!;
      final clubPosition = entity.get<PositionComponent>()!.position;

      if (rive.AABB.testOverlap(
        clubBounds.offset(clubPosition.x, clubPosition.y),
        playerBounds.offset(playerPosition.x, playerPosition.y),
      )) {
        player
            .get<TriggerInputsComponent>()!
            .triggers[Constants.playerDeathInput]!
            .fire();
        player.get<PlayerComponent>()!.hit();
        _gameState.gameOver();
      }
    }
  }
}
