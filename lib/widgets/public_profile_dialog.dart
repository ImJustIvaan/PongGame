import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../services/supabase_service.dart';
import '../utils/user_utils.dart';

class PublicProfileDialog extends StatelessWidget {
  final PlayerStats stats;
  final PongTheme theme;
  final VoidCallback? onChallenge;

  const PublicProfileDialog({
    super.key,
    required this.stats,
    required this.theme,
    this.onChallenge,
  });

  static Future<void> show(
    BuildContext context,
    PlayerStats stats,
    PongTheme theme, {
    VoidCallback? onChallenge,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => PublicProfileDialog(
        stats: stats,
        theme: theme,
        onChallenge: onChallenge,
      ),
    );
  }

  static Future<void> showByUsername(
    BuildContext context,
    String username,
    PongTheme theme, {
    VoidCallback? onChallenge,
  }) async {
    final stats = await SupabaseService.instance.fetchPlayerProfile(username);
    if (!context.mounted) return;

    if (stats == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF1744),
          content: Text(
            'Player "@$username" not found.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    return show(context, stats, theme, onChallenge: onChallenge);
  }

  @override
  Widget build(BuildContext context) {
    final cyan = theme.paddle1Color;
    final pink = theme.paddle2Color;
    final username = stats.username.startsWith('@') ? stats.username : '@${stats.username}';
    final isVerified = UserUtils.isVerified(stats.username);
    final isOwner = UserUtils.isOwner(stats.username);
    final isMe = stats.username.toLowerCase() == SupabaseService.instance.currentUsername.toLowerCase();
    final isMobile = MediaQuery.of(context).size.width < 460;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 24),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: const Color(0xFF090B1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cyan.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: 0.35),
              blurRadius: 32,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: pink.withValues(alpha: 0.2),
              blurRadius: 48,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top header bar
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cyan.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search, size: 13, color: cyan),
                          const SizedBox(width: 5),
                          Text(
                            isMe ? 'YOUR PROFILE' : 'PLAYER PROFILE',
                            style: TextStyle(
                              color: cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.close, color: Colors.white70, size: 16),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Avatar
                Container(
                  width: isMobile ? 56 : 68,
                  height: isMobile ? 56 : 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cyan.withValues(alpha: 0.15),
                    border: Border.all(color: cyan, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: cyan.withValues(alpha: 0.4),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      stats.username.isNotEmpty ? stats.username.replaceAll('@', '')[0].toUpperCase() : 'P',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 24 : 30,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: cyan, blurRadius: 12)],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Username + Verified Checkmark
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      UserUtils.verifiedBadge(size: isMobile ? 16 : 20),
                    ],
                  ],
                ),

                // Badges row (Verified, Owner)
                if (isVerified || isOwner) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOwner)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x33FF1744),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFF1744)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield, size: 10, color: Color(0xFFFF1744)),
                              SizedBox(width: 3),
                              Text(
                                'OWNER',
                                style: TextStyle(
                                  color: Color(0xFFFF1744),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (isVerified)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x2200E5FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 10, color: Color(0xFF00E5FF)),
                              SizedBox(width: 3),
                              Text(
                                'VERIFIED PLAYER',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],

                // Note: NO EMAIL DISPLAYED HERE (privacy preserved)
                const SizedBox(height: 12),

                // Level & Coins Banner
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 7 : 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10132B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22FFD700), blurRadius: 10, spreadRadius: 1),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bolt, color: const Color(0xFF00FF88), size: isMobile ? 18 : 20),
                          const SizedBox(width: 5),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LEVEL',
                                style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'LV. ${stats.level}',
                                style: TextStyle(
                                  color: const Color(0xFF00FF88),
                                  fontSize: isMobile ? 14 : 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(width: 1, height: isMobile ? 22 : 26, color: Colors.white24),
                      Row(
                        children: [
                          Icon(Icons.monetization_on, color: const Color(0xFFFFD700), size: isMobile ? 18 : 20),
                          const SizedBox(width: 5),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COINS',
                                style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${stats.coins}',
                                style: TextStyle(
                                  color: const Color(0xFFFFD700),
                                  fontSize: isMobile ? 14 : 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stat cards (2 rows of 3)
                Row(
                  children: [
                    Expanded(child: _buildStatCard('WINS', '${stats.wins}', Icons.emoji_events, const Color(0xFFFFD700), isMobile)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('KILLS', '${stats.kills}', Icons.local_fire_department, const Color(0xFFFF2A6D), isMobile)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('HIGH SCORE', '${stats.highScore}', Icons.stars, cyan, isMobile)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('BEST RALLY', '${stats.bestRally}', Icons.repeat, const Color(0xFF00FF88), isMobile)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('MATCHES', '${stats.gamesPlayed}', Icons.sports_tennis, Colors.white70, isMobile)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard('WIN RATE', '${stats.winRate.toStringAsFixed(0)}%', Icons.pie_chart, const Color(0xFF00E5FF), isMobile)),
                  ],
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    if (!isMe) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cyan,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                            elevation: 8,
                            shadowColor: cyan.withValues(alpha: 0.5),
                          ),
                          icon: const Icon(Icons.flash_on, size: 16),
                          label: const Text('CHALLENGE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.0)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            if (onChallenge != null) {
                              onChallenge!();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: cyan,
                                  content: Text(
                                    '🎮 Invite @${stats.username} to a match in Online 1v1!',
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 7 : 9, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF10132B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isMobile ? 14 : 16),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 12.5 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
