import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class Bug {
  final rive.Artboard artboard;
  final rive.StateMachine stateMachine;
  final rive.AABB bounds;
  late rive.Vec2D position;

  late rive.BooleanInput isAlive;
  late rive.TriggerInput shoot;

  double _deadTime = 0;

  double timeSinceMoveDown = 0;
  final double timeTillMoveDown = 10;

  Bug(
    this.artboard,
    this.stateMachine, {
    required this.bounds,
    required this.position,
  })  : isAlive = stateMachine.boolean("isAlive")!,
        shoot = stateMachine.trigger("Shoot")! {
    var center = bounds.center();
    artboard.renderTransform = rive.Mat2D.fromTranslation(
        rive.Vec2D.fromValues(position.x, position.y) - center);
  }

  bool get isDead => _deadTime > 0.75;

  void advance(double elapsedSeconds) {
    if (isAlive.value == false) {
      _deadTime += elapsedSeconds;
    }
  }

  void killBug() {
    isAlive.value = false;
  }

  void fire() {
    shoot.fire();
  }

  void dispose() {
    artboard.dispose();
    stateMachine.dispose();
  }
}
