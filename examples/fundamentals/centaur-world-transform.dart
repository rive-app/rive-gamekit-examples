import 'dart:math';
import 'package:flutter/rendering.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class CentaurGame extends rive.RenderTexturePainter {
  final rive.File riveFile;

  final rive.Artboard character;
  late rive.StateMachine characterMachine;

  late rive.Component target;
  rive.Component? _characterRoot;

  double _characterX = 0;
  double _characterDirection = 1;

  CentaurGame(this.riveFile) : character = riveFile.artboard('Character')! {
    characterMachine = character.defaultStateMachine()!;
    character.frameOrigin = false;

    target = character.component('Look')!;
    _characterRoot = character.component('Character');
  }

  @override
  void dispose() {
    character.dispose();
    riveFile.dispose();
    super.dispose();
  }

  rive.Vec2D localCursor = rive.Vec2D();

  void aimAt(Offset localPosition) {
    localCursor = rive.Vec2D.fromOffset(localPosition);
  }

  rive.AABB get sceneBounds {
    final bounds = character.bounds;
    final characterWidth = bounds.width;
    return bounds.inset(-characterWidth * 5, 0);
  }

  @override
  bool paint(rive.RenderTexture texture, Size size, double elapsedSeconds) {
    var renderer = rive.Renderer.make();

    var viewTransform = renderer.computeAlignment(
      BoxFit.contain,
      Alignment.bottomCenter,
      rive.AABB.fromValues(0, 0, size.width, size.height),
      sceneBounds,
    );

    // Compute cursor in world space.
    final inverseViewTransform = rive.Mat2D();
    var worldCursor = rive.Vec2D();
    if (rive.Mat2D.invert(inverseViewTransform, viewTransform)) {
      worldCursor = inverseViewTransform * localCursor;
      // Check if we should invert the character's direction by comparing
      // the world location of the cursor to the world location of the
      // character (need to compensate by character movement, characterX).
      _characterDirection = _characterX < worldCursor.x ? 1 : -1;
      _characterRoot?.scaleX = _characterDirection;
    }

    // Control target node's world transform to follow cursor in world space
    target.worldTransform = rive.Mat2D.fromTranslation(
        worldCursor - rive.Vec2D.fromValues(_characterX, 0));

    characterMachine.advance(elapsedSeconds);
    renderer.save();
    renderer.transform(viewTransform);

    renderer.save();
    renderer.translate(_characterX, 0);
    character.draw(renderer);
    renderer.restore();

    renderer.restore();

    return true;
  }
}
