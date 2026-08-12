import 'package:flutter_test/flutter_test.dart';
import 'package:pawdo/features/media/services/audio_message_service.dart';

void main() {
  test('voice notes accept only the bounded recording duration', () {
    expect(
      AudioMessageService.isValidDuration(const Duration(milliseconds: 499)),
      isFalse,
    );
    expect(
      AudioMessageService.isValidDuration(const Duration(milliseconds: 500)),
      isTrue,
    );
    expect(
      AudioMessageService.isValidDuration(const Duration(seconds: 60)),
      isTrue,
    );
    expect(
      AudioMessageService.isValidDuration(
        const Duration(seconds: 60, milliseconds: 1),
      ),
      isFalse,
    );
  });

  test('voice-note cache accepts only the active couple audio path', () {
    expect(
      AudioMessageService.isValidStoragePath(
        'ABC123',
        'couples/ABC123/audio/1234567890_voice.m4a',
      ),
      isTrue,
    );
    expect(
      AudioMessageService.isValidStoragePath(
        'ABC123',
        'couples/OTHER1/audio/1234567890_voice.m4a',
      ),
      isFalse,
    );
    expect(
      AudioMessageService.isValidStoragePath(
        'ABC123',
        'couples/ABC123/audio/nested/voice.m4a',
      ),
      isFalse,
    );
    expect(
      AudioMessageService.isValidStoragePath(
        'ABC123',
        'couples/ABC123/audio/voice.mp3',
      ),
      isFalse,
    );
  });

  test('voice-note payload limit remains two megabytes', () {
    expect(AudioMessageService.maxAudioBytes, 2 * 1024 * 1024);
  });
}
