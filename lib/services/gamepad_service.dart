import 'package:flutter/foundation.dart';
import 'gamepad_stub.dart'
    if (dart.library.html) 'gamepad_web.dart';

enum GamepadAction {
  actionA,      // Serve ball, select, confirm (A / Cross)
  actionB,      // Back, cancel (B / Circle)
  actionX,      // Alternate action (X / Square)
  actionY,      // Owner auto-play toggle / secondary (Y / Triangle)
  dpadUp,
  dpadDown,
  dpadLeft,
  dpadRight,
  start,        // Pause / Resume (Start / Options / Menu)
  select,       // Select / View / Share
  bumperLeft,   // LB / L1
  bumperRight,  // RB / R1
}

class RawGamepadData {
  final int index;
  final String id;
  final bool connected;
  final double leftStickX;
  final double leftStickY;
  final double rightStickX;
  final double rightStickY;
  final Set<GamepadAction> pressedActions;

  const RawGamepadData({
    required this.index,
    required this.id,
    required this.connected,
    this.leftStickX = 0.0,
    this.leftStickY = 0.0,
    this.rightStickX = 0.0,
    this.rightStickY = 0.0,
    this.pressedActions = const {},
  });
}

class GamepadService {
  static final GamepadService instance = GamepadService._();
  GamepadService._() {
    GamepadPlatform.init(() {
      poll();
    });
  }

  static const double deadzone = 0.15;

  final ValueNotifier<List<String>> connectedControllers = ValueNotifier<List<String>>([]);
  List<RawGamepadData> _currentControllers = [];
  final Map<int, Set<GamepadAction>> _prevActions = {};

  bool get hasAnyController => _currentControllers.isNotEmpty;
  int get controllerCount => _currentControllers.length;
  String get primaryControllerName => _currentControllers.isNotEmpty ? _cleanName(_currentControllers.first.id) : '';

  static String _cleanName(String raw) {
    if (raw.toLowerCase().contains('xbox')) return 'Xbox Controller';
    if (raw.toLowerCase().contains('dualshock') || raw.toLowerCase().contains('dualsense') || raw.toLowerCase().contains('playstation') || raw.toLowerCase().contains('wireless controller')) {
      return 'PlayStation Controller';
    }
    if (raw.toLowerCase().contains('nintendo') || raw.toLowerCase().contains('switch')) {
      return 'Switch Controller';
    }
    final trimmed = raw.split('(').first.trim();
    return trimmed.isNotEmpty ? trimmed : 'Gamepad';
  }

  void poll() {
    final polled = GamepadPlatform.poll();
    _currentControllers = polled;

    final names = polled.map((c) => _cleanName(c.id)).toList();
    if (!listEquals(connectedControllers.value, names)) {
      connectedControllers.value = names;
    }
  }

  void afterFrame() {
    _prevActions.clear();
    for (final c in _currentControllers) {
      _prevActions[c.index] = Set<GamepadAction>.from(c.pressedActions);
    }
  }

  double getMovementY({int player = 1}) {
    if (_currentControllers.isEmpty) return 0.0;

    if (player == 1) {
      final c = _currentControllers.first;
      return _applyDeadzone(c.leftStickY);
    }

    // Player 2
    if (_currentControllers.length > 1) {
      final c2 = _currentControllers[1];
      return _applyDeadzone(c2.leftStickY);
    }

    // Single controller fallback for 2P mode: Player 2 can use Right Stick
    final c1 = _currentControllers.first;
    return _applyDeadzone(c1.rightStickY);
  }

  double getMovementX({int player = 1}) {
    if (_currentControllers.isEmpty) return 0.0;
    final c = (player == 2 && _currentControllers.length > 1)
        ? _currentControllers[1]
        : _currentControllers.first;
    return _applyDeadzone(c.leftStickX);
  }

  bool isActionDown(GamepadAction action, {int player = 1}) {
    if (_currentControllers.isEmpty) return false;
    final c = (player == 2 && _currentControllers.length > 1)
        ? _currentControllers[1]
        : _currentControllers.first;
    return c.pressedActions.contains(action);
  }

  bool isActionJustPressed(GamepadAction action, {int player = 1}) {
    if (_currentControllers.isEmpty) return false;
    final c = (player == 2 && _currentControllers.length > 1)
        ? _currentControllers[1]
        : _currentControllers.first;

    final isDownNow = c.pressedActions.contains(action);
    final wasDownBefore = _prevActions[c.index]?.contains(action) ?? false;
    return isDownNow && !wasDownBefore;
  }

  double _applyDeadzone(double val) {
    if (val.abs() < deadzone) return 0.0;
    // Normalize remainder so sensitivity starts smoothly above deadzone
    final sign = val > 0 ? 1.0 : -1.0;
    return sign * ((val.abs() - deadzone) / (1.0 - deadzone)).clamp(0.0, 1.0);
  }
}
