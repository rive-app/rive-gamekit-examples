import 'package:joel/scene.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

/// A Rive Artboard that can change position dynamically during gameplay within
/// the scene.
class DynamicSceneObject extends SceneObject {
  final Scene scene;
  final rive.Artboard artboard;
  final rive.StateMachine machine;
  rive.AABB bounds;
  rive.Vec2D offset;

  @override
  rive.AABB get aabb => bounds;

  DynamicSceneObject({
    required this.scene,
    required this.artboard,
    required this.machine,
    required this.offset,
  }) : bounds = artboard.bounds.offset(offset.x, offset.y) {
    artboard.renderTransform = renderTransform;
  }

  @override
  SceneClassification get classification => SceneClassification.character;

  bool advance(double elapsedSeconds) {
    return true;
  }

  void move(rive.Vec2D val) {
    offset += val;
    bounds = artboard.bounds.offset(offset.x, offset.y);
    artboard.renderTransform = renderTransform;
    scene.tree.placeProxy(
      sceneTreeProxy,
      bounds,
      padding: 100,
    );
  }

  bool get doesDraw => true;
  @override
  rive.Mat2D get renderTransform => rive.Mat2D.fromTranslation(offset);

  @override
  void draw(rive.Renderer renderer) {
    renderer.save();
    renderer.translate(offset.x, offset.y);
    artboard.draw(renderer);
    renderer.restore();
  }

  @override
  void dispose() {
    machine.dispose();
    artboard.dispose();
  }
}
