import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:joel/aabb_tree.dart';
import 'package:joel/beggining.dart';
import 'package:joel/dynamic_scene_object.dart';
import 'package:joel/ending.dart';
import 'package:joel/hero.dart';
import 'package:joel/parallax_camera.dart';
import 'package:joel/pickup.dart';
import 'package:joel/scenery.dart';
import 'package:joel/static_scene_object.dart';
import 'package:joel/zombie.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

Random _rand = Random();

/// Scene Objects are treated, and placed, differently by the Scene based on
/// their classification.
enum SceneClassification {
  /// Represents any static scene objects which are not shadows.
  ground,

  /// Strictly for use by ShadowSceneObjects as these have logic for path
  /// pouring and skipping default artboard rendering.
  shadow,

  /// Any dynamic object expected to move around the scene, always inheriting
  /// from a DynamicSceneObject base class.
  character,

  /// A static scene object that will be renderered with a more zoomed in camera
  /// to provide a parallax effect. Currently used by tree tops.
  parallax,

  /// A static scene object that will be renderered with an even more zoomed in
  /// camera to provide a parallax effect. Currently used by tree tops.
  highParallax,

  /// DynamicSceneObjects that need to render above the parallax effect. Flying
  /// limbs, clouds, etc.
  sky
}

const useBatchAndRender = true;

abstract class SceneObject {
  int _sceneTreeProxy = -1;
  int get sceneTreeProxy => _sceneTreeProxy;
  rive.AABB get aabb;
  SceneClassification get classification;
  rive.Mat2D get renderTransform;
  void draw(rive.Renderer renderer) {}
  void dispose() {}
}

class Scene {
  final AABBTree<SceneObject> _tree = AABBTree();
  final AABBTree<SceneObject> _staticTree = AABBTree();

  AABBTree<SceneObject> get tree => _tree;
  AABBTree<SceneObject> get staticTree => _staticTree;

  final HashSet<SceneObject> objects = HashSet<SceneObject>();
  final rive.Mat2D _viewTransform = rive.Mat2D();
  final rive.Mat2D _inverseViewTransform = rive.Mat2D();
  final rive.Vec2D _cameraTranslation = rive.Vec2D();
  rive.Vec2D _cameraOffset = rive.Vec2D();
  final List<rive.Artboard> trees;
  final List<rive.Artboard> clouds;
  final List<rive.Artboard> rocks;
  final List<rive.StateMachine> treeMachines = [];
  final List<rive.StateMachine> cloudMachines = [];
  double _cameraZoom = 1.0;

  // We just store these to clean them up later.
  final VoidCallback _cleanup;

