import 'dart:math';
import 'dart:ui' as ui;
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import 'package:space_invaders_bug/boss.dart';
import 'package:space_invaders_bug/constants.dart' as constants;
import 'package:space_invaders_bug/bug.dart';

/// A single projectile fired by the hero.
/// Maybe make an extension of this called PaintProjectile
abstract class Projectile {
  final rive.RenderPath path = rive.Renderer.makePath();
  rive.RenderPaint get stroke;

  rive.Vec2D position;
  rive.Vec2D direction;
  late rive.Vec2D end;
  double get length;
  double get duration;

  // 5 seconds for projectile to live
  final int lifeLimit = 5;

  Projectile(this.position, this.direction) {
    end = position + direction * length;
    path.moveTo(position.x, position.y);
    path.lineTo(end.x, end.y);
  }

  double life = 0;

  bool advance(rive.Vec2D muzzle, double seconds) {
    life += seconds;
    return life > duration;
  }

  bool get isDead => life > duration;

  void dispose() {
    path.dispose();
  }

  void draw(rive.Renderer renderer) {
    renderer.drawPath(path, stroke);
  }
}

class BugProjectile extends Projectile {
  final rive.RenderPaint bugStroke;

  final double _length = 1;

  @override
  rive.RenderPaint get stroke => bugStroke;

  @override
  double get duration => 0.3;

  @override
  double get length => _length;

  static const double _startingThickness = 30;
  double _thickness = _startingThickness;

  BugProjectile(super.position, super.direction)
      : bugStroke = rive.Renderer.makePaint()
          ..style = ui.PaintingStyle.stroke
          ..blendMode = ui.BlendMode.colorDodge
          ..color = const ui.Color.fromRGBO(0, 255, 0, 1)
          ..thickness = _startingThickness
          ..cap = ui.StrokeCap.round;

  @override
  bool advance(rive.Vec2D vec, double seconds) {
    position = vec;
    life += seconds;
    path.reset();
    end = position + direction * length;

    path.moveTo(position.x, position.y);
    path.lineTo(end.x, end.y);

    _thickness += (0 - _thickness) * min(1, seconds * 2);
    bugStroke.thickness = _thickness;

    return life > duration;
  }

  bool testHitDetection(rive.Artboard shipArtboard) {
    var slimeBoundingBox = rive.AABB.fromMinMax(end, position);
    var shipBox = shipArtboard.component("shootingHit")!;

    // Ship shape for hit detection is 425 x 487
    var translatedMat = rive.Mat2D.fromTranslate(
        shipBox.worldTransform[4] - (constants.SHIP_HITBOX_WIDTH / 2),
        shipBox.worldTransform[5] - (constants.SHIP_HITBOX_HEIGHT / 2));
    var newShipBounds = rive.AABB.fromValues(
        translatedMat[4],
        translatedMat[5],
        translatedMat[4] + constants.SHIP_HITBOX_WIDTH,
        translatedMat[5] + constants.SHIP_HITBOX_HEIGHT);
    if (rive.AABB.testOverlap(slimeBoundingBox, newShipBounds)) {
      life = lifeLimit + 1;
      return true;
    }
    return false;
  }

  // hack to keep laser alive for a bit
  bool get isDone => life > lifeLimit;

  @override
  void dispose() {
    super.dispose();
    bugStroke.dispose();
  }
}

class LaserProjectile {
  final rive.Artboard laserArtboard;
  rive.Vec2D startPosition;
  rive.Vec2D endPosition;
  final rive.Vec2D direction;

  double life = 0;
  // 5 seconds for projectile to live
  final int lifeLimit = 5;

  LaserProjectile(this.laserArtboard, this.startPosition, this.direction)
      : endPosition = startPosition;

  void moveLaser(
      rive.Renderer renderer, rive.Vec2D vec, double elapsedSeconds) {
    renderer.save();
    startPosition = vec;
    life += elapsedSeconds;
    endPosition = startPosition + direction;
    var tempTransform = rive.Mat2D.fromTranslation(endPosition);
    renderer.transform(tempTransform);
    laserArtboard.draw(renderer);
    renderer.restore();
  }

  Bug? testHitDetection(Set<Bug> bugList) {
    var laserBoundingBox = rive.AABB.fromMinMax(endPosition, startPosition);
    for (var bug in bugList) {
      var bugArtboardBounds = bug.artboard.bounds;
      var translatedMat = rive.Mat2D.fromTranslate(
          bug.position.x - (bugArtboardBounds.width / 2),
          bug.position.y - (bugArtboardBounds.height / 2));
      var newBugBounds = rive.AABB.fromValues(
          translatedMat[4],
          translatedMat[5],
          translatedMat[4] + bugArtboardBounds.width,
          translatedMat[5] + bugArtboardBounds.height);
      if (rive.AABB.testOverlap(laserBoundingBox, newBugBounds)) {
        life = lifeLimit + 1;
        return bug;
      }
    }
    return null;
  }

