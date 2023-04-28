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
  // final List<TileData> tileData;
  final TileData startingTile;

  final tree = AABBTree<Tile>();
  List<Tile> tiles = [];

  final offsetFactor = 1.27;

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
    for (var y = 0; y <= gridSizeX; y++) {
      for (var x = 0; x <= gridSizeY; x++) {
        final tile = Tile(startingTile, Coordinates(x, y), skewTransform);
        tile.proxyId = tree.createProxy(tile.bounds, tile, padding: 0);
        tiles.add(tile);
      }
    }
  }

  void dispose() {
    for (var tile in tiles) {
      tile.dispose();
    }
  }
}
