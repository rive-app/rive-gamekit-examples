import 'dart:math';

import 'package:joel/aabb_tree.dart';
import 'package:joel/pickup.dart';
import 'package:joel/projectile.dart';
import 'package:joel/scene.dart';
import 'package:joel/zombie.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;
import 'package:joel/dynamic_scene_object.dart';

enum HeroState { idle, aiming, firing, walkingAndFiring, dead }

enum HeroWeapon {
  machineGun,
  railGun,
  none,
}

Random _rand = Random();

class _OverlayEffect {
  final rive.Artboard artboard;
  final rive.StateMachine machine;
  final rive.Mat2D transform;

  int drewFrames = 0;

  _OverlayEffect(this.artboard, this.machine, this.transform) {
    artboard.renderTransform = transform;
  }

  void draw(rive.Renderer renderer) {
    renderer.save();
    renderer.transform(transform);
    artboard.draw(renderer);
    renderer.restore();
  }

  void dispose() {
    artboard.dispose();
    machine.dispose();
  }
}

/// The Hero/player character.
class Hero extends DynamicSceneObject {
  final rive.Artboard hp;
  final rive.StateMachine hpMachine;
  final rive.TriggerInput? hpHit;
  late rive.Vec2D _healthPosition;
  static final rive.Vec2D _healthTargetOffset =
      rive.Vec2D.fromValues(-240, -150);

  rive.NumberInput? aim;
  rive.TriggerInput? fire;
  rive.TriggerInput? hitLeft;
  rive.TriggerInput? hitRight;
  rive.NumberInput? walk;
  final List<rive.Vec2D> _muzzleHeadings = [];
  final List<rive.Vec2D> _muzzlePositions = [];
  final List<double> _muzzleDots = [];
  rive.Component? _helmet;
  rive.Component? _muzzle;
  rive.Component? get muzzle => _muzzle;
  double _aimTarget = 0;
  double _aimCurrent = 0;
  double endingY = 0;

  HeroWeapon _weapon = HeroWeapon.none;
  final List<Projectile> _projectiles = [];

  static const int aimIterations = 40;

  /// The world transform of the muzzle (the location of the barrel of the
  /// hero's weapon).
  rive.Vec2D get muzzleWorld =>
      (_muzzle?.worldTransform.translation ?? rive.Vec2D()) + offset;

  /// The world transform of the muzzle projected forward (along the same
  /// heading of the sight of the weapon) by [project] distance.
  rive.Vec2D projectedMuzzleWorld(double project) {
    if (_muzzle == null) {
      return offset;
    }
    var transform = _muzzle!.worldTransform;
    var translation = transform.translation;
    var heading = rive.Vec2D.fromValues(transform[0], transform[1]);
    rive.Vec2D.normalize(heading, heading);

    return offset + translation + rive.Vec2D.scale(heading, heading, project);
  }

  Hero({
    required super.scene,
    required super.artboard,
    required super.machine,
    required super.offset,
    required this.hp,
    required this.hpMachine,
  }) : hpHit = hpMachine.trigger('hit') {
    _healthPosition = offset + _healthTargetOffset;
    // We set frame origin to false so that we know that Joel's local 0,0 align
    // to wherever we draw him on the scene.
    artboard.frameOrigin = false;
    // Update all positions with frameOrigin false.
    machine.advance(0);
    bounds = artboard.bounds;
    _helmet = artboard.component('Helmet');
    _muzzle = artboard.component('muzzle');
    aim = machine.number('aim');
    fire = machine.trigger('fire');
    hitLeft = machine.trigger('hitLeft');
    hitRight = machine.trigger('hitRight');
    walk = machine.number('walk');

    // Sweep the vectors for the aim. This advances the "aim" input of the state
    // machine and extracts muzzle headings and translations at each iteration.
    // We use this to smoothly aim at specific headings at runtime.
    if (_muzzle != null && aim != null) {
      var inc = 100 / (aimIterations - 1);
      var value = 0.0;
      for (int i = 0; i < aimIterations; i++) {
        aim?.value = value;
        machine.advance(0);
        var wt = _muzzle!.worldTransform;
        var heading = rive.Vec2D.fromValues(wt[0], wt[1]);
        rive.Vec2D.normalize(heading, heading);
        _muzzleHeadings.add(heading);
        _muzzlePositions.add(rive.Vec2D.fromValues(wt[4], wt[5]));
        _muzzleDots.add(0);
        value += inc;
      }
    }
  }

  rive.Vec2D? _pointerTouch;
  rive.Vec2D _walkSpeed = rive.Vec2D();
  final rive.Vec2D _targetWalkSpeed = rive.Vec2D();
  rive.Vec2D get walkSpeed => _walkSpeed;
  HeroState _state = HeroState.idle;
  HeroState get state => isDead ? HeroState.dead : _state;
  double _fireTime = 0;

