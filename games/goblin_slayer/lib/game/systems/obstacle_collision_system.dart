import 'package:goblin_slayer/aabb_tree.dart';
import 'package:goblin_slayer/extensions/input.dart';
import 'package:goblin_slayer/game/components/artboard_component.dart';
import 'package:goblin_slayer/game/components/collision_component.dart';
import 'package:goblin_slayer/game/components/player_component.dart';
import 'package:goblin_slayer/game/components/position_component.dart';
import 'package:goblin_slayer/game/components/velocity_component.dart';
import 'package:goblin_slayer/game/state/game_state.dart';
import 'package:goblin_slayer/game/systems/player_control_system.dart';
import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class ObstacleCollisionSystem extends System {
  // late final Query query;
  late Entity player;
  late rive.AABB playerBounds;
  late AABBTree<Entity> _staticTree;
  late final GameState _gameState;

  ObstacleCollisionSystem({super.priority = 0});

  @override
  void init() {
    _gameState = world!.gameState;
    _staticTree = world!.retrieve<AABBTree<Entity>>('static-tree')!;
    player = createQuery([
      Has<PlayerComponent>(),
    ]).entities.first;
    playerBounds = player.get<ArtboardComponent>()!.artboard.bounds;
  }

  @override
  void execute(double delta) {
    if (!_gameState.isPlaying) return;

    final playerCollision = player.get<CollisionComponent>()!;
    playerBounds = playerCollision.value!;

    final offset = player.get<PositionComponent>()!.position;
    final nextFrameOffset = offset +
        (player.get<VelocityComponent>()!.velocity *
                delta *
                100 *
                PlayerControlSystem.movementSpeed) *
            2;

    final pBounds = playerBounds.offset(nextFrameOffset.x, nextFrameOffset.y);

    playerCollision.obstacleCollisionDirection = CollisionDirection.none;
    _staticTree.query(pBounds, (id, object) {
      if (object.has<CollisionComponent>()) {
        final collisionComponent = object.get<CollisionComponent>()!;
        final bounds = collisionComponent.value!;
        final position = object.get<PositionComponent>()!.position;
        final collisionBounds = bounds.offset(position.x, position.y);

        if (rive.AABB.testOverlap(collisionBounds, pBounds)) {
          playerCollision.obstacleCollisionDirection = detectCollisionDirection(
              collisionBounds, pBounds); // TODO: improve
        }
      }
      return true;
    });
  }
}

// Determine the direction of the collision between two AABBs
// Returns a CollisionDirection enum representing the direction of the collision
CollisionDirection detectCollisionDirection(rive.AABB aabb1, rive.AABB aabb2) {
  // Calculate the sides of aabb1
  final double left1 = aabb1.minX;
  final double right1 = aabb1.minX + aabb1.width;
  final double top1 = aabb1.minY;
  final double bottom1 = aabb1.minY + aabb1.height;

  // Calculate the sides of aabb2
  final double left2 = aabb2.minX;
  final double right2 = aabb2.minX + aabb2.width;
  final double top2 = aabb2.minY;
  final double bottom2 = aabb2.minY + aabb2.height;

  // Check for overlap in each direction
  final double overlapX = (right1 > left2 && right2 > left1)
      ? (right1 < right2 ? right1 - left2 : right2 - left1)
      : 0.0;
  final double overlapY = (bottom1 > top2 && bottom2 > top1)
      ? (bottom1 < bottom2 ? bottom1 - top2 : bottom2 - top1)
      : 0.0;

  // Determine the direction of the collision based on the overlap
  if (overlapX > overlapY) {
    return top1 < top2 ? CollisionDirection.down : CollisionDirection.up;
  } else {
    return left1 < left2 ? CollisionDirection.right : CollisionDirection.left;
  }
}
// }
