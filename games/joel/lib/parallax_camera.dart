import 'dart:ui';

import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class ParallaxCamera {
  final rive.AABB bounds;
  final rive.Mat2D viewTransform;

  ParallaxCamera(this.bounds, this.viewTransform);

  factory ParallaxCamera.fromViewTransform(
    Size viewport,
    rive.Mat2D view, {
    required rive.Vec2D scale,
  }) {
    // The operations in here scale the camera view from the center of the screen.
    // We scale by 1 on X (no change) and a value bigger than 1 on Y in order to
    // make the trees look like they move more vertically as the camera  moves.

    // Get in and out of the center of the screen.
    var rt2 = rive.Mat2D.fromTranslation(
        rive.Vec2D.fromValues(viewport.width / 2, viewport.height / 2));

    var rt = rive.Mat2D.fromTranslation(
        rive.Vec2D.fromValues(-viewport.width / 2, -viewport.height / 2));

    // The scaler.
    var sc = rive.Mat2D.fromScaling(scale);

    // Perform the transformations.
    var parallaxViewTransform = rt2.mul(sc.mul(rt.mul(rive.Mat2D.clone(view))));
    var parallaxCamera = rive.Mat2D();
    rive.Mat2D.invert(parallaxCamera, view);
    var parallaxCameraAABB = rive.AABB.fromPoints(
      [
        rive.Vec2D.fromValues(0, 0),
        rive.Vec2D.fromValues(viewport.width, 0),
        rive.Vec2D.fromValues(viewport.width, viewport.height),
        rive.Vec2D.fromValues(0, viewport.height),
      ],
      transform: parallaxCamera,
    );

    return ParallaxCamera(parallaxCameraAABB, parallaxViewTransform);
  }
}
