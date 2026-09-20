import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/game_theme.dart';
import '../game/pong_engine.dart';
import '../screens/account_dialog.dart';
import '../screens/game_screen.dart';
import '../services/online_match_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import 'banned_dialog.dart';

class OnlineLobbyDialog extends StatefulWidget {
  final PongTheme theme;
  final int targetScore;
  final String? prefilledGameId;

  const OnlineLobbyDialog({
    super.key,
    required this.theme,
    required this.targetScore,
    this.prefilledGameId,
  });

  static Future<void> show(
    BuildContext context, {
    required PongTheme theme,
    required int targetScore,
    String? prefilledGameId,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Online Lobby',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 130),
      pageBuilder: (ctx, _, _) => OnlineLobbyDialog(
        theme: theme,
        targetScore: targetScore,
        prefilledGameId: prefilledGameId,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        return Transform.scale(
          scale: 0.94 + (0.06 * anim.value),
          child: Opacity(
            opacity: anim.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<OnlineLobbyDialog> createState() => _OnlineLobbyDialogState();
}

class _OnlineLobbyDialogState extends State<OnlineLobbyDialog> with SingleTickerProviderStateMixin {
  static const Color cyan = Color(0xFF00F0FF);
  static const Color neonGreen = Color(0xFF00FF88);

  final _joinCodeController = TextEditingController();
  final OnlineMatchService _matchService = OnlineMatchService.instance;

  int _selectedTab = 0; // 0: Host / Create, 1: Join
  late String _generatedGameId;
  late String _shareableLink;

  bool _isConnecting = false;
  bool _copiedLink = false;
  bool _copiedCode = false;
  String? _statusError;

  late final AnimationController _radarController;

  bool get _isLoggedIn => StorageService.instance.isLoggedIn() || SupabaseService.instance.isLoggedIn;
  String get _currentUsername => SupabaseService.instance.currentUsername;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.prefilledGameId != null ? 1 : 0;
    _generatedGameId = OnlineMatchService.generateGameId();
    _shareableLink = OnlineMatchService.buildShareLink(_generatedGameId);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    if (widget.prefilledGameId != null && widget.prefilledGameId!.isNotEmpty) {
      _joinCodeController.text = widget.prefilledGameId!;
    }

    // Fast startup: host immediately without laggy spinners if logged in
    if (_isLoggedIn) {
      if (widget.prefilledGameId == null) {
        _startHosting();
      }
      _checkBanSilently();
    }
  }

  Future<void> _checkBanSilently() async {
    final ban = await SupabaseService.instance.checkBanStatus(_currentUsername);
    if (mounted && ban != null && ban.isActive) {
      Navigator.of(context).pop();
      BannedDialog.show(context, ban, widget.theme);
    }
  }

  void _startHosting() async {
    if (!_isLoggedIn) return;

    setState(() {
      _isConnecting = true;
      _statusError = null;
    });

    _matchService.onOpponentJoined = (guestName) {
      if (!mounted) return;

      // Launch Online Multiplayer GameScreen as Host
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameScreen(
            mode: GameMode.onlineMultiplayer,
            theme: widget.theme,
            targetScore: widget.targetScore,
            isOnlineHost: true,
            onlineRoomId: _generatedGameId,
            opponentUsername: guestName,
          ),
        ),
      );
    };

    _matchService.onStateChanged = (state) {
      if (mounted) {
        setState(() {
          if (state == OnlineConnectionState.error) {
            _statusError = _matchService.errorMessage ?? 'Connection error';
            _isConnecting = false;
          } else if (state == OnlineConnectionState.waitingForGuest) {
            _isConnecting = false;
          }
        });
      }
    };

    final ok = await _matchService.hostMatch(
      gameId: _generatedGameId,
      hostUsername: _currentUsername,
      targetScore: widget.targetScore,
    );

    if (!ok && mounted) {
      setState(() {
        _isConnecting = false;
        _statusError = _matchService.errorMessage ?? 'Could not create room';
      });
    }
  }

  void _handleJoin() async {
    final rawInput = _joinCodeController.text.trim();
    if (rawInput.isEmpty) {
      setState(() => _statusError = 'Enter a room code or share link');
      return;
    }

    final code = OnlineMatchService.extractGameId(rawInput);
    if (code.isEmpty) {
      setState(() => _statusError = 'Invalid game code or link');
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusError = null;
    });

    _matchService.onStateChanged = (state) {
      if (mounted) {
        setState(() {
          if (state == OnlineConnectionState.error) {
            _statusError = _matchService.errorMessage ?? 'Failed to connect to room';
            _isConnecting = false;
          }
        });
      }
    };

    final ok = await _matchService.joinMatch(
      gameId: code,
      guestUsername: _currentUsername,
      onMatchReady: (targetScore) {
        if (!mounted) return;

        // Launch Online Multiplayer GameScreen as Guest
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameScreen(
              mode: GameMode.onlineMultiplayer,
              theme: widget.theme,
              targetScore: targetScore,
              isOnlineHost: false,
              onlineRoomId: code,
              opponentUsername: _matchService.opponentUsername ?? 'Host',
            ),
          ),
        );
      },
    );