  void onPointerDown(rive.Vec2D pointer) {
    _pointerTouch = pointer;
    _state = HeroState.aiming;
  }

  void onPointerMove(rive.Vec2D pointer, rive.Vec2D pointerDelta) {
    if (_pointerTouch == null) {
      return;
    }
    _aimTarget += pointerDelta.x / 3;

    var touchDiff = pointer - _pointerTouch!;
    var diffLength = touchDiff.length();

    _targetWalkSpeed
      ..x = 0
      ..y = 0;
    if (diffLength > 90) {
      _state = HeroState.walkingAndFiring;
      _targetWalkSpeed
        ..x = touchDiff.x * 3
        ..y = 500;
    } else if (diffLength > 40) {
      _state = HeroState.firing;
    } else {
      _state = HeroState.aiming;
    }

    walk?.value = _state == HeroState.walkingAndFiring ? 1 : 0;
    _aimTarget = (touchDiff.x + 100) / 200 * 100;
  }

  void onPointerUp(rive.Vec2D pointer) {
    _targetWalkSpeed
      ..x = 0
      ..y = 0;
    walk?.value = 0;
    _state = HeroState.idle;
    _aimTarget = 50;
  }

  /// Aim at a specific world translation, uses the extracted headings to find
  /// the closest aim input target value.
  void aimAt(rive.Vec2D world) {
    double smallest = 1;
    int bestHeading = 0;

    for (int i = 0; i < aimIterations; i++) {
      var heading = _muzzleHeadings[i];
      rive.Vec2D toCharacter = (offset + _muzzlePositions[i]) - world;
      rive.Vec2D.normalize(toCharacter, toCharacter);

      var d = rive.Vec2D.dot(toCharacter, heading);
      _muzzleDots[i] = d;
      if (d < smallest) {
        smallest = d;
        bestHeading = i;
      }
    }
    double nudge = 0;

    if (bestHeading == 0) {
      // move left.
    } else if (bestHeading == aimIterations - 1) {
      // move right
    } else {
      var p = _muzzleDots[bestHeading - 1];
      var n = _muzzleDots[bestHeading + 1];
      if (p < n) {
        nudge = -min(1.0, (1 + _muzzleDots[bestHeading]) / 0.0002);
      } else {
        nudge = min(1.0, (1 + _muzzleDots[bestHeading]) / 0.0002);
      }
    }
    _aimTarget = (bestHeading + nudge) / (aimIterations - 1) * 100;
  }

  final Stopwatch _lastHurt = Stopwatch()..start();

  ZombieSceneObject? _lastHitZombie;
  double _damage = 0;
  bool _isDead = false;
  bool get isDead => _isDead;
  double _deadTime = 0;
  rive.TriggerInput? _showHand;
  final Stopwatch _headTime = Stopwatch()..start();

  bool get isInEndzone => offset.y > endingY - 1000;

  void _advanceProjectiles(elapsedSeconds) {
    for (final projectile in _projectiles) {
      if (!projectile.stopped) {
        bool stops = projectile.stops;
        List<DynamicSceneObject> hits = [];
        var hitFraction = scene.tree.raycast(
            RaySegment(projectile.position, projectile.end), (ray, id, object) {
          switch (object.classification) {
            case SceneClassification.character:
              if (object is! ZombieSceneObject) {
                return -1;
              }
              var dso = object;
              if (dso.isDead) {
                return -1;
              }
              var center = rive.Vec2D.fromValues(0.0, -174) + dso.offset;
              var radius = 100;

              // Ray intersect with sphere, based on:
              // https://stackoverflow.com/questions/1073336/circle-line-segment-collision-detection-algorithm
              var d = ray.end - ray.start;
              var f = ray.start - center;
              var a = rive.Vec2D.dot(d, d);
              var b = 2 * rive.Vec2D.dot(f, d);
              var c = rive.Vec2D.dot(f, f) - radius * radius;
              var discriminant = b * b - 4 * a * c;
              if (discriminant < 0) {
                return -1;
              } else {
                discriminant = sqrt(discriminant);
                var t1 = (-b - discriminant) / (2 * a);
                if (t1 >= 0 && t1 <= 1) {
                  hits.add(dso);
                  return stops ? t1 : -1;
                }
                var t2 = (-b + discriminant) / (2 * a);
                if (t2 >= 0 && t2 <= 1) {
                  hits.add(dso);
                  return stops ? t2 : -1;
                }
                return -1;
              }
            default:
              return -1;
          }
        });

        var deadZombie = projectile.hit(scene, hits, hitFraction);
        if (deadZombie != null &&
            _headTime.elapsedMilliseconds > 600 &&
            _rand.nextDouble() > 0.75) {
          _headTime.reset();
          // zombie died.
          var artboard = scene.zombie.artboard('Head');

          if (artboard != null) {
            artboard.frameOrigin = false;
            scene.add(
              HeadSceneObject(
                scene: scene,
                artboard: artboard,
                machine: artboard.defaultStateMachine()!,
                offset: deadZombie.offset,
              ),
            );
          }
        }
      }

      projectile.advance(this, elapsedSeconds);
    }
    _projectiles.removeWhere((projectile) {
      if (projectile.isDead) {
        projectile.dispose();
        return true;
      }
      return false;
    });
  }

