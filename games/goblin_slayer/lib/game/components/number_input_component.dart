import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class NumberInputComponent extends Component<rive.NumberInput> {
  late rive.NumberInput numberInput;

  @override
  void init([rive.NumberInput? data]) {
    numberInput = data!;
  }

  @override
  void reset() {}
}
