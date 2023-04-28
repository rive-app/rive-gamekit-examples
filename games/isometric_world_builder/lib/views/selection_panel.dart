import 'package:flutter/material.dart';
import 'package:isometric_world_builder/data.dart';
import 'package:isometric_world_builder/models/tile.dart';
import 'package:rive/rive.dart';

typedef TileSelected = void Function(TileData value);

/// A panel that displays the available tiles to select from.
///
/// This makes use of the normal Rive Flutter Runtime to display
/// the UI selection panel. It atoumatically handles input and
/// state changes are synced through a callback.
class SelectionPanel extends StatefulWidget {
  const SelectionPanel({
    super.key,
    required this.onTileSelected,
  });

  final TileSelected onTileSelected;

  @override
  State<SelectionPanel> createState() => _SelectionPanelState();
}

class _SelectionPanelState extends State<SelectionPanel> {
  late StateMachineController controller;
  late SMINumber input;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onStateChange(String stateMachineName, String stateName) {
    /// Find state changes that correlate to the correct animation name and
    /// tie that into the tile data.
    final tile = Data.tileData[stateName];
    if (tile == null) return;

    widget.onTileSelected(tile);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: RiveAnimation.asset(
        'assets/world_creator.riv',
        artboard: 'Ui',
        onInit: (Artboard artboard) {
          controller = StateMachineController.fromArtboard(
            artboard,
            'State Machine 1',
            onStateChange: _onStateChange,
          )!;
          artboard.addController(controller);
          input = controller.findSMI('numType');
        },
      ),
    );
  }
}
