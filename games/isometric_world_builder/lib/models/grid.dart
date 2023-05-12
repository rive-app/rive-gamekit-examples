import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:isometric_world_builder/models/tile.dart';
import 'package:isometric_world_builder/utils/aabb_tree.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

/// A collection of [Tile]s that are arranged in a grid.
///
/// The [Grid] is responsible for creating the [Tile]s and
/// arranging them in a grid.
///
/// Use [skewTransform] to get the skew of the grid.
class Grid {
  final TileData startingTile;

  var tree = AABBTree<Tile>();
  List<Tile> tiles = [];

  final offsetFactor = 1.28;

  Grid(
    this.startingTile, {
    this.gridSizeX = 5,
    this.gridSizeY = 5,
  }) {
    skewTransform[0] = 0.5;
    skewTransform[1] = 0.25 * offsetFactor;
    skewTransform[2] = -0.5;
    skewTransform[3] = 0.25 * offsetFactor;

    _createGrid();
  }

  late final skewTransform = rive.Mat2D();

  final int gridSizeX;
  final int gridSizeY;

  static const double tileWidth = 500; // This needs to match the Rive artboard
  static const double tileHeight = 500; // This needs to match the Rive artboard

  double get gridWidth => tileWidth * gridSizeX;
  double get gridHeight => tileHeight * gridSizeY;

  void _createGrid() {
    for (var x = 0; x <= gridSizeX; x++) {
      for (var y = 0; y <= gridSizeY; y++) {
        final tile = Tile(startingTile, Coordinates(x, y), skewTransform);
        tile.proxyId = tree.createProxy(tile.bounds, tile, padding: 0);
        tiles.add(tile);
      }
    }
  }

  void updateGrid(int rows, int columns) {
    try {
      final updatedTiles = <Tile>[];
      final updatedTree = AABBTree<Tile>();

      /// A key/value cache for all tiles. Tiles will be reused if their
      /// position is still in the grid.
      final cachedTiles = <String, Tile>{};
      for (final tile in tiles) {
        cachedTiles['${tile.coordinates.x},${tile.coordinates.y}'] = tile;
      }

      for (var x = 0; x <= columns; x++) {
        for (var y = 0; y <= rows; y++) {
          late Tile tile;

          final cached = cachedTiles['$x,$y'];

          /// Tile is reused - remove from cached tiles as the rest will
          /// be disposed.
          cachedTiles.remove('$x,$y');

          if (cached != null) {
            tile = cached;
          } else {
            tile = Tile(startingTile, Coordinates(x, y), skewTransform);
          }
          tile.proxyId = updatedTree.createProxy(tile.bounds, tile, padding: 0);
          updatedTiles.add(tile);
        }
      }

      // Dispose of tiles that are no longer used.
      cachedTiles.forEach((key, value) {
        value.dispose();
      });

      tiles = updatedTiles;
      tree = updatedTree;
    } on Error catch (e, st) {
      log('Could not update grid', error: e, stackTrace: st);
      debugPrint(e.toString());
    }
  }

  void dispose() {
    for (var tile in tiles) {
      tile.dispose();
    }
  }
}
