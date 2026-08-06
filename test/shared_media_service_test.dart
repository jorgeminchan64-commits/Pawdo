import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/media/services/shared_media_service.dart';

void main() {
  group('SharedMediaService image validation', () {
    test('uses an exact 1 MB upload limit', () {
      expect(SharedMediaService.maxImageBytes, 1024 * 1024);
    });

    test('accepts JPEG, PNG and WebP signatures', () {
      expect(
        SharedMediaService.isSupportedImageHeader(
          Uint8List.fromList([0xff, 0xd8, 0xff]),
        ),
        isTrue,
      );
      expect(
        SharedMediaService.isSupportedImageHeader(
          Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        ),
        isTrue,
      );
      expect(
        SharedMediaService.isSupportedImageHeader(
          Uint8List.fromList([
            0x52,
            0x49,
            0x46,
            0x46,
            0,
            0,
            0,
            0,
            0x57,
            0x45,
            0x42,
            0x50,
          ]),
        ),
        isTrue,
      );
    });

    test('rejects GIF, PDF and a spoofed arbitrary payload', () {
      expect(
        SharedMediaService.isSupportedImageHeader(
          Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
        ),
        isFalse,
      );
      expect(
        SharedMediaService.isSupportedImageHeader(
          Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
        ),
        isFalse,
      );
      expect(
        SharedMediaService.isSupportedImageHeader(
          Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
        ),
        isFalse,
      );
    });
  });
}
