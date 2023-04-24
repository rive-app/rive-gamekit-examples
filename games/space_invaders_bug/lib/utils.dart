import 'package:rive_gamekit/rive_gamekit.dart' as rive;

rive.Vec2D getWorldPointFromLocal(rive.Mat2D localMat) {
  return rive.Vec2D.fromValues(
    localMat.values[0] * localMat.values[4] +
        localMat.values[2] * localMat.values[5] +
        localMat.values[4],
    localMat.values[1] * localMat.values[4] +
        localMat.values[3] * localMat.values[5] +
        localMat.values[5],
  );
}
