import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class PositionComponent extends Component<rive.Vec2D> {
  late rive.Vec2D position;

  double get x => position.x;
  double get y => position.y;

  @override
  void init([rive.Vec2D? data]) {
    position = data ?? rive.Vec2D.fromValues(0, 0);
  }

  @override
  void reset() {
    position = rive.Vec2D.fromValues(0, 0);
  }
}
