import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:isometric_world_builder/data.dart';
import 'package:isometric_world_builder/utils/bootstrap.dart';
import 'package:isometric_world_builder/utils/helpers.dart';
import 'package:isometric_world_builder/models/models.dart';
import 'package:isometric_world_builder/views/menu.dart';
import 'package:isometric_world_builder/views/selection_panel.dart';
import 'package:isometric_world_builder/views/world_painter.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

void main() {
  bootstrap(() => const IsometricWorldBuilder());
}

class IsometricWorldBuilder extends StatefulWidget {
  const IsometricWorldBuilder({super.key});

  @override
  State<IsometricWorldBuilder> createState() => _IsometricWorldBuilderState();
}

class _IsometricWorldBuilderState extends State<IsometricWorldBuilder> {
  final rive.RenderTexture _renderTexture =
      rive.GameKit.instance.makeRenderTexture();

  late WorldPainter _worldPainter;
  late Grid grid;
  late final rive.File _riveFile;

  final ValueNotifier<TileData?> _selectedTile = ValueNotifier(null);

  final ValueNotifier<bool> _showPerformanceOverlay = ValueNotifier(false);

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
    return ValueListenableBuilder(
      valueListenable: _showPerformanceOverlay,
      builder: (context, value, child) {
        return MaterialApp(
          showPerformanceOverlay: value,
          theme: ThemeData(
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF5A2752))),
          home: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [
                WorldPainter.backgroundColorDark,
                WorldPainter.backgroundColorLight
              ],
              begin: const FractionalOffset(0.0, 1),
              end: const FractionalOffset(0.0, 0.0),
              stops: const [0.0, 1.0],
              tileMode: TileMode.clamp),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _isLoading
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    _gestureHandler(
                      _renderTexture.widget(_worldPainter),
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Menu(
                        showPerformanceOverlay: _showPerformanceOverlay,
                        updateSize: (rows, columns) {
                          grid.updateGrid(rows, columns);
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SelectionPanel(
                        onTileSelected: (value) => _selectedTile.value = value,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _gestureHandler(Widget child) {
    return GestureDetector(
      onScaleStart: (details) {
        _worldPainter.onScaleStart(details);
      },
      onScaleUpdate: (details) {
        _worldPainter.onScaleUpdate(details);
      },
      onScaleEnd: (details) {
        _worldPainter.onScaleEnd(details);
      },
      child: Listener(
        onPointerUp: (event) => _worldPainter.onPointerUp(event),
        onPointerDown: (event) => _worldPainter.onPointerDown(event),
        onPointerMove: (event) => _worldPainter.onPointerMove(event),
        onPointerHover: (event) => _worldPainter.onHover(event),
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _worldPainter.onPointerScrollEvent(event);
          }
        },
        child: MouseRegion(
          child: child,
        ),
      ),
    );
  }
}
