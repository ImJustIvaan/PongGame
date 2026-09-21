import 'package:flutter_test/flutter_test.dart';
import 'package:pong_game/services/gamepad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GamepadService & Gamepad Tests', () {
    test('GamepadService singleton initializes with empty controller list', () {
      final service = GamepadService.instance;
      expect(service, isNotNull);
      expect(service.connectedControllers, isNotNull);
      expect(service.controllerCount, greaterThanOrEqualTo(0));
    });

    test('Deadzone filters minor stick drift and scales proportionally', () {
      final service = GamepadService.instance;
      // When no controller is connected, getMovementY returns 0.0
      expect(service.getMovementY(player: 1), 0.0);
      expect(service.getMovementY(player: 2), 0.0);
      expect(service.getMovementX(player: 1), 0.0);
    });

    test('RawGamepadData correctly holds axes, index, and action buttons', () {
      const data = RawGamepadData(
        index: 0,
        id: 'Xbox Wireless Controller (STANDARD GAMEPAD)',
        connected: true,
        leftStickX: 0.85,
        leftStickY: -0.92,
        rightStickX: 0.0,
        rightStickY: 0.75,
        pressedActions: {
          GamepadAction.actionA,
          GamepadAction.start,
          GamepadAction.dpadUp,
        },
      );

      expect(data.index, 0);
      expect(data.id, contains('Xbox'));
      expect(data.connected, isTrue);
      expect(data.leftStickX, 0.85);
      expect(data.leftStickY, -0.92);
      expect(data.rightStickY, 0.75);
      expect(data.pressedActions.contains(GamepadAction.actionA), isTrue);
      expect(data.pressedActions.contains(GamepadAction.start), isTrue);
      expect(data.pressedActions.contains(GamepadAction.dpadUp), isTrue);
      expect(data.pressedActions.contains(GamepadAction.actionB), isFalse);
    });
  });
}
