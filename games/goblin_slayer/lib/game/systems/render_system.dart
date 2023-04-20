import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:goblin_slayer/aabb_tree.dart';
import 'package:goblin_slayer/extensions/queries.dart';
import 'package:goblin_slayer/game/components/artboard_component.dart';
import 'package:goblin_slayer/game/components/collision_component.dart';
import 'package:goblin_slayer/game/components/enemy_component.dart';
import 'package:goblin_slayer/game/components/ground_component.dart';
import 'package:goblin_slayer/game/components/obstacle_component.dart';
import 'package:goblin_slayer/game/components/player_component.dart';
import 'package:goblin_slayer/game/components/position_component.dart';
import 'package:goblin_slayer/game/components/state_machine_component.dart';
import 'package:goblin_slayer/game/state/game_state.dart';
import 'package:goblin_slayer/main.dart';
import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;
import 'package:goblin_slayer/extensions/input.dart';

import '../constants.dart';

/// System responsible for rendering all game entities.
class RenderSystem extends System {
  late final GameState _gameState;
  late _PlayerRenderer _playerRenderer;
  late _StaticRenderer _staticRenderer;
  late AABBTree<Entity> _staticTree;
  late AABBTree<Entity> _tree;
  late Query collisionPaintQuery;

  final rive.Mat2D _viewTransform = rive.Mat2D();
  final rive.Mat2D _inverseViewTransform = rive.Mat2D();
  final rive.Vec2D _cameraTranslation = rive.Vec2D();
  rive.AABB _cameraAABB = rive.AABB();
  late double _cameraZoom;

  RenderSystem({super.priority = 5});

  @override
  void init() {
    _gameState = world!.gameState;
    _staticTree = world!.retrieve<AABBTree<Entity>>(Constants.staticTree)!;
    _tree = world!.retrieve<AABBTree<Entity>>(Constants.tree)!;
    _playerRenderer = _PlayerRenderer(createQuery);
    _staticRenderer = _StaticRenderer();

    collisionPaintQuery = createQuery([
      Has<CollisionComponent>(),
    ]);
  }

  final DynamicAnimatable<double> _dynamicZoom = DynamicAnimatable(
    start: 1,
    target: 1,
  );

  final DynamicAnimatable<rive.Vec2D> _dynamicPosition = DynamicAnimatable(
    start: rive.Vec2D.fromValues(0, 0),
    target: rive.Vec2D.fromValues(0, 0),
  );

  static const baseZoom = 0.2;

