import 'package:goblin_slayer/extensions/cooldowns.dart';
import 'package:oxygen/oxygen.dart';

class EnemyComponent extends ValueComponent<String> {
  late String enemyName;

  bool get isDead => deathCooldown.state != DeathCoolDownState.none;
  late DeathCooldown deathCooldown;
  late AttackCooldown attackCooldown;

  static const Duration deathCooldownDuration = Duration(seconds: 10);
  static const Duration attackCooldownDuration = Duration(seconds: 1);

  @override
  void init([String? data]) {
    enemyName = data!;
    deathCooldown = DeathCooldown(deathCooldownDuration);
    attackCooldown = AttackCooldown(attackCooldownDuration);
    super.init(data);
  }

  @override
  void reset() {
    deathCooldown = DeathCooldown(deathCooldownDuration);
    attackCooldown = AttackCooldown(attackCooldownDuration);
    super.reset();
  }
}
