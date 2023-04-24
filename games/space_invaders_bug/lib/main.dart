import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import 'package:space_invaders_bug/invaders.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final rive.RenderTexture _renderTexture =
      rive.GameKit.instance.makeRenderTexture();
  GamePainter? _gamePainter;

  final List<rive.File> _riveFiles = [];

  @override
  void initState() {
    super.initState();

    load();
  }

  Future<void> loadFile(String assetName) async {
    var data = await rootBundle.load(assetName);
    var bytes = data.buffer.asUint8List();
    var file = rive.File.decode(bytes);
    if (file != null) {
      _riveFiles.add(file);
    }
  }

  Future<void> load() async {
    await loadFile('assets/top_down_ship_cleanup_v6.riv');
    await loadFile('assets/top_down_ship_v4.riv');
    await loadFile('assets/bug_1.riv');
    await loadFile('assets/bug_2.riv');
    await loadFile('assets/bug_3.riv');
    await loadFile('assets/bug_boss_clip.riv');

    setState(() {
      _gamePainter = GamePainter(_riveFiles[0], _riveFiles[1],
          _riveFiles.sublist(2, _riveFiles.length - 1), _riveFiles.last);
    });
  }

  @override
  void dispose() {
    super.dispose();
    _gamePainter?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Space Shooter'),
        ),
        body: ColoredBox(
          color: const Color(0xFF507FBA),
          child: Center(
            child: _gamePainter == null
                ? const SizedBox()
                : Focus(
                    focusNode: FocusNode(
                      canRequestFocus: true,
                      onKeyEvent: (node, event) {
                        if (event is KeyRepeatEvent) {
                          return KeyEventResult.handled;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.space) {
                          _gamePainter!.fire();
                        }
                        return KeyEventResult.handled;
                      },
                    )..requestFocus(),
                    child: MouseRegion(
                      onHover: (event) => _gamePainter!.aimAt(
                        event.localPosition * window.devicePixelRatio,
                      ),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        // onPointerDown: _gamePainter!.pointerDown,
                        onPointerMove: (event) => _gamePainter!.aimAt(
                          event.localPosition * window.devicePixelRatio,
                        ),
                        child: _renderTexture.widget(_gamePainter!),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