  int kills = 0;

  void showBubble() {
    if (scene.reachedEnd) {
      artboard.setText('Bubble', 'Easy peasy...');
    }
    machine.boolean('Bubble')?.value = true;
  }

  void hideBubble() {
    machine.boolean('Bubble')?.value = false;
  }

  final List<_OverlayEffect> _effects = [];

  void addBatchMachines(List<rive.StateMachine> machines) {
    _effects.removeWhere((effect) {
      if (effect.drewFrames == 11) {
        effect.dispose();
        return true;
      }
      return false;
    });
    if (!_isDead) {
      machines.add(hpMachine);
    }
    for (final effect in _effects) {
      machines.add(effect.machine);
      effect.drewFrames++;
    }
  }

  double get deadTime => _deadTime;

  @override
  bool advance(double elapsedSeconds) {
    _healthPosition += ((offset +
                _healthTargetOffset +
                (_helmet?.worldTransform.translation ?? rive.Vec2D())) -
            _healthPosition) *
        min(1, elapsedSeconds * 9);
    hp.renderTransform = rive.Mat2D.fromTranslation(_healthPosition);
    if (_isDead) {
      _deadTime += elapsedSeconds;
      _advanceProjectiles(elapsedSeconds);
      if (_deadTime > 5.5) {
        _showHand?.fire();
      }
      return true;
    }
    _aimCurrent += (_aimTarget - _aimCurrent) * min(1, elapsedSeconds * 15);
    aim?.value = _aimCurrent;

    _walkSpeed += (_targetWalkSpeed - _walkSpeed) * min(1, elapsedSeconds * 10);
    var nextOffset = offset + _walkSpeed * elapsedSeconds;
    // Block if we hit the walls.
    if (offset.y <= endingY - 50 &&
        nextOffset.y > endingY - 50 &&
        (nextOffset.x < 1100 || nextOffset.x > 1357)) {
      nextOffset.y = endingY - 50;
    }
    if (nextOffset.x < 100) {
      nextOffset.x = 100;
    } else if (nextOffset.x > 2300) {
      nextOffset.x = 2300;
    }
    rive.Vec2D.copy(offset, nextOffset);
    artboard.renderTransform = renderTransform;

    // Cool off for checking hit detection.
    if (_lastHurt.elapsedMilliseconds > 100) {
      var bounds = rive.AABB
          .fromMinMax(
              rive.Vec2D.fromValues(-30, -10), rive.Vec2D.fromValues(30, 10))
          .offset(offset.x, offset.y);
      scene.tree.query(bounds, (proxy, object) {
        switch (object.classification) {
          case SceneClassification.character:
            if (object is ZombieSceneObject &&
                !object.isDead &&
                _lastHitZombie != object) {
              var center = object.aabb.center();
              var zombieBounds = rive.AABB.fromMinMax(
                  rive.Vec2D.fromValues(center.x - 110, center.y - 50),
                  rive.Vec2D.fromValues(center.x + 110, center.y + 50));

              if (rive.AABB.testOverlap(zombieBounds, bounds)) {
                _lastHurt.reset();
                if (offset.x > center.x) {
                  hitLeft?.fire();
                  object.hitLeft?.fire();
                  scene.shakeCamera(1);
                } else {
                  hitRight?.fire();
                  object.hitRight?.fire();
                  scene.shakeCamera(-1);
                }
                hpHit?.fire();
                _damage += 1;
                _lastHitZombie = object;

                return false;
              }
            } else if (object is Pickup) {
              if (object.pickup()) {
                _fireTime += 0.3;
                switch (object.type) {
                  case 1:
                    _weapon = HeroWeapon.machineGun;
                    machine.number('numColor')?.value = 0;
                    break;
                  case 0:
                    _weapon = HeroWeapon.railGun;
                    machine.number('numColor')?.value = 1;
                    break;
                }
              }
            }
            break;
          default:
            break;
        }
        return true;
      });
    }

    // Fire weapon
    switch (_state) {
      case HeroState.firing:
      case HeroState.walkingAndFiring:
        if (_weapon == HeroWeapon.none) {
          _fireTime = 0;
          break;
        }
        _fireTime -= elapsedSeconds;
        if (_fireTime <= 0 && !isInEndzone) {
          fire?.fire();
          var muzzle = _muzzle?.worldTransform ?? rive.Mat2D();
          var translation = offset + muzzle.translation;

          if (_weapon == HeroWeapon.machineGun) {
            for (int r = 0; r < 2; r++) {
              var pew = scene.characterFile.artboard('Pew')!;
              pew.setText(
                  'Pew',
                  MachineGunProjectile.soundLabels[
                      _rand.nextInt(MachineGunProjectile.soundLabels.length)]);
              pew.frameOrigin = false;
              var pewMachine = pew.defaultStateMachine()!;
              var md = muzzle.xDirection;
              var pewTransform = rive.Mat2D.fromRotation(
                  rive.Mat2D(),
                  atan2(md.y, md.x) +
                      pi / 2 * 3 +
                      (-1 + _rand.nextDouble() * 2) * pi / 8);
              pewTransform[4] =
                  offset.x - 180 - (-1 + _rand.nextDouble() * 2) * 80;
              pewTransform[5] = offset.y + 120 - _rand.nextDouble() * 220;
              _effects.add(_OverlayEffect(pew, pewMachine, pewTransform));

              _projectiles
                  .add(MachineGunProjectile(translation, muzzle.xDirection));
            }
            _fireTime += 0.028;
          } else {
            var pew = scene.characterFile.artboard('Pew')!;

            pew.setText(
                'Pew',
                RailGunProjectile.soundLabels[
                    _rand.nextInt(RailGunProjectile.soundLabels.length)]);
            pew.frameOrigin = false;
            var pewMachine = pew.defaultStateMachine()!;

            // var pewTransform = muzzle.mul(rive.Mat2D.fromTranslation(offset));
            var md = muzzle.xDirection;
            var pewTransform = rive.Mat2D.fromRotation(
                rive.Mat2D(),
                atan2(md.y, md.x) +
                    pi / 2 * 3 +
                    (-1 + _rand.nextDouble() * 2) * pi / 8);
            pewTransform[4] = offset.x + (-1 + _rand.nextDouble() * 2) * 80;
            pewTransform[5] = offset.y + 120 - _rand.nextDouble() * 220;

            _effects.add(_OverlayEffect(pew, pewMachine, pewTransform));
            _projectiles.add(RailGunProjectile(
                scene.size.height * 0.9, translation, muzzle.xDirection));

            _fireTime += 0.44;
          }
        }
        break;
      default:
        break;
    }

    _advanceProjectiles(elapsedSeconds);

    if (_damage > 4) {
      _lastHitZombie?.damage(scene.zombie, false);
      _lastHitZombie?.damage(scene.zombie, false);
      _lastHitZombie?.damage(scene.zombie, false);
      _lastHitZombie?.damage(scene.zombie, false);
      _lastHitZombie?.damage(scene.zombie, false);
      _isDead = true;
      var death = scene.characterFile.artboard('Death');
      if (death != null) {
        death.frameOrigin = false;
        var machine = death.defaultStateMachine();
        if (machine != null) {
          _showHand = machine.trigger('Trigger 1');
          scene.add(
            DynamicSceneObject(
              scene: scene,
              artboard: death,
              machine: machine,
              offset: offset,
            ),
          );
        }
      }
    }
    return true;
  }

  @override
  bool get doesDraw => !_isDead;

  @override
  void draw(rive.Renderer renderer) {
    if (_isDead) {
      return;
    }
    renderer.save();
    renderer.translate(offset.x, offset.y);
    artboard.draw(renderer);
    renderer.restore();
  }

  void drawProjectiles(rive.Renderer renderer) {
    for (final projectile in _projectiles) {
      projectile.draw(renderer);
    }
  }

  void drawEffects(rive.Renderer renderer) {
    if (!_isDead) {
      renderer.save();
      renderer.translate(_healthPosition.x, _healthPosition.y);
      hp.draw(renderer);
      renderer.restore();
    }

    for (final effect in _effects) {
      effect.draw(renderer);
    }
  }

  @override
  void dispose() {
    // Intentionally empty as Joel's Artboard and StateMachine lifecycle are
    // managed by the loader.
    for (final effect in _effects) {
      effect.dispose();
    }
    _effects.clear();
    for (final projectile in _projectiles) {
      projectile.dispose();
    }
    _projectiles.clear();
  }
}