  final rive.Artboard backgroundA;
  final rive.Artboard backgroundB;
  final rive.Artboard shadowsA;
  final rive.Artboard shadowsB;
  final rive.File zombie;
  final rive.File bullets;
  final rive.File characterFile;
  late Hero _character;
  Hero get character => _character;
  rive.Animation? shadowBreezeA;
  rive.Animation? shadowBreezeB;
  final rive.Artboard end;
  final rive.StateMachine endStateMachine;
  final rive.Artboard begin;
  final rive.StateMachine beginStateMachine;
  final rive.Artboard joystick;
  final rive.StateMachine joystickStateMachine;
  final rive.BooleanInput? joystickActive;
  final rive.BooleanInput? joystickShooting;
  final rive.BooleanInput? joystickArrow;
  final rive.Component? joystickCursor;
  final rive.StateMachine? bushStateMachine;
  Beggining? _beggining;
  Ending? _ending;
  Scene._(
    this._cleanup, {
    required rive.Artboard character,
    required rive.StateMachine characterStateMachine,
    required this.backgroundA,
    required this.backgroundB,
    required this.shadowsA,
    required this.shadowsB,
    required this.trees,
    required this.clouds,
    required this.rocks,
    required this.zombie,
    required this.characterFile,
    required this.end,
    required this.endStateMachine,
    required this.begin,
    required this.beginStateMachine,
    required this.bullets,
    required this.joystick,
    required this.joystickStateMachine,
    required rive.Artboard hp,
    required rive.StateMachine hpStateMachine,
    required this.bushStateMachine,
  })  : joystickActive = joystickStateMachine.boolean('joystickActive'),
        joystickShooting = joystickStateMachine.boolean('shootingOn'),
        joystickArrow = joystickStateMachine.boolean('arrowOn'),
        joystickCursor = joystick.component('cursor') {
    _character = Hero(
      scene: this,
      artboard: character,
      machine: characterStateMachine,
      hp: hp,
      hpMachine: hpStateMachine,
      offset: rive.Vec2D.fromValues(
        backgroundA.bounds.width / 2,
        backgroundA.bounds.height / 2,
      ),
    );
    shadowBreezeA = shadowsA.animationNamed('Breeze');
    shadowBreezeB = shadowsB.animationNamed('Breeze');
    double y = -backgroundA.bounds.height;
    double treeLeftY = y;
    double treeRightY = y;
    double cloudLeftY = y;
    double cloudRightY = y;
    double endingY = 0;

    const cloudHalfWidth = 500.0;
    const cloudHalfHeight = 500.0;
    const cloudEdgeCount = 3;
    final random = Random();
    for (final tree in trees) {
      treeMachines.add(tree.defaultStateMachine()!);
    }
    for (final cloud in clouds) {
      cloudMachines.add(cloud.defaultStateMachine()!);
    }

    var levelLength = 10;
    for (int i = 0; i < levelLength; i++) {
      var artboard = i % 2 == 0 ? backgroundA : backgroundB;
      var shadow = i % 2 == 0 ? shadowsA : shadowsB;

      add(ShadowSceneObject(shadow, rive.Vec2D.fromValues(0, y)));
      add(StaticSceneObject(artboard, rive.Vec2D.fromValues(0, y)));

      y += artboard.bounds.height - 2;

      var treeRoadMargin = 0.0;
      var artboardWidth = artboard.bounds.width;
      var artboardHeight = artboard.bounds.height;
      var zombiePad = 350.0;
      var zombieRange = Size(artboardWidth - zombiePad * 2, artboardHeight);

      while (treeLeftY < y) {
        var tree = trees[random.nextInt(trees.length)];
        add(TreeSceneObject(
            tree,
            rive.Vec2D.fromValues(
                treeRoadMargin + random.nextDouble() * 30 - 80, treeLeftY)));
        treeLeftY += tree.bounds.height * 0.52;
        for (int j = 0; j < 3; j++) {
          var rock = rocks[random.nextInt(rocks.length)];
          add(
            StaticSceneObject(
              rock,
              rive.Vec2D.fromValues(
                zombiePad + zombieRange.width * random.nextDouble(),
                treeLeftY + (-1 + random.nextDouble() * 2) * 100,
              ),
            ),
          );
        }
      }

      while (cloudLeftY < y) {
        double x = -cloudHalfWidth / 2;
        for (int j = 0; j < cloudEdgeCount; j++) {
          // add a cloud

          var pos = rive.Vec2D.fromValues(x, cloudLeftY);

          var cloud = clouds[random.nextInt(clouds.length)];
          add(CloudSceneObject(
              cloud,
              pos +
                  rive.Vec2D.fromValues(-50 + 100 * _rand.nextDouble(),
                      -50 + 100 * _rand.nextDouble())));
          x -= cloudHalfWidth;
        }
        cloudLeftY += cloudHalfHeight;
      }

      while (cloudRightY < y) {
        double x = artboardWidth + cloudHalfWidth / 2;
        for (int j = 0; j < cloudEdgeCount; j++) {
          // add a cloud

          var pos = rive.Vec2D.fromValues(x, cloudRightY);

          var cloud = clouds[random.nextInt(clouds.length)];
          add(CloudSceneObject(
              cloud,
              pos +
                  rive.Vec2D.fromValues(-50 + 100 * _rand.nextDouble(),
                      -50 + 100 * _rand.nextDouble())));
          x += cloudHalfWidth;
        }
        cloudRightY += cloudHalfHeight;
      }

      var treeRangeX = artboardWidth - treeRoadMargin * 2;
      while (treeRightY < y) {
        var tree = trees[random.nextInt(trees.length)];
        add(TreeSceneObject(
            tree,
            rive.Vec2D.fromValues(
                treeRoadMargin + treeRangeX + random.nextDouble() * 30 + 80,
                treeRightY)));
        treeRightY += tree.bounds.height * 0.52;
      }
      if (i >= 1 && i < levelLength - 4) {
        var bulletCount = 2 + random.nextInt(3);
        for (int j = 0; j < bulletCount; j++) {
          var artboard = bullets.defaultArtboard();
          if (artboard == null) {
            continue;
          }
          artboard.frameOrigin = false;
          var bullet = Pickup(
            scene: this,
            artboard: artboard,
            machine: artboard.defaultStateMachine()!,
            offset: rive.Vec2D.fromValues(
              _rand.nextDouble() * zombieRange.width,
              y + _rand.nextDouble() * zombieRange.height,
            ),
          );
          add(bullet);
        }
        var count = 200; //Platform.isMacOS ? 150 : 60;
        for (int j = 0; j < count; j++) {
          var zombieSceneObject = ZombieSceneObject.make(
            file: zombie,
            scene: this,
            y: y,
            range: zombieRange,
            pad: zombiePad,
          );
          if (zombieSceneObject != null) {
            add(zombieSceneObject);
          }
        }
        endingY = y;
      }
    }

    // spawn one set of bullets close to Joel
    for (int b = 0; b < 2; b++) {
      var artboard = bullets.defaultArtboard();
      if (artboard != null) {
        artboard.frameOrigin = false;
        var bullet = Pickup(
          bulletType: b,
          scene: this,
          artboard: artboard,
          machine: artboard.defaultStateMachine()!,
          offset: _character.offset +
              (b == 0
                  ? rive.Vec2D.fromValues(
                      -250 + (-1 + _rand.nextDouble() * 2) * 250,
                      300 + _rand.nextDouble() * 30,
                    )
                  : rive.Vec2D.fromValues(
                      250 + (-1 + _rand.nextDouble() * 2) * 250,
                      300 + _rand.nextDouble() * 30,
                    )),
        );
        add(bullet);
      }
    }

    endingY += backgroundA.bounds.height * 1.5;
    _character.endingY = endingY;
    add(
      _ending = Ending(
        scene: this,
        artboard: end,
        offset: rive.Vec2D.fromValues(0, endingY),
        machine: endStateMachine,
      ),
    );
    add(
      _beggining = Beggining(
        scene: this,
        artboard: begin,
        offset: rive.Vec2D.fromValues(0, _character.offset.y - 800),
        machine: beginStateMachine,
      ),
    );
    setCamera(
        rive.Vec2D.fromValues(
            backgroundA.bounds.width / 2, backgroundA.bounds.height / 2),
        0.5);
  }

