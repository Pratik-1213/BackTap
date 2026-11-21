import 'package:flutter_test/flutter_test.dart';
import 'package:backtap/models/tap_action.dart';

void main() {
  group('TapAction Model Tests', () {
    test('availableActions contains all 8 defined system actions', () {
      expect(TapAction.availableActions.length, 8);

      final ids = TapAction.availableActions.map((a) => a.id).toSet();
      expect(ids, containsAll([
        'SCREENSHOT',
        'FLASHLIGHT',
        'LOCK_SCREEN',
        'NOTIFICATIONS',
        'HOME',
        'BACK',
        'RECENTS',
        'MUTE_VOLUME',
      ]));
    });

    test('getById returns exact action case-insensitively', () {
      final action = TapAction.getById('flashlight');
      expect(action.id, 'FLASHLIGHT');
      expect(action.title, 'Flashlight');
      expect(action.requiresAccessibility, isFalse);

      final screenshotAction = TapAction.getById('SCREENSHOT');
      expect(screenshotAction.id, 'SCREENSHOT');
      expect(screenshotAction.requiresAccessibility, isTrue);
    });

    test('getById falls back to default action for unknown IDs', () {
      final fallback = TapAction.getById('UNKNOWN_ACTION_XYZ');
      expect(fallback.id, 'SCREENSHOT');
    });

    test('all availableActions have non-empty titles and descriptions', () {
      for (final action in TapAction.availableActions) {
        expect(action.title.trim().isNotEmpty, isTrue);
        expect(action.description.trim().isNotEmpty, isTrue);
        expect(action.accentColor, isNotNull);
      }
    });
  });
}
