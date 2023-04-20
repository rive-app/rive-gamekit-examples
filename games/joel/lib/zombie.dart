import 'dart:math';
import 'dart:ui';

import 'package:joel/dynamic_scene_object.dart';
import 'package:joel/scene.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

var _rand = Random();

/// A specialization of DynamicSceneObject with logic specific to Zombie
/// StaetMachine input handling for walking, multiple skin switching, taking
/// damage, etc.
class ZombieSceneObject extends DynamicSceneObject {
  final rive.NumberInput pose;
  final rive.NumberInput hit;
  final rive.BooleanInput deadMachineGun;
  final rive.BooleanInput deadRailGun;
  rive.TriggerInput? hitLeft;
  rive.TriggerInput? hitRight;
  final List<rive.TriggerInput> bulletHits;
  int _bulletHit = 0;
  double phase = 0;
  double originalX;
  static final Random _rand = Random();
  bool _isRunning = false;

  static ZombieSceneObject? make({
    required Scene scene,
    required rive.File file,
    required double y,
    required Size range,
    required double pad,
  }) {
    var male = _rand.nextBool();
    const skinCount = 8;
    var skin = _rand.nextInt(skinCount) + 1;

    var artboard = file.artboard(
      male ? 'Male Zombie $skin' : 'Female Zombie $skin',
    );
    if (artboard == null) {
      return null;
    }
    artboard.frameOrigin = false;

    var retry = 40;
    for (int r = 0; r < retry; r++) {
      bool valid = true;
      var offset = rive.Vec2D.fromValues(pad + _rand.nextDouble() * range.width,
          y + _rand.nextDouble() * range.height);
      var aabb = artboard.bounds.offset(offset.x, offset.y);
      aabb = rive.AABB.pad(aabb, -180);

      scene.tree.query(aabb, (proxy, object) {
        switch (object.classification) {
          case SceneClassification.character:
            valid = false;
            return false;
          default:
            return true;
        }
      });
      if (valid || (r == retry - 1)) {
        var stateMachine = artboard.defaultStateMachine()!;

        return ZombieSceneObject(
          scene: scene,
          artboard: artboard,
          machine: stateMachine,
          offset: offset,
        );
      }
    }

    // Failed to find a spot for this zombie.
    artboard.dispose();
    return null;
  }

  ZombieSceneObject({
    required super.scene,
    required super.artboard,
    required super.machine,
    required super.offset,
  })  : pose = machine.number('Pose')!,
        hit = machine.number('Hit')!,
        deadMachineGun = machine.boolean('IsDeath')!,
        deadRailGun = machine.boolean('Death_2')!,
        originalX = offset.x,
        bulletHits = [
          machine.trigger('Bullet_1')!,
          machine.trigger('Bullet_2')!,
          machine.trigger('Bullet_3')!,
        ] {
    var poseValue = _rand.nextInt(5).toDouble();
    _isRunning = poseValue == 4;
    pose.value = poseValue;
    phase = _rand.nextDouble() * 2 * pi;
    machine.number('NumDeath')?.value = _rand.nextInt(8).toDouble();
    machine.advance(_rand.nextDouble() * 12.3);
    hitLeft = machine.trigger('hitLeft');
    hitRight = machine.trigger('hitRight');
  }
  bool _isDead = false;
  bool get isDead => _isDead;

  @override
  bool advance(double elapsedSeconds) {
    if (_isDead) {
      return true;
    }
    double speed = _isRunning ? 250 : 100;
    phase += elapsedSeconds;
    if (!scene.character.isDead &&
        (offset - scene.character.offset).squaredLength() < 600 * 600) {
      var d = scene.character.offset - offset;
      d.norm();
      d.y = -1;
      move(d * elapsedSeconds * speed);
      originalX = offset.x;
      phase = 0;
      // move(rive.Vec2D.fromValues((originalX + d * 2) - offset.x,
      //     elapsedSeconds * -100 * _rand.nextDouble()));
    } else if (scene.character.isDead &&
        (offset - scene.character.offset).squaredLength() < 600 * 600) {
      var d = offset - scene.character.offset;
      d.norm();
      d.y = -1;
      move(d * elapsedSeconds * speed);
      originalX = offset.x;
      phase = 0;
    } else {
      move(rive.Vec2D.fromValues(
          (originalX + sin(phase * 0.5) * 100) - offset.x,
          elapsedSeconds * -speed * _rand.nextDouble()));
    }
    return true;
  }

  @override
  void draw(rive.Renderer renderer) {
    renderer.save();
    renderer.translate(offset.x, offset.y);
    artboard.draw(renderer);
    renderer.restore();
  }

  static const List<String> machineGunText = [
    'SPLAT!!',
    'SQUISH!',
    'SPROOCH!!',
    'BYEEE!!',
    'WHOMP!',
    'SCHLIP!!',
    'SCRUNCH!',
    'SPLUT!',
    'SPOOT!',
    'SMASH!!',
    'SLAM!',
    'SLASH!!',
  ];
  static const List<String> railGunText = [
    'ZAP!!',
    'FLOOMP!!',
    'VOOSH!!',
    'FLASH!',
    'FLUSH!!',
    'FLUMP!',
    'ZIP!',
    'ZOOM!',
    'ZLOPP!!',
    'VOOMP!',
    'FZZZZ!!',
    'WHOMP!!',
    'WTF?!',
    'FZZT!!'
  ];

