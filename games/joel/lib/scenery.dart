import 'package:joel/static_scene_object.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import 'package:joel/scene.dart';

class ShadowSceneObject extends SceneObject {
  final rive.Artboard artboard;
  final rive.AABB bounds;
  final rive.Vec2D offset;

  @override
  rive.AABB get aabb => bounds;

  ShadowSceneObject(this.artboard, this.offset)
      : bounds = artboard.bounds.offset(offset.x, offset.y);

  @override
  SceneClassification get classification => SceneClassification.shadow;

  @override
  rive.Mat2D get renderTransform => rive.Mat2D.fromTranslation(offset);

  @override
  void draw(rive.Renderer renderer) {
    /// We intentionally override draw to be empty as we special case the
    /// Shadows by pouring their paths into a single path which we explicitly
    /// draw manually with the renderer. This is to make the shodows appera
    /// contiguous. This pouring and rendering is handled in [Scene].
  }

  void addToPath(rive.RenderPath path) => artboard.addToRenderPath(
      path, rive.Mat2D.fromTranslate(offset.x, offset.y));
}

class TreeSceneObject extends StaticSceneObject {
  TreeSceneObject(super.artboard, super.offset);

  @override
  SceneClassification get classification => SceneClassification.parallax;
}

class CloudSceneObject extends StaticSceneObject {
  CloudSceneObject(super.artboard, super.offset);

  @override
  SceneClassification get classification => SceneClassification.highParallax;
}
