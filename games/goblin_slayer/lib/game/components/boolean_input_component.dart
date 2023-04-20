import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class BooleanInputComponent extends Component<rive.BooleanInput> {
  late rive.BooleanInput booleanInput;

  @override
  void init([rive.BooleanInput? data]) {
    booleanInput = data!;
  }

  @override
  void reset() {}
}
