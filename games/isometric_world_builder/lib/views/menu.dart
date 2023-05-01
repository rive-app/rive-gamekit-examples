import 'package:flutter/material.dart';

typedef MenuUpdate = void Function(int rows, int columns);

class Menu extends StatefulWidget {
  const Menu({
    super.key,
    required this.showPerformanceOverlay,
    this.updateSize,
  });

  final MenuUpdate? updateSize;
  final ValueNotifier<bool> showPerformanceOverlay;

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final ValueNotifier<double> _rows = ValueNotifier(50);
  final ValueNotifier<double> _columns = ValueNotifier(50);

  void _update() {
    widget.updateSize
        ?.call((_rows.value / 10).round(), (_columns.value / 10).round());
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // user must tap button!
      barrierColor: const Color(0xFF36303B).withOpacity(0.65),
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Settings'),
          content: MenuAlert(
            showPerformanceOverlay: widget.showPerformanceOverlay,
            rows: _rows,
            columns: _columns,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                _update();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: _showMyDialog,
    );
  }
}

class MenuAlert extends StatefulWidget {
  const MenuAlert({
    super.key,
    required this.showPerformanceOverlay,
    required this.rows,
    required this.columns,
  });

  final ValueNotifier<bool> showPerformanceOverlay;
  final ValueNotifier<double> rows;
  final ValueNotifier<double> columns;

  @override
  State<MenuAlert> createState() => _MenuAlertState();
}

class _MenuAlertState extends State<MenuAlert> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ListBody(
        children: <Widget>[
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Rows')),
              Slider(
                value: widget.rows.value,
                min: 10,
                max: 200,
                divisions: 20,
                label: (widget.rows.value / 10).round().toString(),
                onChanged: (double value) {
                  setState(() {
                    widget.rows.value = value;
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Columns')),
              Slider(
                value: widget.columns.value,
                min: 10,
                max: 200,
                divisions: 20,
                label: (widget.columns.value / 10).round().toString(),
                onChanged: (double value) {
                  setState(() {
                    widget.columns.value = value;
                  });
                },
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              const Text('Performance Overlay'),
              Expanded(
                child: Switch(
                  value: widget.showPerformanceOverlay.value,
                  activeColor: Colors.red,
                  onChanged: (bool value) {
                    setState(() {
                      widget.showPerformanceOverlay.value = value;
                    });
                  },
                ),
              ),
              const Divider(),
            ],
          ),
        ],
      ),
    );
  }
}
