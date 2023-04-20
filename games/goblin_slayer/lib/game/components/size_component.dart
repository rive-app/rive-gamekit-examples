import 'dart:ui';

import 'package:oxygen/oxygen.dart';

class SizeComponent extends Component<Size> {
  late Size size;

  @override
  void init([Size? data]) {
    size = data ?? Size.zero;
  }

  @override
  void reset() {
    size = Size.zero;
  }
}