  bool _forceOver = false;

  bool get isOver =>
      _forceOver || _character.deadTime > 10 || (_ending?.isOver ?? false);

  bool get reachedEnd => _ending?.reachedEnd ?? false;

  void setCamera(rive.Vec2D translation, double zoom) {
    rive.Vec2D.copy(_cameraTranslation, translation);
    _cameraZoom = zoom;
  }

  void add(SceneObject object) {
    late AABBTree<SceneObject> tree;
    switch (object.classification) {
      case SceneClassification.character:
      case SceneClassification.sky:
        tree = _tree;
        break;
      default:
        tree = _staticTree;
        break;
    }

    double padding =
        object.classification == SceneClassification.character ? 10 : 0;
    object._sceneTreeProxy =
        tree.createProxy(object.aabb, object, padding: padding);
    objects.add(object);
  }

  void remove(SceneObject object) {
    object.dispose();
    late AABBTree<SceneObject> tree;
    switch (object.classification) {
      case SceneClassification.character:
      case SceneClassification.sky:
        tree = _tree;
        break;
      default:
        tree = _staticTree;
        break;
    }
    tree.removeLeaf(object._sceneTreeProxy);
    objects.remove(object);
  }

  static Future<Scene?> load() async {
    var files = <rive.File>[];
    var artboards = <rive.Artboard>[];
    var stateMachines = <rive.StateMachine>[];
    void cleanup() {
      for (final stateMachine in stateMachines) {
        stateMachine.dispose();
      }
      for (final artboard in artboards) {
        artboard.dispose();
      }
      for (final file in files) {
        file.dispose();
      }
    }

    rive.File? characterFile;
    rive.Artboard? character;
    rive.StateMachine? characterStateMachine;
    {
      var data = await rootBundle.load('assets/joel_v3.riv');
      var bytes = data.buffer.asUint8List();
      characterFile = rive.File.decode(bytes);
      if (characterFile == null) {
        return null;
      } else {
        files.add(characterFile);
        character = characterFile.artboard('Character');
        if (character == null) {
          cleanup();
          return null;
        }
        artboards.add(character);
        characterStateMachine = character.defaultStateMachine();
        if (characterStateMachine == null) {
          cleanup();
          return null;
        }
        stateMachines.add(characterStateMachine);
      }
    }
    rive.File? hpFile;
    rive.Artboard? hp;
    rive.StateMachine? hpStateMachine;
    {
      var data = await rootBundle.load('assets/hp_bar.riv');
      var bytes = data.buffer.asUint8List();
      hpFile = rive.File.decode(bytes);
      if (hpFile == null) {
        return null;
      } else {
        files.add(hpFile);
        hp = hpFile.artboard('health_bar');
        if (hp == null) {
          cleanup();
          return null;
        }
        artboards.add(hp);
        hpStateMachine = hp.defaultStateMachine();
        if (hpStateMachine == null) {
          cleanup();
          return null;
        }
        stateMachines.add(hpStateMachine);
      }
    }
    rive.File? joystickFile;
    rive.Artboard? joystick;
    rive.StateMachine? joystickStateMachine;
    {
      var data = await rootBundle.load('assets/joel_joystick.riv');
      var bytes = data.buffer.asUint8List();
      joystickFile = rive.File.decode(bytes);
      if (joystickFile == null) {
        return null;
      } else {
        files.add(joystickFile);
        joystick = joystickFile.artboard('joystick');
        if (joystick == null) {
          cleanup();
          return null;
        }
        joystick.frameOrigin = false;
        artboards.add(joystick);
        joystickStateMachine = joystick.defaultStateMachine();
        if (joystickStateMachine == null) {
          cleanup();
          return null;
        }
        stateMachines.add(joystickStateMachine);
      }
    }
    rive.Artboard? end;
    rive.StateMachine? endStateMachine;
    rive.Artboard? entry;
    rive.StateMachine? entryStateMachine;
    {
      var data = await rootBundle.load('assets/end.riv');
      var bytes = data.buffer.asUint8List();
      var file = rive.File.decode(bytes);
      if (file == null) {
        return null;
      } else {
        files.add(file);
        end = file.artboard('Fence');
        end?.frameOrigin = false;
        if (end == null) {
          cleanup();
          return null;
        }
        artboards.add(end);
        endStateMachine = end.defaultStateMachine();
        if (endStateMachine == null) {
          cleanup();
          return null;
        }
        stateMachines.add(endStateMachine);

        entry = file.artboard('Entry');
        entry?.frameOrigin = false;
        if (entry == null) {
          cleanup();
          return null;
        }
        artboards.add(entry);
        entryStateMachine = entry.defaultStateMachine();
        if (entryStateMachine == null) {
          cleanup();
          return null;
        }
        stateMachines.add(entryStateMachine);
      }
    }

    rive.File? zombie;
    {
      var data = await rootBundle.load('assets/zombies_separate.riv');
      var bytes = data.buffer.asUint8List();
      var file = rive.File.decode(bytes);
      if (file == null) {
        return null;
      } else {
        files.add(file);
        zombie = file;
      }
    }

    rive.File? bullets;
    {
      var data = await rootBundle.load('assets/bullets.riv');
      var bytes = data.buffer.asUint8List();
      var file = rive.File.decode(bytes);
      if (file == null) {
        return null;
      } else {
        files.add(file);
        bullets = file;
      }
    }

    var data = await rootBundle.load('assets/joel_background.riv');
    var bytes = data.buffer.asUint8List();
    var file = rive.File.decode(bytes);

    if (file == null) {
      cleanup();
      return null;
    } else {
      files.add(file);
      var backgroundA = file.artboard('Road_1');
      if (backgroundA == null) {
        cleanup();
        return null;
      }
      artboards.add(backgroundA);
      var backgroundB = file.artboard('Road_2');
      if (backgroundB == null) {
        cleanup();
        return null;
      }
      artboards.add(backgroundB);
      var shadowsA = file.artboard('Road_1_Shadows');
      if (shadowsA == null) {
        cleanup();
        return null;
      }
      artboards.add(shadowsA);
      var shadowsB = file.artboard('Road_2_Shadows');
      if (shadowsB == null) {
        cleanup();
        return null;
      }
      artboards.add(shadowsB);

      List<rive.Artboard> trees = [];
      for (int i = 1; i <= 4; i++) {
        var tree = file.artboard('Tree_$i');
        if (tree == null) {
          cleanup();
          return null;
        }
        tree.frameOrigin = false;
        artboards.add(tree);
        trees.add(tree);
      }

      List<rive.Artboard> clouds = [];
      for (int i = 1; i <= 3; i++) {
        var cloud = file.artboard('Cloud_$i');
        if (cloud == null) {
          cleanup();
          return null;
        }
        cloud.frameOrigin = false;
        artboards.add(cloud);
        clouds.add(cloud);
      }

      List<rive.Artboard> rocks = [];
      for (int i = 1; i <= 4; i++) {
        var rock = file.artboard('Rock_$i');
        if (rock == null) {
          cleanup();
          return null;
        }
        rock.frameOrigin = false;
        artboards.add(rock);
        rocks.add(rock);
      }
      var bush = file.artboard('Small Bush');
      if (bush == null) {
        cleanup();
        return null;
      }
      var bushStateMachine = bush.defaultStateMachine();
      bush.frameOrigin = false;
      artboards.add(bush);
      rocks.add(bush);

      // var crow = file.artboard('Crow_idle');
      // if (crow == null) {
      //   cleanup();
      //   return null;
      // }
      // var bushStateMachine = bush.defaultStateMachine();
      // bush.frameOrigin = false;
      // artboards.add(crow);

      return Scene._(
        cleanup,
        character: character,
        characterStateMachine: characterStateMachine,
        backgroundA: backgroundA,
        backgroundB: backgroundB,
        shadowsA: shadowsA,
        shadowsB: shadowsB,
        trees: trees,
        clouds: clouds,
        rocks: rocks,
        zombie: zombie,
        characterFile: characterFile,
        end: end,
        endStateMachine: endStateMachine,
        begin: entry,
        beginStateMachine: entryStateMachine,
        bullets: bullets,
        joystick: joystick,
        joystickStateMachine: joystickStateMachine,
        hp: hp,
        hpStateMachine: hpStateMachine,
        bushStateMachine: bushStateMachine,
      );
    }
  }

