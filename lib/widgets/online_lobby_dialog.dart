import 'dart:async';
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
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => OnlineLobbyDialog(
        theme: theme,
        targetScore: targetScore,
        prefilledGameId: prefilledGameId,
      ),
    );
  }

  @override
  State<OnlineLobbyDialog> createState() => _OnlineLobbyDialogState();
}

class _OnlineLobbyDialogState extends State<OnlineLobbyDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _joinCodeController = TextEditingController();
  final OnlineMatchService _matchService = OnlineMatchService.instance;

  late String _generatedGameId;
  late String _shareableLink;

  bool _isConnecting = false;
  bool _copied = false;
  String? _statusError;
  bool _isCheckingBan = false;

  bool get _isLoggedIn => StorageService.instance.isLoggedIn() || SupabaseService.instance.isLoggedIn;
  String get _currentUsername => SupabaseService.instance.currentUsername;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.prefilledGameId != null ? 1 : 0,
    );

    _generatedGameId = OnlineMatchService.generateGameId();
    _shareableLink = OnlineMatchService.buildShareLink(_generatedGameId);

    if (widget.prefilledGameId != null && widget.prefilledGameId!.isNotEmpty) {
      _joinCodeController.text = widget.prefilledGameId!;
    }

    _checkUserBanAndInit();
  }

  Future<void> _checkUserBanAndInit() async {
    if (!_isLoggedIn) return;

    setState(() => _isCheckingBan = true);
    final ban = await SupabaseService.instance.checkBanStatus(_currentUsername);
    if (mounted) {
      setState(() => _isCheckingBan = false);
      if (ban != null && ban.isActive) {
        Navigator.of(context).pop();
        BannedDialog.show(context, ban, widget.theme);
        return;
      }

      // If user came with prefilled code, auto-focus join tab
      if (widget.prefilledGameId == null) {
        _startHosting();
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF00FF88),
          content: Text(
            '🎮 $guestName joined! Starting 1v1 match...',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

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
      setState(() => _statusError = 'Please enter a game link or room code');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF00FF88),
            content: Text(
              'Connected to ${_matchService.opponentUsername ?? "Host"}! Starting 1v1 match...',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

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
        _statusError = _matchService.errorMessage ?? 'Failed to find match room.';
      });
    }
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cyan = widget.theme.paddle1Color;
    final pink = widget.theme.paddle2Color;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFF090B1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cyan.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: 0.35),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: _isCheckingBan
                ? Center(child: CircularProgressIndicator(color: cyan))
                : !_isLoggedIn
                    ? _buildLoginRequiredView(cyan, pink)
                    : _buildLobbyContent(cyan, pink),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequiredView(Color cyan, Color pink) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: cyan, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'ONLINE 1V1 MULTIPLAYER',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white60, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pink.withValues(alpha: 0.15),
            border: Border.all(color: pink, width: 2),
            boxShadow: [
              BoxShadow(
                color: pink.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Icon(Icons.lock_person, color: pink, size: 36),
        ),
        const SizedBox(height: 16),
        const Text(
          'ACCOUNT REQUIRED',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Online multiplayer requires you to be logged in so you can challenge friends, verify matches, and save legitimate leaderboard wins.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            icon: const Icon(Icons.login, size: 18),
            label: const Text(
              'SIGN IN / SIGN UP',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14),
            ),
            onPressed: () async {
              await AccountDialog.show(context, widget.theme);
              if (mounted) {
                setState(() {});
                if (_isLoggedIn) {
                  _checkUserBanAndInit();
                }
              }
            },
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('MAYBE LATER', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildLobbyContent(Color cyan, Color pink) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.wifi_tethering, color: cyan, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'ONLINE 1V1 MULTIPLAYER',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white60, size: 20),
              onPressed: () async {
                await _matchService.leaveMatch();
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Tabs
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10132B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: LinearGradient(colors: [cyan, const Color(0xFF0072FF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2),
            onTap: (idx) {
              if (idx == 0) {
                _startHosting();
              } else {
                _matchService.leaveMatch();
                setState(() {
                  _isConnecting = false;
                  _statusError = null;
                });
              }
            },
            tabs: const [
              Tab(text: 'CREATE MATCH'),
              Tab(text: 'JOIN MATCH'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_statusError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x33FF1744),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFF1744)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusError!,
                    style: const TextStyle(color: Color(0xFFFF1744), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        Flexible(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCreateTab(cyan, pink),
              _buildJoinTab(cyan, pink),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateTab(Color cyan, Color pink) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          // Shareable Link Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10132B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cyan.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, color: cyan, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'YOUR SHAREABLE GAME LINK:',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B1E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    _shareableLink,
                    style: TextStyle(
                      color: cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _copied ? const Color(0xFF00FF88) : cyan,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: Icon(_copied ? Icons.check : Icons.copy, size: 16),
                        label: Text(
                          _copied ? 'LINK COPIED!' : 'COPY LINK',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                        onPressed: () => _copyToClipboard(_shareableLink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cyan.withValues(alpha: 0.6)),
                        foregroundColor: cyan,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      ),
                      icon: const Icon(Icons.code, size: 16),
                      label: Text('ROOM: $_generatedGameId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      onPressed: () => _copyToClipboard(_generatedGameId),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Friend instructions callout (Explicit User Request requirement)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pink.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: pink.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.send_rounded, color: pink, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Give the link to your friend to play together!',
                        style: TextStyle(
                          color: pink,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Send this URL via Discord, WhatsApp, or chat. As soon as your friend clicks the link, your match will launch automatically!',
                        style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Waiting status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF10132B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: cyan,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'WAITING FOR OPPONENT...',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                      Text(
                        'Target Score: ${widget.targetScore} points',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildJoinTab(Color cyan, Color pink) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          const Text(
            'JOIN A FRIEND\'S MATCH',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paste the full link or 6-character room code given by your friend:',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _joinCodeController,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            cursorColor: cyan,
            decoration: InputDecoration(
              hintText: 'https://pong.ivaan.cc/join/xyz123 or code',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              prefixIcon: Icon(Icons.link, color: cyan, size: 18),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste, color: Colors.white54, size: 18),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data != null && data.text != null) {
                    _joinCodeController.text = data.text!.trim();
                  }
                },
              ),
              filled: true,
              fillColor: const Color(0xFF10132B),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cyan.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cyan, width: 2),
              ),
            ),
            onSubmitted: (_) => _handleJoin(),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              icon: _isConnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.play_arrow, size: 20),
              label: Text(
                _isConnecting ? 'CONNECTING...' : 'JOIN & PLAY NOW',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.1),
              ),
              onPressed: _isConnecting ? null : _handleJoin,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10132B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF00FF88), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Online PvP matches count towards legitimate wins & stats.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
