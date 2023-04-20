import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

/// Stores the velocity of an entity.
class VelocityComponent extends Component<rive.Vec2D> {
  /// The current velocity
  late rive.Vec2D velocity;

  /// The goal velocity
  late rive.Vec2D goal;

  double get x => velocity.x;
  double get y => velocity.y;

  void approach(double dt) {
    velocity.x = _approach(goal.x, velocity.x, dt);
    velocity.y = _approach(goal.y, velocity.y, dt);
  }

  double _approach(double goal, double current, double dt) {
    var dif = goal - current;
    if (dif > dt) {
      return current + dt;
    }
    if (dif < -dt) {
      return current - dt;
    }
    return goal;
  }

  @override
  void init([rive.Vec2D? data]) {
    velocity = data ?? rive.Vec2D.fromValues(0, 0);
    goal = data ?? rive.Vec2D.fromValues(0, 0);
  }

  @override
  void reset() {
    velocity = rive.Vec2D.fromValues(0, 0);
    goal = rive.Vec2D.fromValues(0, 0);
  }
}