    if (!ok && mounted) {
      setState(() {
        _isConnecting = false;
        _statusError = _matchService.errorMessage ?? 'Match room not found or expired.';
      });
    }
  }

  void _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareableLink));
    setState(() => _copiedLink = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedLink = false);
    });
  }

  void _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _generatedGameId));
    setState(() => _copiedCode = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedCode = false);
    });
  }

  void _switchTab(int tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
      _statusError = null;
    });

    if (tab == 0) {
      _startHosting();
    } else {
      _matchService.leaveMatch();
      setState(() => _isConnecting = false);
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: const Color(0xFF090C16),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cyan.withValues(alpha: 0.65), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: 0.18),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Top Cyber HUD Bar
              Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1222),
                  border: Border(bottom: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: neonGreen,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: neonGreen, blurRadius: 6, spreadRadius: 1)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '1V1 MULTIPLAYER ARENA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cyan.withValues(alpha: 0.4)),
                      ),
                      child: const Text(
                        'REALTIME WebSocket',
                        style: TextStyle(color: cyan, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        await _matchService.leaveMatch();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, color: Colors.white60, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // Content Body
              Flexible(
                child: !_isLoggedIn
                    ? _buildLoginView()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 2. High-Tech Segmented Mode Switcher
                            _buildSegmentedSwitch(),
                            const SizedBox(height: 16),

                            // Error banner
                            if (_statusError != null) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0x33FF1744),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFF1744)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _statusError!,
                                        style: const TextStyle(color: Color(0xFFFF1744), fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // 3. Tab Body
                            if (_selectedTab == 0)
                              _buildHostArenaView()
                            else
                              _buildJoinArenaView(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Segmented Switcher ---
  Widget _buildSegmentedSwitch() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF12172B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchTab(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: _selectedTab == 0
                      ? [BoxShadow(color: cyan.withValues(alpha: 0.35), blurRadius: 8)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 15,
                      color: _selectedTab == 0 ? Colors.black : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'HOST ARENA',
                      style: TextStyle(
                        color: _selectedTab == 0 ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _switchTab(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? cyan : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: _selectedTab == 1
                      ? [BoxShadow(color: cyan.withValues(alpha: 0.35), blurRadius: 8)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login_sharp,
                      size: 15,
                      color: _selectedTab == 1 ? Colors.black : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'JOIN ARENA',
                      style: TextStyle(
                        color: _selectedTab == 1 ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HOST ARENA VIEW ---
  Widget _buildHostArenaView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // VS Duel Head-to-Head Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF101428),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              // P1 Player
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HOST (P1)', style: TextStyle(color: cyan, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Text(
                      '@$_currentUsername',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: neonGreen, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('READY', style: TextStyle(color: neonGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              // VS Emblem
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF007F).withValues(alpha: 0.6)),
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(color: Color(0xFFFF007F), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),

              // P2 Challenger Radar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('CHALLENGER (P2)', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    const Text(
                      'SEARCHING...',
                      style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.w900, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${widget.targetScore} pts',
                      style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Radar Scan & Hero Room Code Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1020),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cyan.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              // Holographic Sonar Radar Sweep
              SizedBox(
                height: 52,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(52, 52),
                      painter: _SonarRadarPainter(
                        animation: _radarController,
                        color: cyan,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'AWAITING OPPONENT...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Match begins automatically on connect',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 14),

              // Room Code Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ROOM ACCESS CODE',
                    style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                  InkWell(
                    onTap: _copyCode,
                    child: Text(
                      _copiedCode ? 'COPIED!' : 'CLICK TO COPY',
                      style: TextStyle(color: _copiedCode ? neonGreen : cyan, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Code Hero Box
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _copyCode,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141932),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cyan.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatCode(_generatedGameId),
                        style: const TextStyle(
                          color: cyan,
                          fontSize: 22,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(_copiedCode ? Icons.check : Icons.copy, color: _copiedCode ? neonGreen : cyan, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Shareable Link Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF070A14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        _shareableLink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: Icon(_copiedLink ? Icons.check : Icons.share, size: 14),
                    label: Text(
                      _copiedLink ? 'COPIED' : 'INVITE LINK',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.6),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _copiedLink ? neonGreen : cyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: _copyLink,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tip text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: cyan.withValues(alpha: 0.7), size: 13),
            const SizedBox(width: 4),
            Text(
              'Send code or link to any friend on PC, Mac, or Web',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10.5),
            ),
          ],
        ),
      ],
    );
  }

  // --- JOIN ARENA VIEW ---
  Widget _buildJoinArenaView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1020),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cyan.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ENTER BATTLE CODE OR INVITE LINK',
                style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _joinCodeController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                cursorColor: cyan,
                decoration: InputDecoration(
                  hintText: 'e.g. 2tx9dp or https://pong.ivaan.cc/...',
                  hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                  prefixIcon: const Icon(Icons.videogame_asset, color: cyan, size: 18),
                  suffixIcon: TextButton.icon(
                    icon: const Icon(Icons.paste, size: 14, color: cyan),
                    label: const Text('PASTE', style: TextStyle(color: cyan, fontSize: 10, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _joinCodeController.text = data!.text!.trim();
                      }
                    },
                  ),
                  filled: true,
                  fillColor: const Color(0xFF131830),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cyan, width: 1.5)),
                ),
                onSubmitted: (_) => _handleJoin(),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  icon: _isConnecting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.sports_esports, size: 18),
                  label: Text(
                    _isConnecting ? 'ESTABLISHING LINK...' : 'CONNECT & BATTLE',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 1.2),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: _isConnecting ? null : _handleJoin,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Info Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF101428),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: const Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: Color(0xFFFFD700), size: 16),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ranked 1v1 PvP: Match victories award +1 Level and +50 Coins!',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- LOGIN REQUIRED VIEW ---
  Widget _buildLoginView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_person, color: Color(0xFFFF007F), size: 40),
          const SizedBox(height: 12),
          const Text(
            'ACCOUNT REQUIRED',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            'Log in to challenge friends online, save wins, and unlock custom paddle skins.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login, size: 16),
              label: const Text('SIGN IN / SIGN UP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                await AccountDialog.show(context, widget.theme);
                if (mounted) setState(() {});
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatCode(String code) {
    return code.toUpperCase().split('').join(' ');
  }
}

// Lightweight Holographic Sonar Radar Sweep
class _SonarRadarPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _SonarRadarPainter({required this.animation, required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Background circle
    final bgPaint = Paint()..color = color.withValues(alpha: 0.06);
    canvas.drawCircle(center, maxR, bgPaint);

    // Concentric rings
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, maxR * 0.4, ringPaint);
    canvas.drawCircle(center, maxR * 0.75, ringPaint);
    canvas.drawCircle(center, maxR, ringPaint);

    // Rotating scan beam sweep
    final angle = animation.value * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          color.withValues(alpha: 0.5),
          Colors.transparent,
        ],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: maxR));

    canvas.drawCircle(center, maxR, sweepPaint);

    // Center pulse dot
    final centerDot = Paint()..color = color;
    canvas.drawCircle(center, 2.5, centerDot);
  }

  @override
  bool shouldRepaint(covariant _SonarRadarPainter oldDelegate) => true;
}
