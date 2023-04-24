import 'dart:math';
import 'package:flutter/material.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import 'package:space_invaders_bug/projectile.dart';
import 'package:space_invaders_bug/boss.dart';
import 'package:space_invaders_bug/bug.dart';

import 'package:space_invaders_bug/utils.dart';

class SceneTile {
  final rive.Artboard artboard;
  final rive.AABB bounds;
  final rive.Vec2D position;

  SceneTile(
    this.artboard, {
    required this.bounds,
    required this.position,
  });
}

class GamePainter extends rive.RenderTexturePainter {
  // Rive files
  final rive.File riveFile;
  final rive.File riveBg;
  final List<rive.File> bugFiles;
  final rive.File bugBossFile;

  // Tile
  late rive.Artboard bgArtboard;

  // Spaceship
  late rive.Artboard shipArtboard;
  late rive.StateMachine shipStateMachine;
  late rive.BooleanInput shipFiring;
  late rive.TriggerInput shipExplodeTrigger;
  late rive.Component _controlComponent;
  late rive.Component _shipAngle;

  // Lasers
  late rive.Artboard beamArtboard;
  late rive.Component _mainLaser;

  // Bugs
  late Set<Bug> bugList = {};
  late Set<Bug> killedBugs = {};

  // Bee Boss
  late rive.Artboard bossArtboard;
  late rive.StateMachine bossStateMachine;
  late rive.TriggerInput bossHitTrigger;
  late rive.TriggerInput bossAttackTrigger;
  late rive.NumberInput bossHealthInput;

  Boss? beeBoss;

  // For space tiles
  final List<SceneTile> sceneTiles = [];
  late rive.AABB tileSize;
  late Size worldSize;

  // Shoot interval
  int shootingFrame = 0;

  // Lasers (maybe not needed)
  late Set<LaserProjectile> laserList = {};
  late Set<BugProjectile> slimeList = {};

  // Shooting Score
  int bugsKilled = 0;
  // How many bugs to generate initially before boss renders
  int bugsToKillBeforeBoss = 50;

  // Minion list
  late Set<MinionProjectile> minionProjectileList = {};

  rive.Vec2D localCursor = rive.Vec2D();

