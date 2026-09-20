import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/game/game_theme.dart';
import 'package:pong_game/utils/user_utils.dart';

void main() {
  group('UserUtils Tests', () {
    test('imjustivaan is verified (case-insensitive)', () {
      expect(UserUtils.isVerified('imjustivaan'), isTrue);
      expect(UserUtils.isVerified('IMJUSTIVAAN'), isTrue);
      expect(UserUtils.isVerified('ImJustIvaan'), isTrue);
      expect(UserUtils.isVerified('  imjustivaan  '), isTrue);
    });

    test('imjustivaan has owner privileges (case-insensitive)', () {
      expect(UserUtils.isOwner('imjustivaan'), isTrue);
      expect(UserUtils.isOwner('IMJUSTIVAAN'), isTrue);
      expect(UserUtils.isOwner('ImJustIvaan'), isTrue);
      expect(UserUtils.isOwner('  imjustivaan  '), isTrue);
      expect(UserUtils.isOwner('other_user'), isFalse);
      expect(UserUtils.isOwner(null), isFalse);
    });
  });

  group('PongTheme Tests', () {
    test('PongTheme.lightMode is defined with isLight == true', () {
      final theme = PongTheme.fromType(PongThemeType.lightMode);
      expect(theme.type, equals(PongThemeType.lightMode));
      expect(theme.name, equals('Light Mode'));
      expect(theme.isLight, isTrue);
      expect(theme.hasGlow, isFalse);
      expect(PongTheme.cyberNeon.isLight, isFalse);
    });
  });
}
