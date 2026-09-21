// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'gamepad_service.dart';

class GamepadPlatform {
  static void init(void Function() onDevicesChanged) {
    try {
      html.window.on['gamepadconnected'].listen((_) => onDevicesChanged());
      html.window.on['gamepaddisconnected'].listen((_) => onDevicesChanged());
    } catch (_) {}
  }

  static List<RawGamepadData> poll() {
    final results = <RawGamepadData>[];
    try {
      final gamepads = html.window.navigator.getGamepads();
      for (var i = 0; i < gamepads.length; i++) {
        final gp = gamepads[i];
        if (gp == null || gp.connected != true) continue;

        final axes = gp.axes;
        final buttons = gp.buttons;

        double lx = 0.0;
        double ly = 0.0;
        double rx = 0.0;
        double ry = 0.0;

        if (axes != null && axes.isNotEmpty) lx = axes[0].toDouble();
        if (axes != null && axes.length > 1) ly = axes[1].toDouble();
        if (axes != null && axes.length > 2) rx = axes[2].toDouble();
        if (axes != null && axes.length > 3) ry = axes[3].toDouble();

        final actions = <GamepadAction>{};

        bool isDown(int idx) {
          if (buttons == null || idx >= buttons.length) return false;
          final b = buttons[idx];
          return b.pressed == true || (b.value != null && b.value! > 0.5);
        }

        if (isDown(0)) actions.add(GamepadAction.actionA);
        if (isDown(1)) actions.add(GamepadAction.actionB);
        if (isDown(2)) actions.add(GamepadAction.actionX);
        if (isDown(3)) actions.add(GamepadAction.actionY);
        if (isDown(4)) actions.add(GamepadAction.bumperLeft);
        if (isDown(5)) actions.add(GamepadAction.bumperRight);
        if (isDown(8)) actions.add(GamepadAction.select);
        if (isDown(9)) actions.add(GamepadAction.start);
        if (isDown(12)) actions.add(GamepadAction.dpadUp);
        if (isDown(13)) actions.add(GamepadAction.dpadDown);
        if (isDown(14)) actions.add(GamepadAction.dpadLeft);
        if (isDown(15)) actions.add(GamepadAction.dpadRight);

        // Also map D-Pad onto stick values if D-Pad is pressed
        if (actions.contains(GamepadAction.dpadUp) && ly == 0.0) ly = -1.0;
        if (actions.contains(GamepadAction.dpadDown) && ly == 0.0) ly = 1.0;
        if (actions.contains(GamepadAction.dpadLeft) && lx == 0.0) lx = -1.0;
        if (actions.contains(GamepadAction.dpadRight) && lx == 0.0) lx = 1.0;

        results.add(RawGamepadData(
          index: i,
          id: gp.id ?? 'Controller ${i + 1}',
          connected: true,
          leftStickX: lx,
          leftStickY: ly,
          rightStickX: rx,
          rightStickY: ry,
          pressedActions: actions,
        ));
      }
    } catch (_) {}
    return results;
  }
}