  @override
  void execute(double delta) {
    final renderer = rive.Renderer.make();

    switch (_gameState.status) {
      case GameStatus.startMenu:
      case GameStatus.paused:
        _dynamicZoom.setTarget(
          1 * window.devicePixelRatio,
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOut,
        );
        _dynamicPosition.setTarget(
          _playerRenderer.offset +
              _playerRenderer.bounds.center() +
              rive.Vec2D.fromValues(0, -300),
          duration: const Duration(milliseconds: 750),
          curve: Curves.easeOut,
        );
        break;
      case GameStatus.playing:
        _dynamicPosition.setTarget(
          _playerRenderer.offset + _playerRenderer.bounds.center(),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
        _dynamicZoom.setTarget(
          baseZoom * 2 * window.devicePixelRatio,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
        break;
      case GameStatus.gameOver:
        _gameOverZoomIn(delta);
        break;
    }

    _dynamicZoom.tick(delta);
    _dynamicPosition.tick(delta);
    _setCamera(_dynamicPosition.current, _dynamicZoom.current);

    // Save the renderer before applying the camera transform.
    renderer.save();

    // Position the camera.
    _positionCamera(renderer);

    // Draw scene
    {
      final ground = <Entity>[];
      // Dyanamic entities are sorted by their y position so that they are
      // rendered in the correct order.
      //
      // They may also have a state machine, which is used to update the
      // animation.
      final dynamicEntities = <Entity>[_playerRenderer.player];
      final dynamicStateMachines = <rive.StateMachine>[];

      _staticTree.query(_cameraAABB, (id, object) {
        if (object.has<GroundComponent>()) {
          ground.add(object);
          dynamicStateMachines
              .add(object.get<StateMachineComponent>()!.stateMachine);
        } else if (object.has<ObstacleComponent>()) {
          dynamicEntities.add(object); // does not have a state machine
        }

        return true;
      });

      _tree.query(_cameraAABB, (id, object) {
        if (object.has<EnemyComponent>()) {
          if (object.get<EnemyComponent>()!.isDead) {
            ground.add(object);
          } else {
            dynamicEntities.add(object);
          }
          dynamicStateMachines
              .add(object.get<StateMachineComponent>()!.stateMachine);
        }

        return true;
      });

      dynamicEntities.sort((a, b) {
        final aPosition = a.get<PositionComponent>()!;
        final bPosition = b.get<PositionComponent>()!;
        return aPosition.y.compareTo(bPosition.y);
      });

      // Render the static components.
      _staticRenderer.draw(renderer, ground);

      if (_gameState.shouldAdvance) {
        rive.Rive.batchAdvance(dynamicStateMachines, delta);
      }
      if (!_gameState.isPaused) {
        _playerRenderer.advance(delta);
      }

      for (var element in dynamicEntities) {
        final artboard = element.get<ArtboardComponent>()!.artboard;
        final position = element.get<PositionComponent>()!;
        renderer.save();
        renderer.translate(position.x, position.y);
        artboard.draw(renderer);
        renderer.restore();
      }

      _debugPaint(renderer);
    }

    renderer.restore();
  }

  void _gameOverZoomIn(double delta) {
    _dynamicZoom.setTarget(
      1.5 * window.devicePixelRatio,
      duration: const Duration(milliseconds: 900),
      curve: Curves.bounceOut,
    );
    _dynamicPosition.setTarget(
      _playerRenderer.offset + _playerRenderer.bounds.center(),
      duration: const Duration(milliseconds: 900),
      curve: Curves.bounceOut,
    );
  }

  void _positionCamera(rive.Renderer renderer) {
    final size = world!.windowSize;

    _viewTransform[0] = _cameraZoom;
    _viewTransform[1] = 0;
    _viewTransform[2] = 0;
    _viewTransform[3] = _cameraZoom;
    _viewTransform[4] = -_cameraTranslation.x * _cameraZoom + size.width / 2.0;
    _viewTransform[5] = -_cameraTranslation.y * _cameraZoom + size.height / 2.0;

    rive.Mat2D.invert(_inverseViewTransform, _viewTransform);

    _cameraAABB = rive.AABB.fromPoints(
      [
        rive.Vec2D.fromValues(0, 0),
        rive.Vec2D.fromValues(size.width, 0),
        rive.Vec2D.fromValues(size.width, size.height),
        rive.Vec2D.fromValues(0, size.height),
      ],
      transform: _inverseViewTransform,
    );

    renderer.transform(_viewTransform);
  }

  void _setCamera(rive.Vec2D translation, double zoom) {
    // This represent the smallest zoom factor that can be applied for the
    // the current screen size.
    final minimumZoom = max(world!.windowSize.width / world!.worldSize.width,
        world!.windowSize.height / world!.worldSize.height);
    zoom = max(zoom, minimumZoom);

    rive.Vec2D.copy(_cameraTranslation, translation);
    _cameraZoom = zoom;

    // Constrain the camera to the world bounds.
    final maxX = world!.worldSize.width - world!.windowSize.width / 2 / zoom;
    final minX = world!.windowSize.width / 2 / zoom;
    final maxY = world!.worldSize.height - world!.windowSize.height / 2 / zoom;
    final minY = world!.windowSize.height / 2 / zoom;

    // Constrain x bounds
    if (_cameraTranslation.x > maxX) {
      _cameraTranslation.x = maxX;
    } else if (_cameraTranslation.x < minX) {
      _cameraTranslation.x = minX;
    }

    // Constrain y bounds
    if (_cameraTranslation.y > maxY) {
      _cameraTranslation.y = maxY;
    } else if (_cameraTranslation.y < minY) {
      _cameraTranslation.y = minY;
    }
  }

  void _debugPaint(rive.Renderer renderer) {
    if (!debugGame) return;

    final collisionEntities = collisionPaintQuery.entities;
    for (var element in collisionEntities) {
      final collisionBounds = element.get<CollisionComponent>()!.value!;
      final position = element.get<PositionComponent>()!.position;
      final x = position.x + collisionBounds.minX;
      final y = position.y + collisionBounds.minY;

      final path = rive.Renderer.makePath();
      final paint = rive.Renderer.makePaint()
        ..style = PaintingStyle.stroke
        ..thickness = 4
        ..color = Colors.red;

      path.moveTo(x, y);
      path.lineTo(x + collisionBounds.width, y);
      path.lineTo(x + collisionBounds.width, y + collisionBounds.height);
      path.lineTo(x, y + collisionBounds.height);
      path.close();

      renderer.drawPath(path, paint);
    }
  }
}

/// Class responsible for rendering the player.
class _PlayerRenderer {
  final CreateQuery createQuery;

  late rive.Artboard artboard;
  late rive.StateMachine stateMachine;
  late PositionComponent position;
  late Entity player;
  late PlayerComponent playerComponent;

  rive.AABB get bounds => artboard.bounds;
  rive.Vec2D get offset => position.position;

  _PlayerRenderer(this.createQuery) {
    final query = createQuery([
      Has<PlayerComponent>(),
      Has<PositionComponent>(),
      Has<ArtboardComponent>(),
      Has<StateMachineComponent>(),
    ]);
    player = query.entities.first;

    playerComponent = player.get<PlayerComponent>()!;
    position = player.get<PositionComponent>()!;
    artboard = player.get<ArtboardComponent>()!.artboard;
    stateMachine = player.get<StateMachineComponent>()!.stateMachine;
  }

  void advance(elapsedSeconds) {
    stateMachine.advance(elapsedSeconds);
  }

  void draw(rive.Renderer renderer) {
    renderer.save();
    renderer.translate(position.x, position.y);
    artboard.draw(renderer);
    renderer.restore();
  }
}

class _StaticRenderer {
  draw(rive.Renderer renderer, List<Entity> ground) {
    for (var element in ground) {
      final artboard = element.get<ArtboardComponent>()!.artboard;
      final position = element.get<PositionComponent>()!.position;
      renderer.save();
      renderer.translate(position.x, position.y);
      artboard.draw(renderer);
      renderer.restore();
    }
  }
}

class DynamicAnimatable<T> {
  T start;
  T target;
  late T current;
  Duration duration;
  Curve curve;
  double elapsedTime = 0;

  DynamicAnimatable({
    required this.start,
    required this.target,
    this.duration = defaultDuration,
    this.curve = defaultCurve,
  }) {
    current = start;
  }

  late final baseTween = Tween<T>(begin: start, end: target);

  late final Animatable<T> _animatable = baseTween.chain(
    CurveTween(curve: curve),
  );

  static const Curve defaultCurve = Curves.linear;
  static const Duration defaultDuration = Duration(milliseconds: 750);

  void setTarget(
    T value, {
    Curve curve = defaultCurve,
    Duration duration = defaultDuration,
  }) {
    if (value == target) return;

    this.duration = duration;
    this.curve = curve;
    elapsedTime = 0;
    start = current;
    target = value;

    baseTween.begin = start;
    baseTween.end = target;
  }

  void immediateSetTarget(T value) {
    target = value;
    start = value;
    current = value;
    elapsedTime = duration.inMilliseconds.toDouble();
  }

  void tick(double delta) {
    elapsedTime += delta;
    final time = elapsedTime * 1000;
    if (current == target || time >= duration.inMilliseconds) return;
    final t = min(time, duration.inMilliseconds);
    current = _animatable.transform(t / duration.inMilliseconds);
  }
}
