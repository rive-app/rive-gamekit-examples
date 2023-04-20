import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

/// Used to store the trigger inputs of an artboard.
class TriggerInputsComponent extends Component<Map<String, rive.TriggerInput>> {
  late Map<String, rive.TriggerInput> triggers;

  @override
  void init([Map<String, rive.TriggerInput>? data]) {
    triggers = data ?? {};
  }

  @override
  void reset() {
    triggers.clear();
  }
}
