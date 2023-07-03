import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

void main() {
  runApp(const MyApp());
}

class ZombieGridPainter extends rive.RenderTexturePainter {
  final rive.File riveFile;

  final List<rive.Artboard> artboards = [];
  final List<rive.StateMachine> machines = [];
  late rive.AABB zombieSize;
  ZombieGridPainter(this.riveFile) {
    for (int i = 0; i < 6; i++) {
      var artboard = riveFile.artboard('Zombie man');
      if (artboard != null) {
        zombieSize = artboard.bounds;
        artboards.add(artboard);
        var machine = artboard.defaultStateMachine();
        if (machine != null) {
          machines.add(machine);
          var skinInput = machine.number('numSkins');
          if (skinInput != null) {
            skinInput.value = i.toDouble();
          }
        }
      }
    }

    for (int i = 0; i < 4; i++) {
      var artboard = riveFile.artboard('Zombie woman');
      if (artboard != null) {
        zombieSize = artboard.bounds;
        artboards.add(artboard);
        var machine = artboard.defaultStateMachine();
        if (machine != null) {
          machines.add(machine);
          var skinInput = machine.number('numSkins');
          if (skinInput != null) {
            skinInput.value = i.toDouble();
          }
        }
      }
    }
  }

  @override
  bool paint(rive.RenderTexture texture, Size size, double elapsedSeconds) {
    // Batch advances multiple state machines in a thread pool.
    rive.Rive.batchAdvance(machines, elapsedSeconds);

    var renderer = rive.Renderer.make();

    // We have 10 zombie instances. Place 4 per row
    var targetWidth = size.width / 4;
    var targetHeight = targetWidth * zombieSize.height / zombieSize.width;
    var frame = rive.AABB.fromMinMax(
        rive.Vec2D(), rive.Vec2D.fromValues(targetWidth, targetHeight));
    var x = 0.0;
    var y = 0.0;
    for (final artboard in artboards) {
      renderer.save();
      renderer.align(
        BoxFit.contain,
        Alignment.center,
        frame.offset(x, y),
        zombieSize,
      );
      artboard.draw(renderer);
      renderer.restore();
      x += targetWidth;
      if (x >= size.width) {
        x = 0;
        y += targetHeight;
      }
    }
    return true;
  }

  @override
  void dispose() {
    super.dispose();
    riveFile.dispose();
  }

  @override
  Color get background => const Color(0x00000000);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final rive.RenderTexture _renderTexture =
      rive.GameKit.instance.makeRenderTexture();
  ZombieGridPainter? _zombiePainter;

  @override
  void initState() {
    super.initState();

    load();
  }

  Future<void> load() async {
    var data = await rootBundle.load('assets/zombie.riv');
    var bytes = data.buffer.asUint8List();
    var file = rive.File.decode(bytes);
    if (file != null) {
      setState(() {
        _zombiePainter = ZombieGridPainter(file);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _zombiePainter?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ColoredBox(
          color: const Color(0xFF507FBA),
          child: Center(
            child: _zombiePainter == null
                ? const SizedBox()
                : _renderTexture.widget(_zombiePainter!),
          ),
        ),
      ),
    );
  }
}
