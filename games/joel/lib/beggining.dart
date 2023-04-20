import 'package:joel/dynamic_scene_object.dart';

class Beggining extends DynamicSceneObject {
  // final double _height;
  Beggining({
    required super.scene,
    required super.artboard,
    required super.machine,
    required super.offset,
  });

  void start() {
    machine.number('numdoor')?.value = 1;
  }

  @override
  void dispose() {
    // Artboard and Machine are owned by scene.
  }
}
