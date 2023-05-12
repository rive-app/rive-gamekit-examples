import 'package:isometric_world_builder/models/tile.dart';

abstract class Data {
  /// A collection of [TileData]s that are used to create [Tile]s.
  static final tileData = {
    'P1': TileData(
      id: "P1",
      name: 'ground',
      artboardName: 'Ground',
    ),
    'P2': TileData(
      id: "P2",
      name: 'trees',
      artboardName: 'Threes', // TODO: fix name
    ),
    'P3': TileData(
      id: "P3",
      name: 'buildings',
      artboardName: 'Buildings',
    ),
    'P4': TileData(
      id: "P4",
      name: 'mountains',
      artboardName: 'Mountains',
    ),
  };
}
