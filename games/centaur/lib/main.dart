import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import 'centaur_game.dart';

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
  CentaurGame? _centaurPainter;

  @override
  void initState() {
    super.initState();

    load();
  }

  Future<void> load() async {
    var data = await rootBundle.load('assets/centaur_v2.riv');
    var bytes = data.buffer.asUint8List();
    var file = rive.File.decode(bytes);
    if (file != null) {
      setState(() {
        _centaurPainter = CentaurGame(file);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _centaurPainter?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: ColoredBox(
          color: const Color(0xFF507FBA),
          child: Center(
            child: _centaurPainter == null
                ? const SizedBox()
                : Focus(
                    focusNode: FocusNode(
                      canRequestFocus: true,
                      onKeyEvent: (node, event) {
                        if (event is KeyRepeatEvent) {
                          return KeyEventResult.handled;
                        }
                        double speed = 0;
                        if (event is KeyDownEvent) {
                          speed = 1;
                        } else if (event is KeyUpEvent) {
                          speed = -1;
                        }
                        if (event.logicalKey == LogicalKeyboardKey.keyA) {
                          _centaurPainter!.move -= speed;
                        } else if (event.logicalKey ==
                            LogicalKeyboardKey.keyD) {
                          _centaurPainter!.move += speed;
                        }
                        return KeyEventResult.handled;
                      },
                    )..requestFocus(),
                    child: MouseRegion(
                      onHover: (event) => _centaurPainter!.aimAt(
                        event.localPosition * window.devicePixelRatio,
                      ),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _centaurPainter!.pointerDown,
                        onPointerMove: (event) => _centaurPainter!.aimAt(
                          event.localPosition * window.devicePixelRatio,
                        ),
                        child: _renderTexture.widget(_centaurPainter!),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