  bool damage(rive.File file, bool isRailGun) {
    if (_bulletHit < bulletHits.length && _rand.nextBool()) {
      bulletHits[_bulletHit].fire();
      _bulletHit++;
      return _isDead;
    }
    if (_isDead) {
      return _isDead;
    }
    if (hit.value == 2) {
      scene.character.kills++;
      if (isRailGun) {
        artboard.setText(
            'Zap',
            railGunText[_rand.nextInt(railGunText.length)] +
                ' x${scene.character.kills}');
        deadRailGun.value = _isDead = true;
      } else {
        artboard.setText(
            'Splat',
            machineGunText[_rand.nextInt(machineGunText.length)] +
                ' x${scene.character.kills}');
        deadMachineGun.value = _isDead = true;
      }
      return _isDead;
    }
    hit.value += 1;
    if (hit.value == 2 && _rand.nextBool()) {
      // Lose arm or part:
      var partOption = ['Arm', 'Leg', 'Leg bone'];
      var artboard =
          file.artboard(partOption[_rand.nextInt(partOption.length)]);

      if (artboard != null) {
        artboard.frameOrigin = false;
        scene.add(
          ArmSceneObject(
            scene: scene,
            artboard: artboard,
            machine: artboard.defaultStateMachine()!,
            offset: offset,
          ),
        );
      }
    }
    return false;
  }
}

class HeadSceneObject extends DynamicSceneObject {
  final rive.NumberInput rot2D;
  final rive.NumberInput rot3D;
  final double speedX, speedY;
  final rive.Vec2D velocity;
  HeadSceneObject({
    required super.scene,
    required super.artboard,
    required super.machine,
    required super.offset,
  })  : rot2D = machine.number('numRot2D')!,
        rot3D = machine.number('numRot3D')!,
        speedX = 10 + _rand.nextDouble() * 15,
        speedY = 10 + _rand.nextDouble() * 15,
        velocity = rive.Vec2D.fromValues(-600 + _rand.nextDouble() * 1200,
            -1300 - _rand.nextDouble() * 700) {
    machine.boolean('Direction')?.value = _rand.nextBool();
  }

  double scale = 1.0;

  @override
  bool advance(double elapsedSeconds) {
    if (scale > 10) {
      return false;
    }
    scale += elapsedSeconds * 4;
    rot2D.value += elapsedSeconds * speedX;
    rot3D.value += elapsedSeconds * speedY;
    offset += velocity * elapsedSeconds;
    var updatedBounds = artboard.bounds;
    updatedBounds[0] *= scale;
    updatedBounds[1] *= scale;
    updatedBounds[2] *= scale;
    updatedBounds[3] *= scale;
    bounds = updatedBounds.offset(offset.x, offset.y);
    scene.tree.placeProxy(
      sceneTreeProxy,
      aabb,
      padding: 100,
    );
    artboard.renderTransform = renderTransform;
    return true;
  }

  @override
  rive.Mat2D get renderTransform {
    var transform = rive.Mat2D.fromTranslate(offset.x, offset.y);
    transform[0] = scale;
    transform[3] = scale;
    return transform;
  }

  @override
  SceneClassification get classification => SceneClassification.sky;

  @override
  void draw(rive.Renderer renderer) {
    renderer.save();
    renderer.transform(renderTransform);
    artboard.draw(renderer);
    renderer.restore();
  }
}

class ArmSceneObject extends DynamicSceneObject {
  final rive.NumberInput rotation;
  final rive.TriggerInput done;
  final double speedX, speedY;
  double z = 0;
  double speedZ = 6;
  final rive.Vec2D velocity;
  rive.Vec2D logicalOffset;
  ArmSceneObject({
    required super.scene,
    required super.artboard,
    required super.machine,
    required rive.Vec2D offset,
  })  : rotation = machine.number('numAmount')!,
        done = machine.trigger('End')!,
        speedX = (_rand.nextBool() ? -1 : 1) * 20 + _rand.nextDouble() * 15,
        speedY = 10 + _rand.nextDouble() * 15,
        velocity = rive.Vec2D.fromValues(-600 + _rand.nextDouble() * 1200, 0),
        logicalOffset = offset,
        super(offset: rive.Vec2D.clone(offset)) {
    machine.boolean('IsDirection')?.value = _rand.nextBool();
    if (speedX < 0) {
      rotation.value = 100;
    }
  }

  double scale = 1.0;
  bool isDone = false;
  double doneTime = 0;

  @override
  SceneClassification get classification =>
      z > 1 ? SceneClassification.sky : SceneClassification.character;

  @override
  bool advance(double elapsedSeconds) {
    // if (scale > 10) {
    //   return false;
    // }
    // scale += elapsedSeconds * 4;

    if (isDone) {
      doneTime += elapsedSeconds;
      if (doneTime > 2) {
        return false;
      }
    } else {
      speedZ += -9.8 * elapsedSeconds;
      rotation.value += elapsedSeconds * speedX;
      z += speedZ * elapsedSeconds;
      logicalOffset += velocity * elapsedSeconds;
      offset.x = logicalOffset.x;
      offset.y = logicalOffset.y - z * 512.8;

      if (z <= 0) {
        z = 0;
        done.fire();
        isDone = true;
      }
    }

    scale = 1.0 + z * z;
    var updatedBounds = artboard.bounds;
    updatedBounds[0] *= scale;
    updatedBounds[1] *= scale;
    updatedBounds[2] *= scale;
    updatedBounds[3] *= scale;
    bounds = updatedBounds.offset(offset.x, offset.y);
    scene.tree.placeProxy(
      sceneTreeProxy,
      aabb,
      padding: 100,
    );
    artboard.renderTransform = renderTransform;
    return true;
  }

  @override
  rive.Mat2D get renderTransform {
    var transform = rive.Mat2D.fromTranslate(offset.x, offset.y);
    transform[0] = scale;
    transform[3] = scale;
    return transform;
  }

  @override
  void draw(rive.Renderer renderer) {
    renderer.save();
    renderer.transform(renderTransform);
    artboard.draw(renderer);
    renderer.restore();
  }
}