  void dispose() {
    _lastShadowPath?.dispose();
    _lastShadowPath = null;
    for (final object in objects) {
      object.dispose();
    }
    for (final machine in treeMachines) {
      machine.dispose();
    }
    for (final machine in cloudMachines) {
      machine.dispose();
    }
    _cleanup();
  }

  double _shake = 0;
  void shakeCamera(double direction) {
    _shake = direction;
  }

  bool _started = false;
  void start() {
    _started = true;
    _beggining?.start();
  }

  double y = 0;
  rive.RenderPath? _lastShadowPath;

  final rive.RenderPaint _shadowPaint = rive.Renderer.makePaint()
    ..blendMode = BlendMode.multiply
    ..style = PaintingStyle.fill
    ..color = const Color(0x5524161B);

  double _idleTime = 0;

  Size _size = Size.zero;
  Size get size => _size;
  void draw(rive.Renderer renderer, double elapsedSeconds, Size size) {
    _size = size;
    shadowBreezeA?.advance(elapsedSeconds);
    shadowBreezeB?.advance(elapsedSeconds);

    y += elapsedSeconds;
    y = 0;

    var targetZoom = 1.0;
    var zoomSpeed = 3.0;
    var targetCameraOffset = rive.Vec2D.fromValues(0, size.height / 3.9);

    if (!_started) {
      zoomSpeed = 0.3;
      targetZoom = 0.7;
      targetCameraOffset = rive.Vec2D.fromValues(0, 0);
    } else {
      switch (_character.state) {
        case HeroState.dead:
          zoomSpeed = 0.3;
          targetZoom = 2.2;
          targetCameraOffset.y = 0;
          joystickArrow?.value = false;
          joystickShooting?.value = false;
          break;
        case HeroState.idle:
          _idleTime += elapsedSeconds;
          if (_idleTime > 3) {
            _character.showBubble();
          }
          if (_idleTime > 2) {
            targetCameraOffset.y = 0;
            zoomSpeed = 0.3;
            targetZoom = 1.9;
          } else {
            targetZoom = 0.7;
            zoomSpeed = 4;
          }
          joystickArrow?.value = false;
          joystickShooting?.value = false;
          break;
        case HeroState.aiming:
          _character.hideBubble();
          _idleTime = 0;
          targetZoom = 0.75;
          joystickArrow?.value = false;
          joystickShooting?.value = false;
          break;
        case HeroState.firing:
          _idleTime = 0;
          targetZoom = 0.83;
          joystickShooting?.value = true;
          joystickArrow?.value = false;
          break;
        case HeroState.walkingAndFiring:
          joystickShooting?.value = true;
          joystickArrow?.value = true;
          _idleTime = 0;
          targetZoom = 0.6 * 1.5;
          break;
      }
    }

    var zoom = _cameraZoom +
        (targetZoom - _cameraZoom) * min(1, elapsedSeconds * zoomSpeed);
    setCamera(_character.offset + _cameraOffset, zoom);

    var ct = _cameraTranslation +
        rive.Vec2D.fromValues(
          _rand.nextDouble() * _shake * 35,
          0, //(_rand.nextDouble() * 2.0 - 1.0) * _shake.abs() * 10,
        );
    _shake += (0 - _shake) * min(1, elapsedSeconds * 5);
    _cameraOffset +=
        (targetCameraOffset - _cameraOffset) * min(1, elapsedSeconds);
    _viewTransform[0] = _cameraZoom;
    _viewTransform[1] = 0;
    _viewTransform[2] = 0;
    _viewTransform[3] = _cameraZoom;
    _viewTransform[4] = -ct.x * _cameraZoom + size.width / 2.0;
    _viewTransform[5] = -ct.y * _cameraZoom + size.height / 2.0;

    rive.Mat2D.invert(_inverseViewTransform, _viewTransform);
    var cameraAABB = rive.AABB.fromPoints(
      [
        rive.Vec2D.fromValues(0, 0),
        rive.Vec2D.fromValues(size.width, 0),
        rive.Vec2D.fromValues(size.width, size.height),
        rive.Vec2D.fromValues(0, size.height),
      ],
      transform: _inverseViewTransform,
    );

    renderer.save();
    renderer.transform(_viewTransform);

    var shadows = <ShadowSceneObject>[];
    var dynamicObjects = <DynamicSceneObject>[_character];
    var deadZombies = <DynamicSceneObject>[];
    var skyObjects = <DynamicSceneObject>[];
    var ground = <StaticSceneObject>[];

    _staticTree.query(cameraAABB, (proxy, object) {
      switch (object.classification) {
        case SceneClassification.shadow:
          shadows.add(object as ShadowSceneObject);
          break;
        case SceneClassification.ground:
          ground.add(object as StaticSceneObject);

          break;
        default:
          break;
      }
      return true;
    });

    ground.sort((a, b) => a.offset.y.compareTo(b.offset.y));
    for (final groundObject in ground) {
      groundObject.draw(renderer);
    }

    _tree.query(cameraAABB, (proxy, object) {
      switch (object.classification) {
        case SceneClassification.sky:
          skyObjects.add(object as DynamicSceneObject);
          break;
        case SceneClassification.character:
          if (object is ZombieSceneObject) {
            if (object.isDead) {
              deadZombies.add(object);
            } else {
              dynamicObjects.add(object);
            }
          } else {
            dynamicObjects.add(object as DynamicSceneObject);
          }
          break;
        default:
          break;
      }
      return true;
    });

    dynamicObjects.sort((a, b) => a.offset.y.compareTo(b.offset.y));
    deadZombies.sort((a, b) => a.offset.y.compareTo(b.offset.y));
    skyObjects.sort((a, b) => a.offset.y.compareTo(b.offset.y));

    List<SceneObject> toRemove = [];
    List<rive.StateMachine> batchMachines = [
      joystickStateMachine,
      ...treeMachines,
      ...cloudMachines,
      if (bushStateMachine != null) bushStateMachine!
    ];

    // store zombies separate so we can render them in a batch
    List<rive.StateMachine> batchAndRender = [];
    List<rive.StateMachine> batchAndRenderSky = [];
    List<DynamicSceneObject> mainRenderList = [];
    List<DynamicSceneObject> skyRenderList = [];

    for (final dob in deadZombies) {
      if (!dob.advance(elapsedSeconds)) {
        toRemove.add(dob);
      } else if (useBatchAndRender) {
        batchAndRender.add(dob.machine);
      } else {
        batchMachines.add(dob.machine);
        mainRenderList.add(dob);
      }
    }
    for (final dob in dynamicObjects) {
      if (!dob.advance(elapsedSeconds)) {
        toRemove.add(dob);
      } else if (useBatchAndRender) {
        if (dob.doesDraw) {
          batchAndRender.add(dob.machine);
        }
      } else {
        batchMachines.add(dob.machine);
        mainRenderList.add(dob);
      }
    }
    _character.addBatchMachines(batchAndRenderSky);
    for (final skyObject in skyObjects) {
      if (!skyObject.advance(elapsedSeconds)) {
        toRemove.add(skyObject);
      } else if (useBatchAndRender) {
        batchAndRenderSky.add(skyObject.machine);
      } else {
        batchMachines.add(skyObject.machine);
        skyRenderList.add(skyObject);
      }
    }
    toRemove.forEach(remove);

    if (useBatchAndRender) {
      rive.Rive.batchAdvanceAndRender(batchAndRender, elapsedSeconds, renderer);
    }
    rive.Rive.batchAdvance(batchMachines, elapsedSeconds);
    if (!useBatchAndRender) {
      for (final dob in mainRenderList) {
        dob.draw(renderer);
      }
    }

    // Draw shadows.
    _lastShadowPath?.dispose();
    var shadowPath = rive.Renderer.makePath(true);
    for (final shadow in shadows) {
      shadow.addToPath(shadowPath);
    }
    _lastShadowPath = shadowPath;
    renderer.drawPath(shadowPath, _shadowPaint);

    _character.drawProjectiles(renderer);

    // Draw overlay
    // First get a parallax camera.
    var parallax = ParallaxCamera.fromViewTransform(
      size,
      _viewTransform,
      scale: rive.Vec2D.fromValues(1.05, 1.15),
    );

    renderer.restore();
    renderer.save();
    renderer.transform(parallax.viewTransform);

    // Apply the new view transform which also computes a new viewAABB which we
    // can use to cull exactly what is visible.
    _staticTree.query(parallax.bounds, (proxy, object) {
      switch (object.classification) {
        case SceneClassification.parallax:
          object.draw(renderer);

          break;
        default:
          break;
      }
      return true;
    });

    renderer.restore();

    var highParallax = ParallaxCamera.fromViewTransform(size, _viewTransform,
        scale: rive.Vec2D.fromValues(1.3, 1.3));
    renderer.save();
    renderer.transform(highParallax.viewTransform);

    // Apply the new view transform which also computes a new viewAABB which we
    // can use to cull exactly what is visible.
    _staticTree.query(highParallax.bounds, (proxy, object) {
      switch (object.classification) {
        case SceneClassification.highParallax:
          object.draw(renderer);

          break;
        default:
          break;
      }
      return true;
    });

    renderer.restore();

    renderer.save();
    renderer.transform(_viewTransform);
    if (useBatchAndRender) {
      rive.Rive.batchAdvanceAndRender(
          batchAndRenderSky, elapsedSeconds, renderer);
    } else {
      _character.drawEffects(renderer);
      for (final dob in skyRenderList) {
        dob.draw(renderer);
      }
    }

    renderer.restore();

    if (!_character.isDead) {
      renderer.save();
      renderer.transform(_joystickRenderTransform);
      joystick.draw(renderer);
      renderer.restore();
    }
  }

