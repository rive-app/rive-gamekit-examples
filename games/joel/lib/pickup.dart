import 'dart:math';

import 'package:joel/dynamic_scene_object.dart';

var _rand = Random();

class Pickup extends DynamicSceneObject {
  int type = 0;
  bool pickedUp = false;
  Pickup({
    required super.scene,
    required super.artboard,
    required super.machine,
    required super.offset,
    int? bulletType,
  }) {
    type = bulletType ?? _rand.nextInt(2);
    machine.number('numColor')?.value = type.toDouble();
  }

  bool pickup() {
    if (pickedUp) {
      return false;
    }
    pickedUp = true;
    machine.number('numPick')?.value = 1;
    return true;
  }
}
