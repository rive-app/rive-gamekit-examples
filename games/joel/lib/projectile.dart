import 'dart:math';
import 'dart:ui' as ui;

import 'package:joel/dynamic_scene_object.dart';
import 'package:joel/hero.dart';
import 'package:joel/scene.dart';
import 'package:joel/zombie.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

/// A single projectile fired by the hero.
abstract class Projectile {
  bool get stops => true;
  final rive.RenderPath path = rive.Renderer.makePath();
  rive.RenderPaint get stroke;

  rive.Vec2D position;
  rive.Vec2D direction;
  late rive.Vec2D end;
  double get length;
  double get duration;

  bool stopped = false;
  Projectile(this.position, this.direction) {
    end = position + direction * length;
    path.moveTo(position.x, position.y);
    path.lineTo(end.x, end.y);
  }

  double life = 0;

  bool advance(Hero hero, double seconds) {
    life += seconds;
    return life > duration;
  }

  bool get isDead => life > duration;

  void dispose() {
    path.dispose();
  }

  ZombieSceneObject? hit(
      Scene scene, List<DynamicSceneObject> objects, double hitFraction);

  void stop(double t) {
    stopped = true;
    end = position + (end - position) * t;
  }

  void draw(rive.Renderer renderer) {
    renderer.drawPath(path, stroke);
  }
}

rive.Vec2D _jitter(rive.Vec2D heading, double amount) {
  var rand = Random();
  var result = rive.Vec2D();
  rive.Vec2D.normalize(
      result,
      heading +
          rive.Vec2D.fromValues((rand.nextDouble() * 2.0 - 1.0) * 0.05, 0));
  return result;
}

class MachineGunProjectile extends Projectile {
  static const List<String> soundLabels = [
    'PEW',
    'POW',
    'PING',
    'PEW',
  ];

  static final rive.RenderPaint machineGunStroke = rive.Renderer.makePaint()
    ..style = ui.PaintingStyle.stroke
    ..blendMode = ui.BlendMode.colorDodge
    ..color = const ui.Color(0xFF53FD00)
    ..thickness = 15
    ..cap = ui.StrokeCap.round;

  @override
  rive.RenderPaint get stroke => machineGunStroke;

  @override
  double get duration => 0.5;
  static const double speed = 5050;

  @override
  double get length => 120;

  MachineGunProjectile(rive.Vec2D position, rive.Vec2D direction)
      : super(position, _jitter(direction, 0.05));

  @override
  bool advance(Hero hero, double seconds) {
    if (!stopped) {
      position += direction * speed * seconds;

      end += direction * speed * seconds * 1.2;
    } else {
      position += (end - position) * min(1, seconds * 13);
    }
    life += seconds;

    path.reset();

    path.moveTo(position.x, position.y);
    path.lineTo(end.x, end.y);

    return life > duration;
  }

  @override
  ZombieSceneObject? hit(
      Scene scene, List<DynamicSceneObject> objects, double hitFraction) {
    if (objects.isEmpty) {
      return null;
    }
    var lastHit = objects.last;

    if (lastHit is ZombieSceneObject) {
      if (hitFraction != 1) {
        stop(hitFraction);
      }
      var zombieObject = lastHit;
      if (zombieObject.damage(scene.zombie, false)) {
        return zombieObject;
      }
    }
    return null;
  }
}

class RailGunProjectile extends Projectile {
  static const List<String> soundLabels = [
    'BLAM!!',
    'BLAMMO!',
    'BOOM!',
    'ZIIING!',
    'ZILCH!'
  ];
  final rive.RenderPaint railGunStroke;

  final double _length;
  @override
  rive.RenderPaint get stroke => railGunStroke;

  @override
  double get duration => 0.3;

  @override
  double get length => _length;

  static const double _startingThickness = 30;
  double _thickness = _startingThickness;

  RailGunProjectile(this._length, super.position, super.direction)
      : railGunStroke = rive.Renderer.makePaint()
          ..style = ui.PaintingStyle.stroke
          ..blendMode = ui.BlendMode.colorDodge
          ..color = const ui.Color(0xFFFD0044)
          ..thickness = _startingThickness
          ..cap = ui.StrokeCap.round;

  @override
  bool get stops => false;

  @override
  bool advance(Hero hero, double seconds) {
    var muzzle = hero.muzzle?.worldTransform ?? rive.Mat2D();
    position = hero.offset + muzzle.translation;
    direction = muzzle.xDirection;
    life += seconds;
    path.reset();
    end = position + direction * length;
    path.moveTo(position.x, position.y);
    path.lineTo(end.x, end.y);

    _thickness += (0 - _thickness) * min(1, seconds * 5);
    railGunStroke.thickness = _thickness;

    return life > duration;
  }

  @override
  void dispose() {
    super.dispose();
    railGunStroke.dispose();
  }

  @override
  ZombieSceneObject? hit(
      Scene scene, List<DynamicSceneObject> objects, double hitFraction) {
    ZombieSceneObject? deadZombie;
    if (stopped) {
      return null;
    }
    stopped = true;
    // if (!stopped) {
    //   stop(hitFraction);
    //   path.reset();
    //   path.moveTo(position.x, position.y);
    //   path.lineTo(end.x, end.y);
    // } else {
    //   return null;
    // }
    for (final object in objects) {
      if (object is ZombieSceneObject) {
        var zombieObject = object;
        for (int i = 0; i < 6; i++) {
          if (zombieObject.damage(scene.zombie, true)) {
            deadZombie = zombieObject;
            break;
          }
        }
      }
    }
    return deadZombie;
  }
}