  bool testBossHitDetection(Boss beeBoss) {
    // var laserBoundingBox = rive.AABB.fromMinMax(end, prevVec);
    var laserBoundingBox = rive.AABB.fromValues(
        endPosition.x,
        endPosition.y,
        endPosition.x + laserArtboard.bounds.width,
        endPosition.y + laserArtboard.bounds.height);
    var translatedMat =
        rive.Mat2D.fromTranslate(beeBoss.position.x, beeBoss.position.y)
            .mul(beeBoss.artboard.renderTransform);
    var newBossBounds = rive.AABB.fromValues(
      translatedMat[4],
      translatedMat[5],
      translatedMat[4] + (beeBoss.artboard.bounds.width * translatedMat[0]),
      translatedMat[5] + (beeBoss.artboard.bounds.height * translatedMat[3]),
    );
    if (rive.AABB.testOverlap(laserBoundingBox, newBossBounds)) {
      life = lifeLimit + 1;
      return true;
    }
    return false;
  }

  bool get isDone => life > lifeLimit;

  void dispose() {
    laserArtboard.dispose();
  }
}

class MinionProjectile {
  rive.Artboard minionArtboard;
  rive.Artboard beeBossArtboard;
  rive.Component spawnLocationComponent;
  rive.StateMachine minionSm;

  // Transformation with last translation of the Minion
  late rive.Mat2D lastPositionTransform;

  // Transformation with the original translation of the Minion (spawn point)
  late rive.Mat2D originalPositionTransform;

  // Final transformation of the Minion in world space (after scaling, position,
  // and rotation)
  rive.Mat2D? lastWorldSpaceTransform;

  double timeSinceSpawn = 0;
  final double timeUntilAttack = 0.5;

  double life = 0;
  final int lifeLimit = 5;

  MinionProjectile(
      this.minionArtboard, this.beeBossArtboard, this.spawnLocationComponent)
      : minionSm = minionArtboard.stateMachine("State Machine 1")! {
    lastPositionTransform = rive.Mat2D.fromTranslate(
        spawnLocationComponent.worldTransform[4] -
            (minionArtboard.bounds.centerX / 3),
        spawnLocationComponent.worldTransform[5] -
            (minionArtboard.bounds.centerY / 3));
    originalPositionTransform = lastPositionTransform;
  }

  // Draws the next transformation for the MinionProjectile. It also keeps the
  // Minion in place (spawning location) for a short period of time before it
  // "attacks" and starts moving towards the ship. Since the Boss artboard from
  // which this Minion spawned is scaled 3x up, we make sure to calculate the
  // appropriate transform for minions so they are scaled back down 3x in size.
  // The rotation transform calculation below also rotates the Minion towards
  // the spaceship component, based on where the spaceship lands on either side
  // of the x-axis
  void drawNextTransform(rive.Component shipControlComponent,
      rive.Renderer renderer, double elapsedSeconds) {
    var shouldMove = timeSinceSpawn >= timeUntilAttack;
    if (!shouldMove) {
      life += elapsedSeconds;
      timeSinceSpawn += elapsedSeconds;
      return;
    }
    var moveTransform = rive.Mat2D.fromTranslate(
        (lastPositionTransform[4] - (minionArtboard.bounds.centerX / 3)) +
            (shipControlComponent.x < 0 ? -15 : 15),
        (lastPositionTransform[5] - (minionArtboard.bounds.centerY / 3)) + 15);
    var finalTransform = beeBossArtboard.renderTransform
        .mul(shouldMove ? moveTransform : originalPositionTransform)
        .mul(rive.Mat2D.fromRotation(
            rive.Mat2D(),
            atan2(
                    -1 *
                        ((shipControlComponent.x -
                            minionArtboard.bounds.centerX)),
                    -1 * (shipControlComponent.y)) /
                2))
        .mul(rive.Mat2D.fromScale(1 / 3, 1 / 3));
    minionArtboard.renderTransform = finalTransform;
    lastPositionTransform =
        shouldMove ? moveTransform : originalPositionTransform;
    lastWorldSpaceTransform = finalTransform;
    life += elapsedSeconds;
    timeSinceSpawn += elapsedSeconds;
  }

  // Determine if the Minion comes into contact with the bounding box of the
  // spaceship
  bool testHitDetection(rive.Artboard shipArtboard) {
    if (lastWorldSpaceTransform == null) {
      return false;
    }
    var minionBoundingBox = rive.AABB.fromValues(
        lastWorldSpaceTransform![4],
        lastWorldSpaceTransform![5],
        lastWorldSpaceTransform![4] + minionArtboard.bounds.width,
        lastWorldSpaceTransform![5] + minionArtboard.bounds.height);
    var shipBox = shipArtboard.component("shootingHit")!;

    var shipTranslatedMat = rive.Mat2D.fromTranslate(
        shipBox.worldTransform[4] - (constants.SHIP_HITBOX_WIDTH / 2),
        shipBox.worldTransform[5] - (constants.SHIP_HITBOX_HEIGHT / 2));
    var newShipBounds = rive.AABB.fromValues(
        shipTranslatedMat[4],
        shipTranslatedMat[5],
        shipTranslatedMat[4] + constants.SHIP_HITBOX_WIDTH,
        shipTranslatedMat[5] + constants.SHIP_HITBOX_HEIGHT);
    if (rive.AABB.testOverlap(minionBoundingBox, newShipBounds)) {
      life = lifeLimit + 1;
      return true;
    }
    return false;
  }

  bool get isDone => life > lifeLimit;

  void dispose() {
    minionArtboard.dispose();
  }
}
