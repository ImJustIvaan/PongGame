import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../services/storage_service.dart';

class UsernamePromptDialog extends StatefulWidget {
  final PongTheme theme;

  const UsernamePromptDialog({super.key, required this.theme});

  static Future<String?> show(BuildContext context, PongTheme theme) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => UsernamePromptDialog(theme: theme),
    );
  }

  @override
  State<UsernamePromptDialog> createState() => _UsernamePromptDialogState();
}

class _UsernamePromptDialogState extends State<UsernamePromptDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  static const List<String> _randomNames = [
    'CYBER_PADDLE',
    'NEON_VIPER',
    'PONG_ACE',
    'RETRO_STRIKE',
    'ARCADE_HERO',
    'QUANTUM_SPIN',
    'SHADOW_HIT',
    'HYPER_BALL',
    'PADDLE_KING',
    'TURBO_RALLY',
  ];

  @override
  void initState() {
    super.initState();
    final existing = StorageService.instance.getUsername();
    if (existing != null && existing.isNotEmpty) {
      _controller.text = existing;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _generateRandom() {
    final rand = _randomNames[Random().nextInt(_randomNames.length)];
    final suffix = Random().nextInt(99) + 1;
    setState(() {
      _controller.text = '$rand$suffix';
      _error = null;
    });
  }

  void _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a username or click Random.');
      return;
    }
    if (name.length < 2) {
      setState(() => _error = 'Username must be at least 2 characters.');
      return;
    }

    await StorageService.instance.saveUsername(name);
    if (mounted) {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF111222),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: widget.theme.paddle1Color.withValues(alpha: 0.9), width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.theme.paddle1Color.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_pin_circle_outlined, size: 48, color: widget.theme.paddle1Color),
            const SizedBox(height: 12),
            Text(
              'MAKE A USERNAME',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: widget.theme.ballColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter your arcade gamer tag to track your scores and rank on the leaderboard:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              autofocus: true,
              style: TextStyle(color: widget.theme.ballColor, fontWeight: FontWeight.bold, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'e.g. CYBER_PADDLE',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                prefixIcon: Icon(Icons.badge_outlined, color: widget.theme.paddle1Color),
                suffixIcon: IconButton(
                  tooltip: 'Random Gamertag',
                  icon: const Icon(Icons.casino_outlined, color: Colors.white70),
                  onPressed: _generateRandom,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: widget.theme.paddle1Color, width: 2),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.paddle1Color,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submit,
                child: const Text(
                  'CONFIRM USERNAME',
                  style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                // Skip / play as guest
                Navigator.of(context).pop();
              },
              child: const Text('SKIP FOR NOW', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
