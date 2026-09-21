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
    test('All 4 themes support both dark and light modes with correct isLight value', () {
      expect(PongThemeType.values.length, 4);

      for (final type in PongThemeType.values) {
        final darkTheme = PongTheme.fromType(type, isLight: false);
        expect(darkTheme.type, equals(type));
        expect(darkTheme.isLight, isFalse);

        final lightTheme = PongTheme.fromType(type, isLight: true);
        expect(lightTheme.type, equals(type));
        expect(lightTheme.isLight, isTrue);
        expect(lightTheme.backgroundColor, isNot(equals(darkTheme.backgroundColor)));
      }
    });
  });
}
