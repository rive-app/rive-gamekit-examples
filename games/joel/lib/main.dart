import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:joel/scene.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;
import 'package:joel/scene.dart' as joel;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final rive.RenderTexture _renderTexture =
      rive.GameKit.instance.makeRenderTexture();
  final JoelPainter _joelPainter = JoelPainter();

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _joelPainter.onPointerDown,
        onPointerMove: _joelPainter.onPointerMove,
        onPointerUp: _joelPainter.onPointerUp,
        child: _renderTexture.widget(_joelPainter),
      ),
    );
  }
}

enum JoelGameState {
  mainMenu,
  scene,
}

enum JoelFade { fadeIn, fadeOut, complete }

class JoelPainter extends rive.RenderTexturePainter {
  double _darken = 1.0;

  JoelGameState _state = JoelGameState.mainMenu;
  JoelFade _fadeState = JoelFade.complete;
  rive.File? _introFile;
  rive.Artboard? _intro;
  rive.Artboard? _introButton;
  rive.StateMachine? _introButtonMachine;
  rive.StateMachine? _introMachine;
  joel.Scene? _scene;
  JoelPainter() {
    {
      rootBundle.load('assets/intro.riv').then((data) {
        var bytes = data.buffer.asUint8List();
        _introFile = rive.File.decode(bytes);
        if (_introFile == null) {
          return null;
        } else {
          _intro = _introFile!.artboard('Screen');
          if (_intro != null) {
            _introMachine = _intro!.defaultStateMachine();
          }
          _introButton = _introFile!.artboard('button');
          if (_introButton != null) {
            _introButtonMachine = _introButton!.defaultStateMachine();
          }
        }
        _fadeState = JoelFade.fadeIn;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _introFile?.dispose();
  }

  Size _fadeSize = Size.zero;
  rive.RenderPath? _path;
  final rive.RenderPaint _paint = rive.Renderer.makePaint()
    ..color = const Color(0xFF000000)
    ..style = PaintingStyle.fill;

  bool _requestedStart = false;

  static const double fadeSpeed = 0.8;
  @override
  bool paint(rive.RenderTexture texture, Size size, double elapsedSeconds) {
    switch (_fadeState) {
      case JoelFade.fadeIn:
        _darken -= elapsedSeconds * fadeSpeed;
        if (_darken <= 0) {
          _darken = 0;
          _fadeState = JoelFade.complete;
          if (_state == JoelGameState.scene) {
            _scene?.start();
          }
        }
        break;
      case JoelFade.fadeOut:
        _darken += elapsedSeconds * fadeSpeed;
        if (_darken >= 1) {
          _darken = 1;
          _fadeState = JoelFade.complete;
          if (_state == JoelGameState.scene) {
            // Fade in to main menu...
            _scene?.dispose();
            _scene = null;
            _state = JoelGameState.mainMenu;
            _fadeState = JoelFade.fadeIn;
          } else if (_state == JoelGameState.mainMenu) {
            // Fade in to scene once it loads
            joel.Scene.load().then((scene) {
              _scene = scene;

              _state = JoelGameState.scene;
              _fadeState = JoelFade.fadeIn;
            });
          }
        }
        break;
      case JoelFade.complete:
        if (_state == JoelGameState.scene) {
          if (_scene?.isOver == true) {
            _fadeState = JoelFade.fadeOut;
          }
        } else if (_requestedStart) {
          _fadeState = JoelFade.fadeOut;
          _requestedStart = false;
        }
        break;
    }
    var renderer = rive.Renderer.make();

    switch (_state) {
      case JoelGameState.scene:
        _scene?.draw(renderer, elapsedSeconds, size);
        break;
      case JoelGameState.mainMenu:
        _introMachine?.advance(elapsedSeconds);
        _introButtonMachine?.advance(elapsedSeconds);
        var intro = _intro;
        if (intro != null) {
          renderer.save();
          renderer.align(
              BoxFit.cover,
              Alignment.center,
              rive.AABB.fromMinMax(
                  rive.Vec2D(), rive.Vec2D.fromValues(size.width, size.height)),
              intro.bounds);
          intro.draw(renderer);
          renderer.restore();

          var introButton = _introButton;
          if (introButton != null) {
            renderer.save();
            renderer.align(
                BoxFit.none,
                const Alignment(0.0, 0.75),
                rive.AABB.fromMinMax(rive.Vec2D(),
                    rive.Vec2D.fromValues(size.width, size.height)),
                introButton.bounds);
            introButton.draw(renderer);
            renderer.restore();
          }
        }
        break;
    }

    if (_darken != 0) {
      if (_fadeSize != size) {
        _path = rive.Renderer.makePath(true);
        _path!.moveTo(0, 0);
        _path!.lineTo(size.width, 0);
        _path!.lineTo(size.width, size.height);
        _path!.lineTo(0, size.height);
        _path!.close();

        _fadeSize = size;
      }
      renderer.drawPath(
        _path!,
        _paint..color = _paint.color.withOpacity(_darken),
      );
    }
    return true;
  }

  void onPointerDown(PointerDownEvent event) {
    if (_fadeState == JoelFade.complete &&
        _state == JoelGameState.mainMenu &&
        !_requestedStart) {
      _introButtonMachine?.trigger('Pressed')?.fire();
      _requestedStart = true;

      return;
    }
    _scene?.onPointerDown(event);
  }

  void onPointerMove(PointerMoveEvent event) => _scene?.onPointerMove(event);

  void onPointerUp(PointerUpEvent event) => _scene?.onPointerUp(event);

  @override
  Color get background => const Color(0xFFD5B2BE);
}
