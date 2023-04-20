import 'package:oxygen/oxygen.dart';

/// Used in the AABB Tree to store the entity and its AABB.
class TreeProxyComponent extends ValueComponent<int> {
  @override
  void reset() {
    value = -1;
    super.reset();
  }
}
