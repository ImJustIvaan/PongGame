import 'package:flutter/services.dart';
import 'gamepad_service.dart';

class GamepadPlatform {
  static void init(void Function() onDevicesChanged) {}

  static List<RawGamepadData> poll() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final actions = <GamepadAction>{};

    if (keys.contains(LogicalKeyboardKey.gameButtonA)) actions.add(GamepadAction.actionA);
    if (keys.contains(LogicalKeyboardKey.gameButtonB)) actions.add(GamepadAction.actionB);
    if (keys.contains(LogicalKeyboardKey.gameButtonX)) actions.add(GamepadAction.actionX);
    if (keys.contains(LogicalKeyboardKey.gameButtonY)) actions.add(GamepadAction.actionY);
    if (keys.contains(LogicalKeyboardKey.gameButtonStart)) actions.add(GamepadAction.start);
    if (keys.contains(LogicalKeyboardKey.gameButtonSelect)) actions.add(GamepadAction.select);
    if (keys.contains(LogicalKeyboardKey.gameButtonLeft1)) actions.add(GamepadAction.bumperLeft);
    if (keys.contains(LogicalKeyboardKey.gameButtonRight1)) actions.add(GamepadAction.bumperRight);
    if (keys.contains(LogicalKeyboardKey.arrowUp)) actions.add(GamepadAction.dpadUp);
    if (keys.contains(LogicalKeyboardKey.arrowDown)) actions.add(GamepadAction.dpadDown);
    if (keys.contains(LogicalKeyboardKey.arrowLeft)) actions.add(GamepadAction.dpadLeft);
    if (keys.contains(LogicalKeyboardKey.arrowRight)) actions.add(GamepadAction.dpadRight);

    double ly = 0.0;
    if (actions.contains(GamepadAction.dpadUp)) ly = -1.0;
    if (actions.contains(GamepadAction.dpadDown)) ly = 1.0;

    double lx = 0.0;
    if (actions.contains(GamepadAction.dpadLeft)) lx = -1.0;
    if (actions.contains(GamepadAction.dpadRight)) lx = 1.0;

    final hasGamepadKey = actions.isNotEmpty;
    if (!hasGamepadKey) return const [];

    return [
      RawGamepadData(
        index: 0,
        id: 'Gamepad Controller',
        connected: true,
        leftStickX: lx,
        leftStickY: ly,
        pressedActions: actions,
      ),
    ];
  }
}