  // 1. Instance all the Rive artboards, state machines and associated inputs,
  // and components that'll be used for this game. Reference the associated
  // Rive files to see the name correlation to each of these pieces
  //
  // 2. Create a set of bug instances for our game
  //
  // 3. Create a set of tiles to use as our background
  GamePainter(this.riveFile, this.riveBg, this.bugFiles, this.bugBossFile)
      : shipArtboard = riveFile.artboard("large scene")!,
        bgArtboard = riveBg.artboard("bg")!,
        beamArtboard = riveFile.artboard("beam")!,
        bossArtboard = bugBossFile.artboard("Main")! {
    shipArtboard.frameOrigin = false;
    bossArtboard.frameOrigin = false;

    // Grab references to state machines, inputs, and components
    shipStateMachine = shipArtboard.stateMachine("State Machine 1")!;
    shipFiring = shipStateMachine.boolean("isShooting")!;
    shipExplodeTrigger = shipStateMachine.trigger("explosion")!;
    _controlComponent = shipArtboard.component("main")!;
    _shipAngle = shipArtboard.component("shipAngle")!;
    _mainLaser = shipArtboard.component("beamMain")!;

    bossStateMachine = bossArtboard.stateMachine("State Machine 1")!;

    // Add space tiles
    const rows = 5;
    const columns = 5;
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        sceneTiles.add(
          SceneTile(
            bgArtboard,
            bounds: bgArtboard.bounds,
            position: rive.Vec2D.fromValues(
                j * bgArtboard.bounds.width, i * bgArtboard.bounds.height),
          ),
        );
      }
    }

    tileSize = bgArtboard.bounds;
    worldSize = Size(tileSize.width * columns, tileSize.height * rows);

    // Spawn the initial bugs
    spawnBugs(bugsToKillBeforeBoss);
  }

  // Create Bug instances up to the spawnStagger parameter number, each with
  // a random position to render at, as well as references to their own artboard
  // and state machine
  void spawnBugs(int spawnStagger) {
    var rand = Random();
    for (var i = 0; i < spawnStagger; i++) {
      var bugFile = bugFiles[rand.nextInt(bugFiles.length)];
      var bugArtboard = bugFile.artboard("New Artboard")!;
      var bugStateMachine = bugArtboard.stateMachine("State Machine 1")!;
      var bugBounds = bugArtboard.bounds;

      var range = sceneRange.maximum - sceneRange.minimum;
      var newBug = Bug(
        bugArtboard,
        bugStateMachine,
        bounds: bugBounds,
        position: rive.Vec2D.fromValues(
            rand.nextDouble() * range.x + sceneRange.minimum.x,
            rand.nextDouble() * range.y + sceneRange.minimum.y),
      );
      bugList.add(newBug);
    }
  }

  // Callback for the MouseRegion widget that wraps this GamePainter w.r.t. the
  // onHover event. Store the Offset of the local cursor position into a Vec2D
  void aimAt(Offset localPosition) {
    localCursor = rive.Vec2D.fromOffset(localPosition);
  }

  // Callback for the FocusNode widget that wraps this GamePainter w.r.t. the
  // onKeyEvent listening for the spacebar key. Set the ships state machine
  // boolean input to true for the shooting action
  //
  // (inspect the top_down_ship.riv for more on how the state machine is set up)
  void fire() {
    shipFiring.value = true;
  }

  // Draw the background tiles with the Renderer at their defined positions
  void drawTiles(rive.Renderer renderer) {
    for (var sceneTile in sceneTiles) {
      renderer.save();
      renderer.translate(sceneTile.position.x, sceneTile.position.y);
      sceneTile.artboard.draw(renderer);
      renderer.restore();
    }
  }

  @override
  Color get background => Color.fromARGB(236, 0, 0, 0);

  // Artbitrary range to define the scene boundaries
  rive.AABB get sceneBounds {
    final bounds = shipArtboard.bounds;
    final shipWidth = bounds.width;
    return bounds.inset(-shipWidth * 3, 0);
  }

  // Artbitrary range to define the scene for bugs
  rive.AABB get sceneRange {
    return rive.AABB.fromMinMax(
        sceneBounds.minimum - rive.Vec2D.fromValues(0, 5000),
        sceneBounds.maximum - rive.Vec2D.fromValues(0, 3000));
  }

  // This method contains the animation/render loop. Here is where we control
  // most of the game logic and what entity renders where on the RenderTexture.
  // This method will continuously be called every frame as long as you return
  // `true` at the end of the method (to continue painting the next frame).
  //
  // For demo purposes, a lot of logic may be encapsulated here, but in a real
  // production app, you may want to consider how you organize your different
  // GameKit entities (classes) to prevent this method from becoming large in
  // size.
  @override
  bool paint(rive.RenderTexture texture, Size size, double elapsedSeconds) {
    var renderer = rive.Renderer.make();

    var viewTransform = renderer.computeAlignment(
      BoxFit.contain,
      Alignment.bottomCenter,
      rive.AABB.fromValues(0, 0, size.width, size.height),
      sceneBounds,
    );

    drawTiles(renderer);

    final inverseViewTransform = rive.Mat2D();
    var worldCursor = rive.Vec2D();
    if (rive.Mat2D.invert(inverseViewTransform, viewTransform)) {
      worldCursor = inverseViewTransform * localCursor -
          rive.Vec2D.fromValues(shipArtboard.bounds.centerX, 0);
    }

    _controlComponent.x = worldCursor.x;
    _shipAngle.x = worldCursor.x * 0.83;

    // Apply the viewTransform from earlier to the renderer
    renderer.save();
    renderer.transform(viewTransform);
    shipStateMachine.advance(elapsedSeconds);

    // Advance Bug state machine's and draw the artboard efficiently in a multi-
    // threaded batch function from Rive
    var randShooterObj = Random();
    var randBugIdx =
        bugList.isNotEmpty ? randShooterObj.nextInt(bugList.length) : 0;
    // Advances time for each bug even if killed, so that we can count elapsed
    // seconds since death, to let a death animation play out before removing
    // and disposing of a Bug artboard/state machine from the scene
    for (var bug in bugList) {
      bug.advance(elapsedSeconds);
    }
    rive.Rive.batchAdvanceAndRender(
        bugList.map((bug) => bug.stateMachine), elapsedSeconds, renderer);

    // Draw the Bee Boss when all the bugs are killed
    if (bugsKilled >= bugsToKillBeforeBoss && beeBoss == null) {
      var bossTransform = rive.Mat2D.fromScale(3, 3)
          .mul(rive.Mat2D.fromTranslate(0, -(size.height)));
      beeBoss = Boss(bugBossFile, bossArtboard, bossStateMachine,
          bounds: bossArtboard.bounds, bossTransform: bossTransform);
      shootingFrame = 0;
    }

    if (beeBoss != null) {
      beeBoss!.advanceAndDraw(renderer, elapsedSeconds);
    }

    // Draw the spaceship that starts at the center on bottom of screen
    renderer.save();
    renderer.translate(0, 0);
    shipArtboard.draw(renderer);
    renderer.restore();

    // Draw a laser projectile when the state machine "isShooting" is set to
    // true. Get the position of the ship laser muzzle in world space and call
    // moveLaser to render the laser artboard at that location
    renderer.save();
    var realLaserInWorld = getWorldPointFromLocal(_mainLaser.worldTransform);
    renderer.restore();
    if (shipFiring.value) {
      var yInWorld = _mainLaser.worldTransform.mul(viewTransform);
      var laserShotArtboard = riveFile.artboard("beam")!;
      laserShotArtboard.frameOrigin = false;
      var startingPosition = rive.Vec2D.fromValues(
          worldCursor.x +
              shipArtboard.bounds.centerX +
              laserShotArtboard.bounds.centerX,
          yInWorld[5] + laserShotArtboard.bounds.centerY);
      var newLaser = LaserProjectile(laserShotArtboard, startingPosition,
          rive.Vec2D.fromValues(0, realLaserInWorld.y * 2 * -1));
      laserList.add(newLaser);
      newLaser.moveLaser(renderer, startingPosition, elapsedSeconds);
      shipFiring.value = false;
    }

    Set<LaserProjectile> removedLasers = {};

    // For each laser created, determine if:
    // - It's past its life time (5 seconds), and dispose accordingly
    // - It hit a bug or a boss. If yes, the hit detection logic in the laser
    //   projectile class already accounts for life ending, just add to
    //   removedLasers to get disposed
    for (var laser in laserList) {
      if (laser.isDone) {
        laser.dispose();
        removedLasers.add(laser);
      } else {
        var tempPosition = rive.Vec2D.fromValues(
            laser.startPosition.x, laser.startPosition.y - 100);
        laser.moveLaser(renderer, tempPosition, elapsedSeconds);
        if (beeBoss != null) {
          var didHitBoss = laser.testBossHitDetection(beeBoss!);
          if (didHitBoss) {
            laser.dispose();
            removedLasers.add(laser);
            beeBoss!.takeDamage();
            if (beeBoss!.bossHealthInput.value <= 0) {
              // In the future, acconut for a death animation for the boss
              beeBoss!.dispose();
              beeBoss = null;
              bugsKilled = 0;
            }
          }
        } else {
          var potentiallyHitBug = laser.testHitDetection(bugList);
          if (potentiallyHitBug != null &&
              !killedBugs.contains(potentiallyHitBug)) {
            laser.dispose();
            removedLasers.add(laser);
            bugsKilled++;
            killedBugs.add(potentiallyHitBug);
            potentiallyHitBug.killBug();
          }
        }
      }
    }
    laserList.removeAll(removedLasers);

    // Detect if Bug is dead and is ready to be disposed of, while also creating
    // Bug slime projectiles randomly
    var deadList = <Bug>{};
    for (int i = 0; i < bugList.length; i++) {
      var bug = bugList.elementAt(i);
      if (bug.isDead) {
        deadList.add(bug);
        bug.dispose();
        continue;
      }
      if (shootingFrame == 100 && i == randBugIdx) {
        shootingFrame = 0;
        var startPosition =
            rive.Vec2D.fromValues(bug.position.x, bug.position.y);
        var slimeProjectile =
            BugProjectile(startPosition, rive.Vec2D.fromValues(0, 200));
        slimeList.add(slimeProjectile);
        slimeProjectile.advance(startPosition, elapsedSeconds);
        slimeProjectile.draw(renderer);
        bug.fire();
      }
    }
    bugList.removeAll(deadList);

    // Detect if any Bug slime projectiles have hit the ship and trigger the
    // explore state machine input on the ship if so.
    // Additionally, detect if any Bug slime projectiles are "done" or "dead" to
    // remove them from the scene
    Set<BugProjectile> removedSlimes = {};
    for (var slime in slimeList) {
      if (slime.isDone) {
        removedSlimes.add(slime);
      } else {
        renderer.save();
        var tempPosition =
            rive.Vec2D.fromValues(slime.position.x, slime.position.y + 100);
        slime.advance(tempPosition, elapsedSeconds);
        slime.draw(renderer);

        if (slime.testHitDetection(shipArtboard)) {
          shipExplodeTrigger.fire();
          removedSlimes.add(slime);
        }
        renderer.restore();
      }
    }
    for (var removedSlime in removedSlimes) {
      removedSlime.dispose();
    }
    slimeList.removeAll(removedSlimes);

    // Spawn minions from the Boss on a cadence and move them towards the ship's
    // location. Explode the ship using the explode trigger from the ship's
    // state machine if hit detection occurs, and remove the dead minions
    // progressively
    if (beeBoss != null) {
      if (shootingFrame >= 100) {
        shootingFrame = 0;
        beeBoss!.fire(_controlComponent);
      }
      beeBoss!.advanceMinions(renderer, elapsedSeconds, _controlComponent);
      if (beeBoss!.testHitDetection(shipArtboard)) {
        shipExplodeTrigger.fire();
      }
      beeBoss!.removeDeadMinions();
    }
    renderer.restore();
    shootingFrame++;
    return true;
  }

  // Dispose of all our Rive instances to properly clean up unneeded resources
  // Note: Components and State Machine Inputs do not need to be disposed of
  @override
  void dispose() {
    // Dispose Rive Files
    riveFile.dispose();
    riveBg.dispose();
    for (var bugFile in bugFiles) {
      bugFile.dispose();
    }
    bugBossFile.dispose();

    //Dispose Artboards
    shipArtboard.dispose();
    bgArtboard.dispose();
    beamArtboard.dispose();
    bossArtboard.dispose();

    // Dispose State Machines
    shipStateMachine.dispose();
    bossStateMachine.dispose();

    // Dispose any leftover Rive references in Bugs
    for (var bug in bugList) {
      bug.dispose();
    }

    // Dispose any leftover Rive references in Lasers
    for (var laser in laserList) {
      laser.dispose();
    }

    super.dispose();
  }
}
