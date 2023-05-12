import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:isometric_world_builder/utils/aabb_tree.dart';
import 'package:isometric_world_builder/models/models.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class WorldPainter extends rive.RenderTexturePainter with PointerInput {
  WorldPainter(
    this.grid,
    this.selectedTile,
    this.selectionArtboard,
  ) : selectionStateMachine = selectionArtboard.defaultStateMachine()!;

  final Grid grid;
  final ValueNotifier<TileData?> selectedTile;
  final rive.Artboard selectionArtboard;
  final rive.StateMachine selectionStateMachine;

  final rive.Mat2D _viewTransform = rive.Mat2D();
  final rive.Mat2D _inverseViewTransform = rive.Mat2D();
  final rive.Mat2D _inverseSkewTransform = rive.Mat2D();

  rive.Vec2D _localCursor = rive.Vec2D.fromValues(0, 0);

  final rive.Vec2D _cameraPosition = rive.Vec2D.fromValues(0, 0);

  final startingZoom = 0.3 * window.devicePixelRatio;
  late double _zoom = startingZoom;
  late double _zoomStart = startingZoom;

  Tile? _hoveredTile;

  rive.Vec2D get _worldCursor =>
      _inverseViewTransform * _localCursor * (1 / _zoom);

  void _positionCameraOnStart(Size size) {
    final pos = rive.Vec2D.fromValues(0, 0);
    final before = _inverseViewTransform * pos;
    final after = _inverseViewTransform * pos * (1 / startingZoom);
    final offset = grid.skewTransform * (after - before);

    _cameraPosition.x += offset.x * _zoom +
        (size.width / 2) -
        ((Grid.tileWidth / 2) * startingZoom);
    _cameraPosition.y += offset.y * _zoom;
  }

  @override
  void onHover(PointerEvent event) {
    _localCursor =
        rive.Vec2D.fromOffset(event.localPosition * window.devicePixelRatio);
  }

  // Keep track of the last pointer button that was pressed down.
  int _lastButtonEvent = 0;

  @override
  void onPointerUp(PointerUpEvent event) {
    if (_lastButtonEvent == kSecondaryMouseButton) {
      _isPanning = false;
    }

    if (_hoveredTile == null || _lastButtonEvent != kPrimaryButton) return;
    if (selectedTile.value == null) {
      _hoveredTile!.triggeTileCycle();
    } else {
      _hoveredTile!.updateTile(selectedTile.value!);
    }
  }

  bool _isPanning = false;

  @override
  void onPointerDown(PointerDownEvent event) {
    _lastButtonEvent = event.buttons;
    if (event.buttons == kSecondaryMouseButton) {
      _isPanning = true;
    }
  }

  @override
  void onPointerMove(PointerMoveEvent event) {
    if (_hoveredTile?.tileData != null &&
        selectedTile.value != null &&
        _lastButtonEvent != kSecondaryMouseButton) {
      _hoveredTile!.paint(selectedTile.value!);
    }

    _localCursor =
        rive.Vec2D.fromOffset(event.localPosition * window.devicePixelRatio);

    if (event.buttons == kSecondaryMouseButton) {
      _cameraPosition.x += event.delta.dx * window.devicePixelRatio;
      _cameraPosition.y += event.delta.dy * window.devicePixelRatio;
    }
  }

  @override
  void onPointerScrollEvent(PointerScrollEvent event) {
    /// Handles zoom with a mouse.
    final before = _worldCursor;
    final zoomAmount = event.scrollDelta.dy / 1000;
    _zoom = clampDouble(_zoom - zoomAmount, 0.1, 6);
    final after = _worldCursor;

    final offset = grid.skewTransform * (after - before);

    _cameraPosition.x += offset.x * _zoom;
    _cameraPosition.y += offset.y * _zoom;
  }

  @override
  void onScaleStart(ScaleStartDetails event) {
    _zoomStart = _zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateDetails event) {
    final before = _worldCursor;

    final double desiredScale = _zoomStart * event.scale;
    final double scaleChange = desiredScale / _zoom;

    _zoom = clampDouble(_zoom * scaleChange, 0.1, 6.0);
    final after = _worldCursor;
    final offset = grid.skewTransform * (after - before);
    _cameraPosition.x += offset.x * _zoom;
    _cameraPosition.y += offset.y * _zoom;
  }

  @override
  void onScaleEnd(ScaleEndDetails event) {}

  bool firstLoad = true;

  @override
  bool paint(rive.RenderTexture texture, Size size, double elapsedSeconds) {
    if (firstLoad) {
      _positionCameraOnStart(size);
      firstLoad = false;
    }

    final renderer = rive.Renderer.make();

    // Set the zoom level
    _viewTransform[0] = _zoom;
    _viewTransform[1] = 0;
    _viewTransform[2] = 0;
    _viewTransform[3] = _zoom;

    // Move the origin to the center of the map
    _viewTransform[4] = _cameraPosition.x;
    _viewTransform[5] = _cameraPosition.y;

    // Create a Mat2D to apply the skew transform to.
    final skewViewTransform = rive.Mat2D();

    // Copy the skew transform from the grid to the skewViewTransform.
    rive.Mat2D.copy(skewViewTransform, grid.skewTransform);

    // Set the translation values for the skewViewTransform.
    skewViewTransform[4] = _viewTransform[4];
    skewViewTransform[5] = _viewTransform[5];

    // Save the renderer's current state.
    renderer.save();

    // Apply the view transform to the renderer.
    renderer.transform(_viewTransform);

    // Do not update the hovered tile while panning
    if (!_isPanning) {
      for (final tile in grid.tiles) {
        // Set the onHover input to false for all artboards.
        tile.onHover(false);
        _hoveredTile = null;
      }

      // If the view transform can be inverted, then we can transform the cursor
      // from local coordinates to world coordinates. This allows us to use the
      // world coordinates to find the artboard that is currently under the cursor.
      if (rive.Mat2D.invert(_inverseViewTransform, skewViewTransform)) {
        final worldCursor = _worldCursor;

        // Iterate over all artboards in the grid and perform a raycast against them
        // to see if any of them intersect with the cursor. If so, set the onHover
        // input to true.
        grid.tree.raycast(
          RaySegment(worldCursor, worldCursor),
          (ray, id, tile) {
            _hoveredTile = tile;
            tile.onHover(true);
            return -1;
          },
        );
      }
    }

    rive.Mat2D.invert(
        _inverseSkewTransform, _viewTransform.mul(grid.skewTransform));
    // slightly expand the camera AABB to account for tiles that draw outside
    // of their bounds - for example the tall trees. This ensures that they
    // are still drawn when they are partially off screen.
    final popinPadding = 750 * _zoom;
    final cameraAABB = rive.AABB.fromPoints([
      rive.Vec2D.fromValues(0, 0),
      rive.Vec2D.fromValues(size.width, 0),
      rive.Vec2D.fromValues(
          size.width + popinPadding, size.height + popinPadding),
      rive.Vec2D.fromValues(-popinPadding, size.height + popinPadding),
    ], transform: _inverseSkewTransform);

    final List<Tile> tilesToRender = [];
    grid.tree.query(cameraAABB, (id, tile) {
      tilesToRender.add(tile);
      return true;
    });

    tilesToRender.sort((a, b) => a.position.y.compareTo(b.position.y));

    // Advance and render all state machines in the grid.
    rive.Rive.batchAdvanceAndRender(
        tilesToRender.map((e) => e.sm), elapsedSeconds, renderer);

    // Paint selection/hover tile
    {
      if (_hoveredTile != null) {
        renderer.save();
        final transform = _hoveredTile!.artboard.renderTransform;
        renderer.translate(transform[4], transform[5]);
        selectionArtboard.draw(renderer);
        renderer.restore();
      }
    }

    // Restore the renderer state.
    renderer.restore();

    return true;
  }

  @override
  Color get background => Colors.transparent;
  static Color backgroundColorLight = const Color(0xFFFEE6D7);
  static Color backgroundColorDark = const Color(0xFF64535B);

  @override
  void dispose() {
    selectionStateMachine.dispose();
    selectionArtboard.dispose();
    grid.dispose();
    super.dispose();
  }
}

mixin PointerInput {
  void onHover(PointerEvent event);
  void onPointerUp(PointerUpEvent event);
  void onPointerDown(PointerDownEvent event);
  void onPointerMove(PointerMoveEvent event);
  void onPointerScrollEvent(PointerScrollEvent event);
  void onScaleStart(ScaleStartDetails event);
  void onScaleUpdate(ScaleUpdateDetails event);
  void onScaleEnd(ScaleEndDetails event);
}
