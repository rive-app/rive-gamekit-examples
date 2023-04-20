import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

/// A component that holds a collision box - [rive.AABB]
class CollisionComponent extends ValueComponent<rive.AABB> {
  bool didCollideLastFrame = false;
  CollisionDirection obstacleCollisionDirection = CollisionDirection.none;
}

/// The direction of the collision.
enum CollisionDirection { left, right, up, down, none }
