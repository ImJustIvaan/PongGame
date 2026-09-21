// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:js' as js;
import 'gamepad_service.dart';

class GamepadPlatform {
  static void init(void Function() onDevicesChanged) {
    try {
      html.window.addEventListener('gamepadconnected', (_) => onDevicesChanged());
      html.window.addEventListener('gamepaddisconnected', (_) => onDevicesChanged());
    } catch (_) {}
  }

  static List<RawGamepadData> poll() {
    final results = <RawGamepadData>[];

    // Primary: Direct JavaScript Interop (bypasses deprecated/incompatible GamepadList prototype wrappers)
    try {
      final nav = js.context['navigator'];
      if (nav != null) {
        dynamic rawList;
        try {
          rawList = js.context.callMethod('eval', ["(navigator.getGamepads ? navigator.getGamepads() : [])"]);
        } catch (_) {
          if (nav is js.JsObject && nav.hasProperty('getGamepads')) {
            rawList = nav.callMethod('getGamepads');
          }
        }

        if (rawList != null) {
          final len = (rawList['length'] as num?)?.toInt() ?? 0;
          for (var i = 0; i < len; i++) {
            final gp = rawList[i];
            if (gp == null) continue;

            final connected = gp['connected'];
            if (connected != true) continue;

            final id = (gp['id'] as String?) ?? 'Gamepad ${i + 1}';

            final axes = gp['axes'];
            final axesLen = (axes != null && axes['length'] != null) ? (axes['length'] as num).toInt() : 0;
            double getAxis(int idx) {
              if (axes == null || idx >= axesLen) return 0.0;
              final a = axes[idx];
              return (a as num?)?.toDouble() ?? 0.0;
            }

            double lx = getAxis(0);
            double ly = getAxis(1);
            double rx = getAxis(2);
            double ry = getAxis(3);

            final buttons = gp['buttons'];
            final btnLen = (buttons != null && buttons['length'] != null) ? (buttons['length'] as num).toInt() : 0;
            bool isDown(int idx) {
              if (buttons == null || idx >= btnLen) return false;
              final b = buttons[idx];
              if (b == null) return false;
              final pressed = b['pressed'] == true;
              final val = (b['value'] as num?)?.toDouble() ?? 0.0;
              return pressed || val > 0.5;
            }

            final actions = <GamepadAction>{};
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
              id: id,
              connected: true,
              leftStickX: lx,
              leftStickY: ly,
              rightStickX: rx,
              rightStickY: ry,
              pressedActions: actions,
            ));
          }

          if (results.isNotEmpty) return results;
        }
      }
    } catch (_) {}

    // Fallback: dart:html
    try {
      final gamepads = html.window.navigator.getGamepads();
      final length = gamepads.length;
      for (var i = 0; i < length; i++) {
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
