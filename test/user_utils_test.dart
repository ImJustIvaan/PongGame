import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/utils/user_utils.dart';

void main() {
  group('UserUtils Tests', () {
    test('imjustivaan is verified (case-insensitive)', () {
      expect(UserUtils.isVerified('imjustivaan'), isTrue);
      expect(UserUtils.isVerified('IMJUSTIVAAN'), isTrue);
      expect(UserUtils.isVerified('ImJustIvaan'), isTrue);
      expect(UserUtils.isVerified('  imjustivaan  '), isTrue);
    });

    test('other usernames are not verified', () {
      expect(UserUtils.isVerified('other_user'), isFalse);
      expect(UserUtils.isVerified('ivaan'), isFalse);
      expect(UserUtils.isVerified(''), isFalse);
      expect(UserUtils.isVerified(null), isFalse);
    });
  });
}
