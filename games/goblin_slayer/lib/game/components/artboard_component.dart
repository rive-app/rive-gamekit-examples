import 'package:oxygen/oxygen.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

///
class ArtboardComponent extends Component<rive.Artboard> {
  late rive.Artboard artboard;

  @override
  void init([rive.Artboard? data]) {
    artboard = data!;
  }

  @override
  void reset() {}

  @override
  void dispose() {
    artboard.dispose();
    super.dispose();
  }
}
