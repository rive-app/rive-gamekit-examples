import 'package:joel/dynamic_scene_object.dart';

class Ending extends DynamicSceneObject {
  final double _height;
  Ending({
    required super.scene,
    required super.artboard,
    required super.machine,
    required super.offset,
  }) : _height = artboard.bounds.height;

  double _endingTime = 0;

  bool get isOver => _endingTime > 8;

  bool get reachedEnd => _endingTime > 0;

  @override
  bool advance(double elapsedSeconds) {
    if (scene.character.offset.y > offset.y + _height / 3) {
      machine.number('NumTruck')?.value = 1;
      _endingTime += elapsedSeconds;
    }
    return true;
  }

  @override
  void dispose() {
    // Artboard and Machine are owned by scene.
  }
}
