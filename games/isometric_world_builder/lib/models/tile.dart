import 'package:rive_gamekit/rive_gamekit.dart' as rive;

/// [TileData] is a data class that holds the information about a tile.
class TileData {
  final String id;
  final String name;
  final String artboardName;

  late final rive.File file;

  TileData({
    required this.id,
    required this.name,
    required this.artboardName,
  });

  rive.Artboard artboard() => file.artboard(artboardName)!;

  @override
  bool operator ==(covariant TileData other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.name == name &&
        other.artboardName == artboardName;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ artboardName.hashCode;
}

/// Contains the coordinate data for the grid.
class Coordinates {
  final int x;
  final int y;

  const Coordinates(this.x, this.y);
}

/// The [Tile] is a wrapper around the [TileData] that contains
/// the [artboard] and the [StateMachine] for the tile.
///
/// The [Tile] is also responsible for updating the [TileData] and
/// swapping the [artboard] and [StateMachine] when the [TileData] changes.
///
/// It also contains the [Coordinates] of the tile in the grid and the
/// [proxyId] for the [AABBTree].
class Tile {
  int proxyId = -1;
  TileData tileData;
  final rive.Mat2D transform;
  final Coordinates coordinates;

  late final rive.Vec2D position;
  late final rive.Vec2D worldOffset;
  late final rive.AABB bounds;

  late rive.Artboard artboard;
  late rive.StateMachine sm;
  late rive.BooleanInput onHoverInput;
  late rive.TriggerInput swapTrigger;
  late rive.TriggerInput removeTrigger;

  // static const _boundsOffset = 250;
  static const _boundsOffset = 0;

  Tile(
    this.tileData,
    this.coordinates,
    this.transform,
  ) {
    _initRive();

    worldOffset = rive.Vec2D.fromValues(artboard.bounds.width * coordinates.x,
        artboard.bounds.height * coordinates.y);

    bounds = artboard.bounds
        .offset(worldOffset.x + 500, worldOffset.y + _boundsOffset);

    position = rive.Vec2D.fromValues(
            coordinates.x.toDouble() * artboard.bounds.width,
            coordinates.y.toDouble() * artboard.bounds.height)
        .apply(transform);

    _setPosition();
  }

  void _initRive() {
    artboard = tileData.artboard();
    sm = artboard.defaultStateMachine()!;
    onHoverInput = sm.boolean('IsHover')!;
    swapTrigger = sm.trigger('Tree')!; // TODO: change name to Swap
    removeTrigger = sm.trigger('remove')!;
  }

  void _setPosition() {
    final view = rive.Mat2D.fromTranslate(
      position.x,
      position.y,
    );

    artboard.renderTransform = view;
  }

  void onClick() {
    swapTrigger.fire();
  }

  void onHover(bool value) {
    if (onHoverInput.value != value) {
      onHoverInput.value = value;
    }
  }

  bool _isSwapping = false;

  Future<void> updateTile(TileData tileData) async {
    if (this.tileData == tileData && !_isSwapping) {
      swapTrigger.fire();
    } else if (!_isSwapping) {
      _isSwapping = true;
      final cachedSm = sm;
      final cachedArtboard = artboard;
      // removeTrigger.fire();
      // await Future.delayed(const Duration(milliseconds: 1000));

      this.tileData = tileData;
      _initRive();
      _setPosition();

      cachedSm.dispose();
      cachedArtboard.dispose();
      await Future.delayed(const Duration(milliseconds: 10));

      swapTrigger.fire();
      _isSwapping = false;
    }
  }

  void dispose() {
    sm.dispose();
    artboard.dispose();
  }
}
