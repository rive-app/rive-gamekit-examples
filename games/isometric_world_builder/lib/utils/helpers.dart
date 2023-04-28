import 'package:flutter/services.dart';
import 'package:rive_gamekit/rive_gamekit.dart' as rive;

abstract class Helpers {
  static Future<rive.File> decodeFile(String filePath) async {
    try {
      final data = await rootBundle.load(filePath);
      final bytes = data.buffer.asUint8List();
      return rive.File.decode(bytes)!;
    } catch (e) {
      throw Exception('Could not load Rive file with path: $filePath');
    }
  }
}
