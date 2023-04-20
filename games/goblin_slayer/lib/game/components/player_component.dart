import 'package:oxygen/oxygen.dart';

class PlayerComponent extends ValueComponent<void> {
  bool _isDead = false;
  bool get isDead => _isDead;
  bool get isAlive => !_isDead;

  void hit() => _isDead = true;

  void alive() => _isDead = false;
}
