import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:goblin_slayer/aabb_tree.dart';
import 'package:goblin_slayer/extensions/input.dart';
import 'package:goblin_slayer/game/components/artboard_component.dart';
import 'package:goblin_slayer/game/components/boolean_input_component.dart';
import 'package:goblin_slayer/game/components/club_component.dart';
import 'package:goblin_slayer/game/components/collision_component.dart';
import 'package:goblin_slayer/game/components/enemy_component.dart';
import 'package:goblin_slayer/game/components/ground_component.dart';
import 'package:goblin_slayer/game/components/number_input_component.dart';
import 'package:goblin_slayer/game/components/obstacle_component.dart';
import 'package:goblin_slayer/game/components/player_component.dart';
import 'package:goblin_slayer/game/components/rive_component_component.dart';
import 'package:goblin_slayer/game/components/size_component.dart';
import 'package:goblin_slayer/game/components/speed_component.dart';
import 'package:goblin_slayer/game/components/state_machine_component.dart';
import 'package:goblin_slayer/game/components/tree_proxy_component.dart';
import 'package:goblin_slayer/game/components/trigger_input_component.dart';
import 'package:goblin_slayer/game/components/velocity_component.dart';
import 'package:goblin_slayer/game/components/player_attack_component.dart';
import 'package:goblin_slayer/game/state/game_state.dart';
import 'package:goblin_slayer/game/systems/enemy_collision_system.dart';
import 'package:goblin_slayer/game/systems/enemy_spawn_system.dart';
import 'package:goblin_slayer/game/systems/player_collision_system.dart';
import 'package:goblin_slayer/game/systems/player_control_system.dart';
import 'package:goblin_slayer/game/systems/render_system.dart';
import 'package:goblin_slayer/game/systems/ui_system.dart';
import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

import 'game/components/position_component.dart';
import 'game/constants.dart';

void main() {
  runApp(const GoblinSlayerGame());
}

/// Displays hitboxes and other debug information.
bool debugGame = false;

