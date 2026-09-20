import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../services/supabase_service.dart';

class BannedDialog extends StatelessWidget {
  final BanRecord ban;
  final PongTheme theme;

  const BannedDialog({
    super.key,
    required this.ban,
    required this.theme,
  });

  static Future<void> show(BuildContext context, BanRecord ban, PongTheme theme) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (_) => BannedDialog(ban: ban, theme: theme),
    );
  }

  @override
  Widget build(BuildContext context) {
    const redGlow = Color(0xFFFF1744);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0B18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: redGlow.withValues(alpha: 0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: redGlow.withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: redGlow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: redGlow, width: 2),
              ),
              child: const Icon(Icons.gavel, color: redGlow, size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'ACCOUNT BANNED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: redGlow,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'User: @${ban.username}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      const Text('DURATION: ', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        ban.durationLabel.toUpperCase(),
                        style: const TextStyle(color: redGlow, fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      const Text('REASON: ', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          ban.reason,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (ban.bannedUntil != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.event_outlined, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        const Text('EXPIRES: ', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                          ban.bannedUntil!.toLocal().toString().split('.').first,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: redGlow,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('I UNDERSTAND', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
