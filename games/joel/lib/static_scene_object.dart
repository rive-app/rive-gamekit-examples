import 'package:rive_gamekit/rive_gamekit.dart' as rive;
import 'package:joel/scene.dart';

/// A Rive Artboard that is placed at a location in the scene and doesn't move
/// for the duration fo the entire game.
class StaticSceneObject extends SceneObject {
  final rive.Artboard artboard;
  final rive.AABB bounds;
  final rive.Vec2D offset;

  @override
  rive.AABB get aabb => bounds;

  StaticSceneObject(this.artboard, this.offset)
      : bounds = artboard.bounds.offset(offset.x, offset.y);

  @override
  SceneClassification get classification => SceneClassification.ground;

  @override
  rive.Mat2D get renderTransform => rive.Mat2D.fromTranslation(offset);

  @override
  void draw(rive.Renderer renderer) {
    renderer.save();
    renderer.translate(offset.x, offset.y);
    artboard.draw(renderer);
    renderer.restore();
  }
}