class GoblinSlayerGame extends StatelessWidget {
  const GoblinSlayerGame({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      // showPerformanceOverlay: true,
      home: GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final rive.RenderTexture _renderTexture =
      rive.GameKit.instance.makeRenderTexture();

  final world = World();
  final _gameState = GameState();
  final staticTree = AABBTree<Entity>();
  final tree = AABBTree<Entity>();
  late final GameWorldPainter _gamePainter = GameWorldPainter(world);

  bool isLoading = true;

  List<rive.File> files = [];
  List<rive.Artboard> artboards = [];
  List<rive.StateMachine> machines = [];

  @override
  void initState() {
    super.initState();
    _setupGameWorld();
  }

  Future _setupGameWorld() async {
    final uiHudFile = await _decodeFile('assets/special_attack_ui.riv');
    final coverFile = await _decodeFile('assets/cover.riv');
    final textFile = await _decodeFile('assets/goblins_text.riv');

    files.addAll([uiHudFile, coverFile, textFile]);

    world.registerSystem(UISystem(
        uiHudFile: uiHudFile, coverFile: coverFile, textFile: textFile));
    world.registerSystem(PlayerControlSystem());
    world.registerSystem(RenderSystem());
    world.registerSystem(EnemySpawnSystem());
    // world.registerSystem(ObstacleCollisionSystem());
    world.registerSystem(PlayerCollisionSystem());
    world.registerSystem(EnemyCollisionSystem());
    world.registerComponent(() => PlayerComponent());
    world.registerComponent(() => EnemyComponent());
    world.registerComponent(() => PlayerAttackComponent());
    world.registerComponent(() => ClubComponent());
    world.registerComponent(() => ObstacleComponent());
    world.registerComponent(() => GroundComponent());
    world.registerComponent(() => PositionComponent());
    world.registerComponent(() => VelocityComponent());
    world.registerComponent(() => SizeComponent());
    world.registerComponent(() => SpeedComponent());
    world.registerComponent(() => CollisionComponent());
    world.registerComponent(() => ArtboardComponent());
    world.registerComponent(() => StateMachineComponent());
    world.registerComponent(() => NumberInputComponent());
    world.registerComponent(() => BooleanInputComponent());
    world.registerComponent(() => TriggerInputsComponent());
    world.registerComponent(() => RiveComonentComponent());
    world.registerComponent(() => TreeProxyComponent());

    // Backgound entities
    {
      final file = await _decodeFile('assets/terrain.riv');
      final background = file.artboard("Terrain")!;
      final backgroundStateMachine = background.defaultStateMachine()!;

      files.add(file);
      artboards.add(background);

      final ground1 = world.createEntity()
        ..add<GroundComponent, void>()
        ..add<PositionComponent, rive.Vec2D>(rive.Vec2D.fromValues(0, 0))
        ..add<ArtboardComponent, rive.Artboard>(background)
        ..add<StateMachineComponent, rive.StateMachine>(backgroundStateMachine)
        ..add<SizeComponent, Size>();

      staticTree.createProxy(background.bounds.offset(0, 0), ground1);

      final worldSize = Size(background.bounds.width, background.bounds.height);

      world.store<Size>(Constants.worldSize, worldSize);
      world.store<GameState>(Constants.gameState, _gameState);
    }

    // Player entity
    {
      final file = await _decodeFile('assets/death_knight.riv');

      final character = file.artboard("MC Main Artboard");
      final machine = character!.defaultStateMachine()!;
      final directionInput = machine.number('Direction')!;
      final isMovingInput = machine.boolean('isMoving')!;
      final attackInput = machine.trigger('Attack')!;
      final specialAttackInput = machine.trigger('Special_Attack')!;
      final deathInput = machine.trigger('Death')!;

      final swordHitBox = character.component('AttackBoxPath');

      isMovingInput.value = false;

      files.add(file);
      artboards.add(character);
      machines.add(machine);

      final collisionBounds = rive.AABB.fromValues(0, 0, 150, 130);

      world.createEntity()
        ..add<PlayerComponent, void>()
        ..add<PositionComponent, rive.Vec2D>(
          rive.Vec2D.fromValues(
              world.worldSize.width / 2, world.worldSize.height / 2),
        )
        ..add<CollisionComponent, rive.AABB>(
          collisionBounds.translate(
            rive.Vec2D.fromValues(
              character.bounds.centerX - collisionBounds.centerX,
              character.bounds.centerX - collisionBounds.centerY + 60,
            ),
          ),
        )
        ..add<VelocityComponent, rive.Vec2D>()
        ..add<ArtboardComponent, rive.Artboard>(character)
        ..add<StateMachineComponent, rive.StateMachine>(machine)
        ..add<NumberInputComponent, rive.NumberInput>(directionInput)
        ..add<BooleanInputComponent, rive.BooleanInput>(isMovingInput)
        ..add<TriggerInputsComponent, Map<String, rive.TriggerInput>>(
          {
            Constants.playerAttackInput: attackInput,
            Constants.playerDeathInput: deathInput,
            Constants.playerSpecialAttackInput: specialAttackInput,
          },
        )
        ..add<RiveComonentComponent, rive.Component>(swordHitBox);
    }

    // Obstacle entity
    // {
    //   final data = await rootBundle.load('assets/rock.riv');
    //   final bytes = data.buffer.asUint8List();
    //   final file = rive.File.decode(bytes)!;
    //   files.add(file);

    //   for (var i = 0; i < 5; i++) {
    //     final rock = file.artboard("Rock")!;

    //     artboards.add(rock);
    //     final collisionBounds = rive.AABB.fromValues(0, 0, 400, 200);

    //     final offset =
    //         Offset(Random().nextDouble() * 4000, Random().nextDouble() * 4000);

    //     final entity = world.createEntity()
    //       ..add<ObstacleComponent, void>()
    //       ..add<PositionComponent, rive.Vec2D>(
    //           rive.Vec2D.fromValues(offset.dx, offset.dy))
    //       ..add<ArtboardComponent, rive.Artboard>(rock)
    //       ..add<CollisionComponent, rive.AABB>(
    //         collisionBounds.translate(rive.Vec2D.fromValues(
    //           rock.bounds.centerX - collisionBounds.centerX,
    //           rock.bounds.centerX - collisionBounds.centerY + 40,
    //         )),
    //       )
    //       ..add<SizeComponent, Size>();

    //     staticTree.createProxy(
    //         rock.bounds.offset(offset.dx, offset.dy), entity);
    //   }
    // }

    world.store(Constants.staticTree, staticTree);
    world.store(Constants.tree, tree);

    world.init();

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _gamePainter.dispose();
    _gameState.dispose();

    for (var element in machines) {
      element.dispose();
    }
    for (var element in artboards) {
      element.dispose();
    }
    for (var element in files) {
      element.dispose();
    }
    _renderTexture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return (isLoading)
        ? const SizedBox()
        : Scaffold(
            body: Focus(
              focusNode: FocusNode(
                canRequestFocus: true,
                onKeyEvent: (node, event) {
                  for (var system in world.systemManager.inputSystems) {
                    system.onKeyEvent(event);
                  }
                  return KeyEventResult.handled;
                },
              )..requestFocus(),
              child: _renderTexture.widget(_gamePainter),
            ),
          );
  }
}

class GameWorldPainter extends rive.RenderTexturePainter {
  final World world;
  late Query query;

  GameWorldPainter(this.world);

  @override
  bool paint(rive.RenderTexture texture, Size size, double elapsedSeconds) {
    world.windowSize = size;
    world.execute(elapsedSeconds);

    return true;
  }

  @override
  Color get background => const Color(0xFF000000);
}

Future<rive.File> _decodeFile(String path) async {
  final data = await rootBundle.load(path);
  final bytes = data.buffer.asUint8List();
  final file = rive.File.decode(bytes);
  if (file == null) {
    throw Exception('Unable to load Rive file with path: $path');
  }
  return file;
}
