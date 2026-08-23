import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const prefixes = ['avatar_boy', 'avatar_girl'];
  const layers = ['hair', 'skin', 'outfit', 'shoes'];

  for (final prefix in prefixes) {
    for (final layer in layers) {
      test(
        '$prefix $layer layer matches the production sprite sheet',
        () async {
          final data = await rootBundle.load(
            'assets/images/avatars/layers/${prefix}_$layer.png',
          );
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 836);
          expect(frame.image.height, 1881);

          final pixels = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          expect(pixels, isNotNull);
          var visibleSamples = 0;
          var shadedSamples = 0;
          final bytes = pixels!.buffer.asUint8List();
          for (var index = 0; index < bytes.length; index += 4 * 31) {
            final alpha = bytes[index + 3];
            if (alpha == 0) continue;
            visibleSamples++;
            if (bytes[index] < 250) shadedSamples++;
          }
          expect(visibleSamples, greaterThan(20));
          expect(shadedSamples, greaterThan(5));
          frame.image.dispose();
          codec.dispose();
        },
      );
    }
  }
}
