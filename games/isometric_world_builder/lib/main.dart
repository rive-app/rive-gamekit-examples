import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:isometric_world_builder/data.dart';
import 'package:isometric_world_builder/utils/helpers.dart';
import 'package:isometric_world_builder/models/models.dart';
import 'package:isometric_world_builder/views/selection_panel.dart';
import 'package:isometric_world_builder/views/world_painter.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

void main() => runApp(const IsometricWorldBuilder());

class IsometricWorldBuilder extends StatefulWidget {
  const IsometricWorldBuilder({super.key});

  @override
  State<IsometricWorldBuilder> createState() => _IsometricWorldBuilderState();
}

class _IsometricWorldBuilderState extends State<IsometricWorldBuilder> {
  final rive.RenderTexture _renderTexture =
      rive.GameKit.instance.makeRenderTexture();

  late final WorldPainter _worldPainter;
  late final Grid grid;
  late final rive.File _riveFile;

  final ValueNotifier<TileData?> _selectedTile = ValueNotifier(null);

  @override
  void initState() {
    super.initState();

    initGame();
  }

  @override
  void dispose() {
    _worldPainter.dispose();
    _riveFile.dispose();
    super.dispose();
  }

  bool _isLoading = true;
  Future<void> initGame() async {
    _riveFile = await Helpers.decodeFile('assets/world_creator.riv');
    for (var element in Data.tileData.entries) {
      element.value.file = _riveFile;
    }

    grid = Grid(
      Data.tileData.entries.first.value,
      gridSizeX: 5,
      gridSizeY: 5,
    );

    _worldPainter = WorldPainter(grid, _selectedTile);

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      showPerformanceOverlay: false,
      home: Scaffold(
        body: _isLoading
            ? const SizedBox()
            : Stack(
                children: [
                  _gestureHandler(
                    _renderTexture.widget(_worldPainter),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SelectionPanel(
                      // tileData: _tileData,
                      onTileSelected: (value) => _selectedTile.value = value,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Listener _gestureHandler(Widget child) {
    return Listener(
      onPointerUp: (event) => _worldPainter.onPointerUp(event),
      onPointerDown: (event) => _worldPainter.onPointerDown(event),
      onPointerMove: (event) => _worldPainter.onPointerMove(event),
      onPointerPanZoomUpdate: _worldPainter.onPointerPanZoomUpdate,
      onPointerHover: (event) => _worldPainter.onHover(event),
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _worldPainter.onPointerScrollEvent(event);
        }
      },
      child: MouseRegion(
        child: child,
      ),
    );
  }
}