  rive.Vec2D? _touchPosition;
  final rive.Mat2D _inverseJoystickTransform = rive.Mat2D();
  rive.Mat2D _joystickRenderTransform = rive.Mat2D();

  void onPointerDown(PointerDownEvent event) {
    if (!_started) {
      return;
    }
    if (_character.isDead && _character.deadTime > 1) {
      _forceOver = true;
      return;
    }
    _touchPosition = rive.Vec2D.fromOffset(event.localPosition);
    _character.onPointerDown(rive.Vec2D.fromOffset(event.localPosition));
    joystickActive?.value = true;
    var transform = rive.Mat2D.fromTranslation(_touchPosition!);
    rive.Mat2D.invert(_inverseJoystickTransform, transform);

    _joystickRenderTransform =
        rive.Mat2D.fromTranslation(_touchPosition! * window.devicePixelRatio);

    joystickCursor?.worldTransform = rive.Mat2D();
  }

  void onPointerMove(PointerMoveEvent event) {
    if (!_started) {
      return;
    }
    var pointerPosition = rive.Vec2D.fromOffset(event.localPosition);
    _character.onPointerMove(
        pointerPosition, rive.Vec2D.fromOffset(event.localDelta));

    var localTouchPosition = _inverseJoystickTransform * pointerPosition;
    joystickCursor
        ?.setLocalFromWorld(rive.Mat2D.fromTranslation(localTouchPosition));
  }

  void onPointerUp(PointerUpEvent event) {
    if (!_started) {
      return;
    }
    _touchPosition = null;
    _character.onPointerUp(rive.Vec2D.fromOffset(event.localPosition));
    joystickActive?.value = false;
  }
}
