import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

class StateMachineComponent extends Component<rive.StateMachine> {
  late rive.StateMachine stateMachine;

  @override
  void init([rive.StateMachine? data]) {
    stateMachine = data!;
  }

  @override
  void reset() {}

  @override
  void dispose() {
    stateMachine.dispose();
    super.dispose();
  }
}
