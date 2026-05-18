import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageUtils {
  /// Compress a picked image to ~1024px wide JPEG (70% quality).
  /// Returns the compressed bytes, or the original bytes if compression fails.
  static Future<Uint8List> compress(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      return result ?? await file.readAsBytes();
    } catch (_) {
      return await file.readAsBytes();
    }
  }
}
