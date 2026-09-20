import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;
import '../widgets/set_new_password_dialog.dart';
import '../widgets/online_lobby_dialog.dart';
import '../widgets/banned_dialog.dart';
import '../utils/user_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../game/game_theme.dart';
import '../game/paddle_skin.dart';
import '../game/pong_engine.dart';
import '../services/fullscreen_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/pong_canvas.dart';
import 'account_dialog.dart';
import 'admin_panel_dialog.dart';
import 'game_screen.dart';
import 'skin_shop_dialog.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> with SingleTickerProviderStateMixin {
  StreamSubscription<AuthState>? _authSub;
  late PongThemeType _selectedThemeType;
  late AiDifficulty _difficulty;
  late int _targetScore;
  bool _soundEnabled = true;

  late final PongEngine _attractEngine;
  late final Ticker _attractTicker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _selectedThemeType = StorageService.instance.getTheme();
    _difficulty = StorageService.instance.getDifficulty();
    _targetScore = StorageService.instance.getTargetScore();
    _soundEnabled = StorageService.instance.getSoundEnabled();
    SoundService.instance.isMuted = !_soundEnabled;
    _initAuthListener();

    // Attract mode background demo (AI vs AI playing)
    _attractEngine = PongEngine(mode: GameMode.attractMode);
    _attractTicker = createTicker((elapsed) {
      if (_lastTick == Duration.zero) {
        _lastTick = elapsed;
        return;
      }
      final dt = ((elapsed - _lastTick).inMicroseconds / 1000000.0).clamp(0.0, 0.04);
      _lastTick = elapsed;
      _attractEngine.update(dt);
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _attractTicker.dispose();
    super.dispose();
  }

  void _initAuthListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kIsWeb) {
        final frag = Uri.base.fragment;
        final query = Uri.base.queryParameters;
        final path = Uri.base.path;

        if (frag.contains('type=recovery') || query['type'] == 'recovery') {
          _promptSetNewPassword();
          return;
        }

        // Check for /join/<gameId>
        String? joinGameId;
        if (path.contains('/join/')) {
          joinGameId = path.split('/join/').last.split('?').first.split('#').first.replaceAll('/', '').trim();
        } else if (frag.contains('join/')) {
          joinGameId = frag.split('join/').last.split('?').first.replaceAll('/', '').trim();
        } else if (query.containsKey('join')) {
          joinGameId = query['join'];
        }

        if (joinGameId != null && joinGameId.isNotEmpty) {
          _handleJoinLinkOnStartup(joinGameId);
        }
      }
    });

    _syncPlayerStats();

    _authSub = SupabaseService.instance.authStateChanges?.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _promptSetNewPassword();
      } else if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.tokenRefreshed ||
          data.event == AuthChangeEvent.userUpdated) {
        _syncPlayerStats();
      }
    });
  }

  Future<void> _syncPlayerStats() async {
    final isLogged = StorageService.instance.isLoggedIn() || SupabaseService.instance.isLoggedIn;
    if (isLogged) {
      try {
        final stats = await SupabaseService.instance.fetchMyStats();
        if (stats != null && mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('Notice syncing player stats in main menu: $e');
      }
    }
  }

  void _handleJoinLinkOnStartup(String gameId) async {
    if (!mounted) return;
    final isLogged = StorageService.instance.isLoggedIn() || SupabaseService.instance.isLoggedIn;
    if (!isLogged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF00E5FF),
          content: Text(
            '🎮 You received an invite! Please log in to join your friend.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 4),
        ),
      );
      await AccountDialog.show(context, _theme);
    }

    final isNowLogged = StorageService.instance.isLoggedIn() || SupabaseService.instance.isLoggedIn;
    if (isNowLogged && mounted) {
      _openOnlineMultiplayer(prefilledGameId: gameId);
    }
  }

  void _openOnlineMultiplayer({String? prefilledGameId}) async {
    final isLogged = StorageService.instance.isLoggedIn() || SupabaseService.instance.isLoggedIn;
    if (!isLogged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFFF71CE),
          content: Text(
            '🔒 Please log in or create an account to play online with friends.',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 3),
        ),
      );
      await AccountDialog.show(context, _theme);
      setState(() {});
      return;
    }

    final currentUsername = SupabaseService.instance.currentUsername;
    final ban = await SupabaseService.instance.checkBanStatus(currentUsername);
    if (ban != null && ban.isActive) {
      if (mounted) {
        BannedDialog.show(context, ban, _theme);
      }
      return;
    }

    if (mounted) {
      await OnlineLobbyDialog.show(
        context,
        theme: _theme,
        targetScore: _targetScore,
        prefilledGameId: prefilledGameId,
      );
      await _syncPlayerStats();
      if (mounted) setState(() {});
    }
  }

  void _promptSetNewPassword() async {
    if (!mounted) return;
    await SetNewPasswordDialog.show(context, _theme);
    await _syncPlayerStats();
    if (mounted) setState(() {});
  }

  PongTheme get _theme => PongTheme.fromType(_selectedThemeType);

  void _startGame(GameMode mode) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          mode: mode,
          difficulty: _difficulty,
          targetScore: _targetScore,
          theme: _theme,
        ),
      ),
    );
    await _syncPlayerStats();
    if (mounted) setState(() {});
  }



  @override
  Widget build(BuildContext context) {
    final highScore = StorageService.instance.getHighScore();
    final bestRally = StorageService.instance.getBestRally();
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 640 || screenSize.height < 600;
    // Responsive scale: 1.0 for default window (680h), scaling up to 1.5x on 1080p+ fullscreen, compact on mobile
    final double scale = isMobile
        ? (screenSize.width / 400.0).clamp(0.78, 0.96)
        : (screenSize.height / 680.0).clamp(0.85, 1.55);

    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      body: Stack(
        children: [
          // Background attract game (semi-transparent)
          Opacity(
            opacity: 0.35,
            child: PongCanvas(
              engine: _attractEngine,
              theme: _theme,
              skin1: PaddleSkinCatalog.byId(StorageService.instance.getEquippedSkin()),
            ),
          ),

          // Menu Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24,
                  vertical: isMobile ? 54 : (18 * scale).roundToDouble(),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title Logo
                    Text(
                      'THE PONG GAME!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _theme.ballColor,
                        fontSize: isMobile ? 26 : (38 * scale).roundToDouble(),
                        fontWeight: FontWeight.w900,
                        letterSpacing: isMobile ? 2.0 : 3.0 * scale,
                        shadows: _theme.hasGlow
                            ? [
                                Shadow(
                                  color: _theme.paddle1Color,
                                  blurRadius: (isMobile ? 18 : 28 * scale).roundToDouble(),
                                )
                              ]
                            : null,
                      ),
                    ),
                    SizedBox(height: isMobile ? 2 : (4 * scale).roundToDouble()),
                    Text(
                      'Are you game?',
                      style: TextStyle(
                        color: _theme.paddle1Color,
                        fontSize: isMobile ? 12.5 : (15 * scale).roundToDouble(),
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        letterSpacing: isMobile ? 1.5 : 2.0 * scale,
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : (28 * scale).roundToDouble()),

                    // Play Buttons
                    _buildPlayButton(
                      title: '1 PLAYER  (VS AI)',
                      subtitle: 'Difficulty: ${_difficulty.name.toUpperCase()}',
                      icon: Icons.person,
                      color: _theme.paddle1Color,
                      scale: scale,
                      isMobile: isMobile,
                      onTap: () => _startGame(GameMode.singlePlayer),
                    ),
                    SizedBox(height: isMobile ? 8 : (12 * scale).roundToDouble()),

                    _buildPlayButton(
                      title: 'ONLINE 1V1  (MULTIPLAYER)',
                      subtitle: 'Share Link • Challenge Friends',
                      icon: Icons.public,
                      color: const Color(0xFF00FF88),
                      scale: scale,
                      isMobile: isMobile,
                      onTap: () => _openOnlineMultiplayer(),
                    ),
                    SizedBox(height: isMobile ? 8 : (12 * scale).roundToDouble()),

                    _buildPlayButton(
                      title: '2 PLAYERS  (LOCAL)',
                      subtitle: 'Shared Screen / Dual Keys (Casual)',
                      icon: Icons.people,
                      color: _theme.paddle2Color,
                      scale: scale,
                      isMobile: isMobile,
                      onTap: () => _startGame(GameMode.twoPlayer),
                    ),
                    SizedBox(height: isMobile ? 8 : (12 * scale).roundToDouble()),

                    _buildPlayButton(
                      title: 'PRACTICE RALLY',
                      subtitle: 'Solo Rebound Wall',
                      icon: Icons.fitness_center,
                      color: _theme.ballColor,
                      scale: scale,
                      isMobile: isMobile,
                      onTap: () => _startGame(GameMode.practice),
                    ),
                    SizedBox(height: isMobile ? 14 : (24 * scale).roundToDouble()),

                    // Difficulty & Target Score Selectors
                    _buildOptionsRow(scale, isMobile, screenSize),

                    SizedBox(height: isMobile ? 14 : (20 * scale).roundToDouble()),

                    // Bottom Bar: Theme switcher, skins, leaderboard, sound
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: isMobile ? 6 : (10 * scale).roundToDouble(),
                      runSpacing: isMobile ? 6 : (8 * scale).roundToDouble(),
                      children: [
                        _buildIconButton(
                          icon: Icons.palette_outlined,
                          label: _theme.name,
                          scale: scale,
                          isMobile: isMobile,
                          onPressed: _showThemePicker,
                        ),
                        _buildIconButton(
                          icon: Icons.style,
                          label: 'SKINS',
                          scale: scale,
                          isMobile: isMobile,
                          onPressed: () async {
                            await SkinShopDialog.show(context, _theme);
                            await _syncPlayerStats();
                            setState(() {});
                          },
                        ),
                        _buildIconButton(
                          icon: Icons.leaderboard_outlined,
                          label: 'LEADERBOARD',
                          scale: scale,
                          isMobile: isMobile,
                          onPressed: () async {
                            final isLogged = StorageService.instance.isLoggedIn() || SupabaseService.instance.isLoggedIn;
                            final targetTab = isLogged ? 1 : 0;
                            await AccountDialog.show(context, _theme, initialTab: targetTab);
                            await _syncPlayerStats();
                            setState(() {});
                          },
                        ),
                        _buildIconButton(
                          icon: _soundEnabled ? Icons.volume_up : Icons.volume_off,
                          label: _soundEnabled ? 'SOUND ON' : 'MUTED',
                          scale: scale,
                          isMobile: isMobile,
                          onPressed: () {
                            setState(() {
                              _soundEnabled = !_soundEnabled;
                              SoundService.instance.isMuted = !_soundEnabled;
                              StorageService.instance.saveSoundEnabled(_soundEnabled);
                            });
                          },
                        ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 10 : (16 * scale).roundToDouble()),

                    // Stats summary
                    Text(
                      'LV. ${StorageService.instance.getLevel()}  •  ${StorageService.instance.getCoins()} COINS 🪙'
                      '${highScore > 0 || bestRally > 0 ? "  •  BEST SCORE: $highScore  •  RALLY: $bestRally" : ""}',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: isMobile ? 11 : (12 * scale).roundToDouble(),
                        letterSpacing: isMobile ? 1.0 : 1.5 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Unified Responsive Top Navigation & Stats Bar
          Positioned(
            top: 10,
            left: isMobile ? 10 : 16,
            right: isMobile ? 10 : 16,
            child: SafeArea(
              child: Row(
                children: [
                  // Fullscreen toggle (icon-only on mobile, icon+label on desktop)
                  ValueListenableBuilder<bool>(
                    valueListenable: FullscreenService.instance.isFullScreen,
                    builder: (context, isFs, _) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => FullscreenService.instance.toggle(),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : (10 * scale.clamp(1.0, 1.3)).roundToDouble(),
                            vertical: isMobile ? 6 : (6 * scale.clamp(1.0, 1.3)).roundToDouble(),
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF090B1E).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFs ? Icons.fullscreen_exit : Icons.fullscreen,
                                size: isMobile ? 16 : (16 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                color: _theme.paddle1Color,
                              ),
                              if (!isMobile) ...[
                                const SizedBox(width: 5),
                                Text(
                                  isFs ? 'EXIT' : 'FULLSCREEN',
                                  style: TextStyle(
                                    color: _theme.paddle1Color,
                                    fontSize: (11 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  Builder(
                    builder: (context) {
                      final isLogged = SupabaseService.instance.isLoggedIn || StorageService.instance.isLoggedIn();
                      final username = SupabaseService.instance.currentUsername;
                      final isVerified = UserUtils.isVerified(username);
                      final isOwner = UserUtils.isOwner(username);

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Level & Coins Pill
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 8 : (10 * scale.clamp(1.0, 1.3)).roundToDouble(),
                              vertical: isMobile ? 6 : (6 * scale.clamp(1.0, 1.3)).roundToDouble(),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF090B1E).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.6)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x22FFD700), blurRadius: 8, spreadRadius: 1),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt, size: 14, color: Color(0xFF00FF88)),
                                const SizedBox(width: 3),
                                Text(
                                  isMobile ? '${StorageService.instance.getLevel()}' : 'LV. ${StorageService.instance.getLevel()}',
                                  style: TextStyle(
                                    color: const Color(0xFF00FF88),
                                    fontSize: isMobile ? 11 : (11 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: isMobile ? 5 : 8),
                                const Text('•', style: TextStyle(color: Colors.white30, fontSize: 10)),
                                SizedBox(width: isMobile ? 5 : 8),
                                const Icon(Icons.monetization_on, size: 14, color: Color(0xFFFFD700)),
                                const SizedBox(width: 3),
                                Text(
                                  '${StorageService.instance.getCoins()}',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD700),
                                    fontSize: isMobile ? 11 : (11 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isMobile ? 6 : 8),

                          // If Owner: Admin Button
                          if (isOwner) ...[
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                await AdminPanelDialog.show(context, _theme);
                                await _syncPlayerStats();
                                setState(() {});
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 7 : (10 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                  vertical: isMobile ? 6 : (6 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFFF1744)),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x66FF1744), blurRadius: 10, spreadRadius: 1),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.admin_panel_settings, size: 15, color: Color(0xFFFF1744)),
                                    if (!isMobile) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        'ADMIN',
                                        style: TextStyle(
                                          color: const Color(0xFFFF1744),
                                          fontSize: (11 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: isMobile ? 6 : 8),
                          ],

                          // Profile / Login Button
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await AccountDialog.show(context, _theme);
                              await _syncPlayerStats();
                              setState(() {});
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 9 : (12 * scale.clamp(1.0, 1.3)).roundToDouble(),
                                vertical: isMobile ? 6 : (6 * scale.clamp(1.0, 1.3)).roundToDouble(),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF090B1E).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isLogged ? _theme.paddle1Color : Colors.white24,
                                ),
                                boxShadow: isLogged
                                    ? [
                                        BoxShadow(
                                          color: _theme.paddle1Color.withValues(alpha: 0.3),
                                          blurRadius: 10,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLogged ? Icons.account_circle : Icons.account_circle_outlined,
                                    size: isMobile ? 15 : 16,
                                    color: isLogged ? _theme.paddle1Color : Colors.white70,
                                  ),
                                  const SizedBox(width: 5),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isMobile
                                          ? (screenSize.width * 0.38).clamp(120.0, 160.0)
                                          : 180,
                                    ),
                                    child: Text(
                                      isLogged
                                          ? (username.startsWith('@') ? username : '@$username')
                                          : (isMobile ? 'LOGIN' : 'SIGN IN'),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: isLogged ? _theme.paddle1Color : Colors.white70,
                                        fontSize: isMobile ? 11 : 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 3),
                                    UserUtils.verifiedBadge(size: isMobile ? 13 : 15),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double scale,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final btnWidth = isMobile
        ? (screenSize.width - 32).clamp(260.0, 390.0)
        : (320 * scale).clamp(320.0, 480.0);
    return Container(
      width: btnWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16 * scale),
        boxShadow: _theme.hasGlow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.25),
                  blurRadius: isMobile ? 8 : 14 * scale,
                  offset: Offset(0, isMobile ? 2 : 4 * scale),
                )
              ]
            : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 11 : (16 * scale).roundToDouble(),
            horizontal: isMobile ? 14 : (20 * scale).roundToDouble(),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 12 : 16 * scale)),
        ),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(icon, size: isMobile ? 22 : (28 * scale).roundToDouble(), color: Colors.black),
            SizedBox(width: isMobile ? 12 : (16 * scale).roundToDouble()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isMobile ? 13.5 : (16 * scale).roundToDouble(),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : (11 * scale).roundToDouble(),
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: isMobile ? 13 : (16 * scale).roundToDouble(), color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsRow(double scale, bool isMobile, Size screenSize) {
    final optWidth = isMobile
        ? (screenSize.width - 32).clamp(260.0, 390.0)
        : (320 * scale).clamp(320.0, 480.0);
    return Container(
      width: optWidth,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : (14 * scale).roundToDouble(),
        vertical: isMobile ? 8 : (12 * scale).roundToDouble(),
      ),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16 * scale),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI LEVEL:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isMobile ? 11 : (12 * scale).roundToDouble(),
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<AiDifficulty>(
                value: _difficulty,
                dropdownColor: const Color(0xFF151520),
                style: TextStyle(
                  color: _theme.paddle1Color,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 11.5 : (13 * scale).roundToDouble(),
                ),
                underline: const SizedBox(),
                isDense: true,
                items: AiDifficulty.values.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _difficulty = val);
                    StorageService.instance.saveDifficulty(val);
                  }
                },
              ),
            ],
          ),
          Divider(color: Colors.white10, height: isMobile ? 10 : (14 * scale).roundToDouble()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FIRST TO:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isMobile ? 11 : (12 * scale).roundToDouble(),
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<int>(
                value: _targetScore,
                dropdownColor: const Color(0xFF151520),
                style: TextStyle(
                  color: _theme.paddle1Color,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 11.5 : (13 * scale).roundToDouble(),
                ),
                underline: const SizedBox(),
                isDense: true,
                items: [5, 7, 11].map((pts) {
                  return DropdownMenuItem<int>(
                    value: pts,
                    child: Text('$pts POINTS'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _targetScore = val);
                    StorageService.instance.saveTargetScore(val);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String label,
    required double scale,
    required bool isMobile,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 10 : 12 * scale)),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : (14 * scale).roundToDouble(),
          vertical: isMobile ? 6 : (10 * scale).roundToDouble(),
        ),
      ),
      icon: Icon(icon, size: isMobile ? 14 : (18 * scale).roundToDouble(), color: Colors.white),
      label: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 10 : (12 * scale).roundToDouble(),
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: onPressed,
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141524),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SELECT THEME',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              ...PongThemeType.values.map((type) {
                final t = PongTheme.fromType(type);
                final isSelected = _selectedThemeType == type;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.paddle1Color,
                    radius: 12,
                  ),
                  title: Text(
                    t.name,
                    style: TextStyle(
                      color: isSelected ? t.paddle1Color : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: t.paddle1Color) : null,
                  onTap: () {
                    setState(() => _selectedThemeType = type);
                    StorageService.instance.saveTheme(type);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
