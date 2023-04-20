import 'package:goblin_slayer/game/components/enemy_component.dart';
import 'package:oxygen/oxygen.dart';

class ClubComponent extends ValueComponent<String> {
  final Stopwatch timeAlive = Stopwatch();
  String? parentName;

  bool get shouldDestroy =>
      timeAlive.elapsed > EnemyComponent.attackCooldownDuration;

  @override
  void init([String? data]) {
    parentName = data;
    timeAlive.reset();
    timeAlive.start();
    super.init(data);
  }

  @override
  void reset() {
    timeAlive.reset();
    // timeAlive.start();
    super.reset();
  }
}
