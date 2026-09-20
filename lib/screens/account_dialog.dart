import 'dart:math';
import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../utils/user_utils.dart';
import '../widgets/banned_dialog.dart';
import 'admin_panel_dialog.dart';

enum LeaderboardType {
  level('level', 'LEVEL', Icons.bolt, Color(0xFF00FF88)),
  kills('kills', 'KILLS', Icons.local_fire_department, Color(0xFFFF2A6D)),
  wins('wins', 'WINS', Icons.emoji_events, Color(0xFFFFD700)),
  score('high_score', 'SCORE', Icons.stars, Color(0xFF00E5FF));

  final String column;
  final String label;
  final IconData icon;
  final Color color;

  const LeaderboardType(this.column, this.label, this.icon, this.color);
}

class AccountDialog extends StatefulWidget {
  final PongTheme theme;
  final int? initialTab;
  final LeaderboardType? initialLeaderboardType;

  const AccountDialog({
    super.key,
    required this.theme,
    this.initialTab,
    this.initialLeaderboardType,
  });

  static Future<void> show(
    BuildContext context,
    PongTheme theme, {
    int? initialTab,
    LeaderboardType? initialLeaderboardType,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AccountDialog(
        theme: theme,
        initialTab: initialTab,
        initialLeaderboardType: initialLeaderboardType,
      ),
    );
  }

  @override
  State<AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<AccountDialog> with TickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabase = SupabaseService.instance;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isResetPasswordMode = false;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  PlayerStats? _myStats;
  List<PlayerStats> _leaderboard = [];
  bool _isLoadingLeaderboard = false;
  LeaderboardType _leaderboardType = LeaderboardType.level;

  static const List<String> _suggestedNames = [
    'CYBER_VIPER',
    'NEON_BLADE',
    'PADDLE_ZERO',
    'RETRO_GHOST',
    'PONG_TITAN',
    'QUANTUM_HIT',
    'HYPER_PULSE',
    'SHADOW_ACE',
    'TURBO_CORE',
    'VORTEX_KING',
  ];

  bool get _isLoggedIn => StorageService.instance.isLoggedIn() || _supabase.isLoggedIn;

  @override
  void initState() {
    super.initState();
    if (widget.initialLeaderboardType != null) {
      _leaderboardType = widget.initialLeaderboardType!;
    }
    _initTabController();

    final localName = StorageService.instance.getUsername();
    if (localName != null && localName.isNotEmpty) {
      _usernameController.text = localName;
    }

    _loadInitialData();
  }

  void _initTabController() {
    final count = _isLoggedIn ? 2 : 3;
    int index = 0;
    if (widget.initialTab != null) {
      index = widget.initialTab!.clamp(0, count - 1);
    }
    _tabController = TabController(
      length: count,
      vsync: this,
      initialIndex: index,
    );
  }

  void _rebuildTabController() {
    _tabController.dispose();
    _initTabController();
    setState(() {});
  }

  void _loadInitialData() async {
    if (_isLoggedIn) {
      final curName = _supabase.currentUsername;
      if (curName.isNotEmpty) {
        final ban = await _supabase.checkBanStatus(curName);
        if (ban != null && ban.isActive) {
          await _supabase.signOut();
          await StorageService.instance.setLoggedIn(false);
          if (mounted) {
            BannedDialog.show(context, ban, widget.theme);
            _rebuildTabController();
          }
          return;
        }
      }
      final stats = await _supabase.fetchMyStats();
      if (stats != null) {
        await StorageService.instance.syncFromRemoteStats(
          level: stats.level,
          coins: stats.coins,
          kills: stats.kills,
          wins: stats.wins,
          highScore: stats.highScore,
          bestRally: stats.bestRally,
        );
      }
      final localCoins = StorageService.instance.getCoins();
      final localLevel = StorageService.instance.getLevel();
      final localKills = StorageService.instance.getKills();
      final localWins = StorageService.instance.getWins();
      if (localCoins > (stats?.coins ?? 0) || localLevel > (stats?.level ?? 1)) {
        await _supabase.syncLocalRecords(
          StorageService.instance.getHighScore(),
          StorageService.instance.getBestRally(),
          localLevel: localLevel,
          localCoins: localCoins,
          localKills: localKills,
          localWins: localWins,
        );
      }
      if (mounted) setState(() => _myStats = stats);
    }
    _fetchLeaderboard();
  }

  void _fetchLeaderboard({LeaderboardType? type}) async {
    if (!mounted) return;
    if (type != null) {
      _leaderboardType = type;
    }
    setState(() => _isLoadingLeaderboard = true);
    try {
      final list = await _supabase.fetchLeaderboard(
        orderBy: _leaderboardType.column,
      ).timeout(const Duration(seconds: 8));
      if (mounted) {
        setState(() {
          _leaderboard = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaderboard in dialog: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLeaderboard = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _resetEmailController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    final email = _resetEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!_supabase.isConfigured) {
        final savedEmail = StorageService.instance.getSavedEmail();
        if (savedEmail != null && savedEmail.toLowerCase() == email.toLowerCase()) {
          if (mounted) {
            setState(() {
              _isResetPasswordMode = false;
              _successMessage = 'Local account found! You can sign up with a new password to overwrite.';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'No account found with that email address.';
            });
          }
        }
        return;
      }

      final error = await _supabase.resetPassword(email);
      if (error != null) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isResetPasswordMode = false;
            _successMessage = 'Password reset link sent to $email! Check your inbox.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Reset password failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showChangePasswordDialog() {
    _newPasswordController.clear();
    showDialog(
      context: context,
      builder: (ctx) {
        final cyan = widget.theme.paddle1Color;
        bool isSubmitting = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF090B1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cyan.withValues(alpha: 0.6)),
              ),
              title: const Text(
                'CHANGE PASSWORD',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter a new password (minimum 6 characters):',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: cyan,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: const Color(0xFF10132C),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cyan.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cyan),
                      ),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(dialogError!, style: const TextStyle(color: Color(0xFFFF1744), fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newPass = _newPasswordController.text.trim();
                          if (newPass.length < 6) {
                            setDialogState(() => dialogError = 'Password must be at least 6 characters');
                            return;
                          }
                          setDialogState(() => isSubmitting = true);

                          try {
                            if (_supabase.isConfigured) {
                              final err = await _supabase.updatePassword(newPass);
                              if (err != null) {
                                setDialogState(() {
                                  dialogError = err;
                                });
                                return;
                              }
                            }
                            await StorageService.instance.updateLocalPassword(newPass);
                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            if (mounted) {
                              setState(() => _successMessage = 'Password updated successfully!');
                            }
                          } catch (e) {
                            setDialogState(() {
                              dialogError = 'Failed to update password: $e';
                            });
                          } finally {
                            setDialogState(() => isSubmitting = false);
                          }
                        },
                  child: const Text('SAVE PASSWORD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _rollRandomName() {
    final rand = _suggestedNames[Random().nextInt(_suggestedNames.length)];
    final num = Random().nextInt(99) + 1;
    setState(() {
      _usernameController.text = '$rand$num';
      _errorMessage = null;
    });
  }

  void _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      if (!_supabase.isConfigured) {
        final isValid = StorageService.instance.validateLocalCredentials(
          email: email,
          password: password,
        );
        if (!isValid) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Invalid email or password. Please create an account first.';
            });
          }
          return;
        }

        final username = StorageService.instance.getUsername() ?? email.split('@').first;
        final ban = await _supabase.checkBanStatus(username);
        if (ban != null && ban.isActive) {
          await StorageService.instance.setLoggedIn(false);
          if (mounted) {
            BannedDialog.show(context, ban, widget.theme);
          }
          return;
        }

        await StorageService.instance.setLoggedIn(true);
        if (mounted) {
          setState(() {
            _successMessage = 'Welcome back, $username!';
          });
          _rebuildTabController();
        }
        return;
      }

      final error = await _supabase.signIn(email: email, password: password);
      if (error != null) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
          });
        }
      } else {
        final currentUsername = _supabase.currentUsername;
        if (currentUsername.isNotEmpty) {
          final ban = await _supabase.checkBanStatus(currentUsername);
          if (ban != null && ban.isActive) {
            await _supabase.signOut();
            await StorageService.instance.setLoggedIn(false);
            if (mounted) {
              BannedDialog.show(context, ban, widget.theme);
            }
            return;
          }
        }

        await StorageService.instance.setLoggedIn(true);
        try {
          await _supabase.syncLocalRecords(
            StorageService.instance.getHighScore(),
            StorageService.instance.getBestRally(),
            localLevel: StorageService.instance.getLevel(),
            localCoins: StorageService.instance.getCoins(),
          );
        } catch (e) {
          debugPrint('Error syncing local records: $e');
        }

        PlayerStats? stats;
        try {
          stats = await _supabase.fetchMyStats();
        } catch (e) {
          debugPrint('Error fetching stats: $e');
        }

        if (mounted) {
          setState(() {
            _myStats = stats;
            _successMessage = 'Welcome back, ${_supabase.currentUsername}!';
          });
          _rebuildTabController();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign in failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'All fields are required');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final ban = await _supabase.checkBanStatus(username);
      if (ban != null && ban.isActive) {
        if (mounted) {
          BannedDialog.show(context, ban, widget.theme);
        }
        return;
      }

      await StorageService.instance.saveLocalAccount(
        username: username,
        email: email,
        password: password,
      );

      if (!_supabase.isConfigured) {
        if (mounted) {
          setState(() {
            _successMessage = 'Account created for $username!';
          });
          _rebuildTabController();
        }
        return;
      }

      final error = await _supabase.signUp(
        email: email,
        password: password,
        username: username,
      );

      if (error != null) {
        if (mounted) {
          setState(() {
            _errorMessage = error;
          });
        }
      } else {
        try {
          await _supabase.syncLocalRecords(
            StorageService.instance.getHighScore(),
            StorageService.instance.getBestRally(),
            localLevel: StorageService.instance.getLevel(),
            localCoins: StorageService.instance.getCoins(),
          );
        } catch (e) {
          debugPrint('Error syncing local records: $e');
        }

        if (mounted) {
          setState(() {
            _successMessage = 'Welcome, $username!';
          });
          _rebuildTabController();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Sign up failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleLogOut() async {
    setState(() => _isLoading = true);
    try {
      await StorageService.instance.logout();
      await _supabase.signOut();
      if (mounted) {
        setState(() {
          _myStats = null;
          _successMessage = 'Logged out successfully';
          _errorMessage = null;
        });
        _rebuildTabController();
      }
    } catch (e) {
      debugPrint('Logout error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.theme.paddle1Color;
    final accentPink = widget.theme.paddle2Color;
    final loggedIn = _isLoggedIn;
    final isMobile = MediaQuery.of(context).size.width < 460;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16, vertical: 20),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: const Color(0xFF090B1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: glowColor.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: glowColor.withValues(alpha: 0.35),
              blurRadius: 32,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: accentPink.withValues(alpha: 0.2),
              blurRadius: 50,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Subtle background ambient glow
              Positioned(
                top: -60,
                right: -60,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor.withValues(alpha: 0.12),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.2),
                        blurRadius: 60,
                        spreadRadius: 30,
                      )
                    ],
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: loggedIn ? const Color(0x2200E5FF) : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: loggedIn ? glowColor.withValues(alpha: 0.7) : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: loggedIn ? const Color(0xFF00FF88) : Colors.white38,
                                  shape: BoxShape.circle,
                                  boxShadow: loggedIn
                                      ? [
                                          const BoxShadow(
                                            color: Color(0xFF00FF88),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                loggedIn ? 'LOGGED IN' : 'GUEST',
                                style: TextStyle(
                                  color: loggedIn ? glowColor : Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5,
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
                            padding: const EdgeInsets.all(6),
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

                    // Title
                    Text(
                      loggedIn ? 'PLAYER PROFILE' : 'PLAYER ACCOUNT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: glowColor.withValues(alpha: 0.8), blurRadius: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tab Bar
                    _buildSegmentedTabBar(glowColor),
                    const SizedBox(height: 16),

                    // Status Messages
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0x33FF1744),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF1744)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x44FF1744), blurRadius: 10)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFFF1744), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (_successMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0x3300FF88),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00FF88)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x4400FF88), blurRadius: 10)
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF00FF88), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Tab View
                    Flexible(
                      child: SizedBox(
                        height: (MediaQuery.of(context).size.height * 0.74).clamp(isMobile ? 470.0 : 490.0, 620.0),
                        child: TabBarView(
                          controller: _tabController,
                          children: loggedIn
                              ? [
                                  _buildProfileView(glowColor, isMobile),
                                  _buildLeaderboardView(glowColor),
                                ]
                              : [
                                  _buildLeaderboardView(glowColor),
                                  _isResetPasswordMode ? _buildResetPasswordView(glowColor) : _buildSignInView(glowColor),
                                  _buildSignUpView(glowColor, accentPink),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTabBar(Color glowColor) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final isMobile = MediaQuery.of(context).size.width < 460;
        final tabs = _isLoggedIn
            ? ['PROFILE & STATS', 'LEADERBOARD']
            : ['LEADERBOARD', 'SIGN IN', 'SIGN UP'];

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF10132C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: List.generate(tabs.length, (idx) {
              final isSelected = _tabController.index == idx;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _tabController.animateTo(idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 7 : 8),
                    decoration: BoxDecoration(
                      color: isSelected ? glowColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: glowColor.withValues(alpha: 0.5),
                                blurRadius: 14,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: Text(
                      tabs[idx],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white60,
                        fontSize: isMobile ? 9.5 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: isMobile ? 0.4 : 1.1,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildSignUpView(Color cyan, Color pink) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildNeonField(
            label: 'USERNAME',
            controller: _usernameController,
            hint: 'e.g. imjustivaan',
            icon: Icons.person_outline,
            glowColor: pink,
            trailing: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _rollRandomName,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: pink.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: pink.withValues(alpha: 0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.casino_outlined, size: 14, color: pink),
                    const SizedBox(width: 4),
                    Text(
                      'RANDOM',
                      style: TextStyle(color: pink, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildNeonField(
            label: 'EMAIL ADDRESS',
            controller: _emailController,
            hint: 'user@example.com',
            icon: Icons.alternate_email,
            glowColor: cyan,
          ),
          const SizedBox(height: 12),
          _buildNeonField(
            label: 'PASSWORD (6+ CHARACTERS)',
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscureText: true,
            glowColor: cyan,
          ),
          const SizedBox(height: 16),
          _buildGlowButton(
            title: 'CREATE ACCOUNT',
            gradientColors: [pink, const Color(0xFF9C27B0)],
            glowColor: pink,
            isLoading: _isLoading,
            onTap: _handleSignUp,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text(
                'Already have an account? SIGN IN',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordView(Color cyan) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: cyan, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => setState(() => _isResetPasswordMode = false),
              ),
              const SizedBox(width: 8),
              const Text(
                'RESET PASSWORD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter your email address to receive a secure password reset link:',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          _buildNeonField(
            label: 'EMAIL ADDRESS',
            controller: _resetEmailController,
            hint: 'user@example.com',
            icon: Icons.alternate_email,
            glowColor: cyan,
          ),
          const SizedBox(height: 16),
          _buildGlowButton(
            title: 'SEND RESET LINK',
            gradientColors: [cyan, const Color(0xFF0072FF)],
            glowColor: cyan,
            isLoading: _isLoading,
            onTap: _handleResetPassword,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _isResetPasswordMode = false),
              child: const Text(
                'Remember your password? SIGN IN',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInView(Color cyan) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          _buildNeonField(
            label: 'EMAIL ADDRESS',
            controller: _emailController,
            hint: 'user@example.com',
            icon: Icons.alternate_email,
            glowColor: cyan,
          ),
          const SizedBox(height: 16),
          _buildNeonField(
            label: 'PASSWORD',
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscureText: true,
            glowColor: cyan,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isResetPasswordMode = true;
                  _errorMessage = null;
                  _successMessage = null;
                  if (_emailController.text.trim().isNotEmpty) {
                    _resetEmailController.text = _emailController.text.trim();
                  }
                });
              },
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: cyan.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildGlowButton(
            title: 'SIGN IN',
            gradientColors: [cyan, const Color(0xFF0072FF)],
            glowColor: cyan,
            isLoading: _isLoading,
            onTap: _handleSignIn,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => _tabController.animateTo(2),
              child: const Text(
                'Need an account? SIGN UP',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileView(Color cyan, bool isMobile) {
    final rawName = _supabase.currentUsername;
    final isVerified = UserUtils.isVerified(rawName);
    final highScore = [ _myStats?.highScore ?? 0, StorageService.instance.getHighScore() ].reduce((a, b) => a > b ? a : b);
    final bestRally = [ _myStats?.bestRally ?? 0, StorageService.instance.getBestRally() ].reduce((a, b) => a > b ? a : b);
    final wins = [ _myStats?.wins ?? 0, StorageService.instance.getWins() ].reduce((a, b) => a > b ? a : b);
    final kills = [ _myStats?.kills ?? 0, StorageService.instance.getKills() ].reduce((a, b) => a > b ? a : b);
    final level = [ _myStats?.level ?? 1, StorageService.instance.getLevel() ].reduce((a, b) => a > b ? a : b);
    final coins = [ _myStats?.coins ?? 0, StorageService.instance.getCoins() ].reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      child: Column(
        children: [
        SizedBox(height: isMobile ? 2 : 4),
        Container(
          width: isMobile ? 52 : 68,
          height: isMobile ? 52 : 68,
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
              rawName.isNotEmpty ? rawName[0].toUpperCase() : 'P',
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 22 : 30,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: cyan, blurRadius: 12)],
              ),
            ),
          ),
        ),
        SizedBox(height: isMobile ? 4 : 8),

        // Username + Verified Checkmark
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              rawName,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            if (isVerified) UserUtils.verifiedBadge(size: isMobile ? 16 : 20),
          ],
        ),

        if (isVerified)
          Container(
            margin: const EdgeInsets.only(top: 2, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0x2200E5FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 11, color: Color(0xFF00E5FF)),
                SizedBox(width: 4),
                Text(
                  'VERIFIED PLAYER',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

        Text(
          _supabase.currentUser?.email ?? StorageService.instance.getSavedEmail() ?? 'Active Player Profile',
          style: TextStyle(color: Colors.white54, fontSize: isMobile ? 10 : 11),
        ),
        SizedBox(height: isMobile ? 8 : 12),

        // Level & Coins Banner
        Container(
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 6 : 8),
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
                  Icon(Icons.bolt, color: const Color(0xFF00FF88), size: isMobile ? 17 : 20),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LEVEL',
                        style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'LV. $level',
                        style: TextStyle(color: const Color(0xFF00FF88), fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
              Container(width: 1, height: isMobile ? 20 : 26, color: Colors.white24),
              Row(
                children: [
                  Icon(Icons.monetization_on, color: const Color(0xFFFFD700), size: isMobile ? 17 : 20),
                  const SizedBox(width: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'COINS',
                        style: TextStyle(color: Colors.white60, fontSize: 8.5, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$coins 🪙',
                        style: TextStyle(color: const Color(0xFFFFD700), fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Stats Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard('HIGH SCORE', '$highScore', cyan, isMobile),
            _buildStatCard('BEST RALLY', '$bestRally', const Color(0xFFFF71CE), isMobile),
            _buildStatCard('KILLS', '$kills', const Color(0xFFFF5252), isMobile),
            _buildStatCard('WINS', '$wins', const Color(0xFF00FF88), isMobile),
          ],
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Center(
          child: TextButton.icon(
            icon: Icon(Icons.lock_reset, size: isMobile ? 14 : 16, color: cyan.withValues(alpha: 0.9)),
            label: Text(
              'CHANGE PASSWORD',
              style: TextStyle(
                color: cyan.withValues(alpha: 0.9),
                fontSize: isMobile ? 10.5 : 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            onPressed: _showChangePasswordDialog,
          ),
        ),
        SizedBox(height: isMobile ? 8 : 14),

        if (UserUtils.isOwner(rawName)) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.symmetric(vertical: isMobile ? 9 : 12),
                elevation: 4,
              ),
              icon: Icon(Icons.admin_panel_settings, size: isMobile ? 17 : 20),
              label: Text(
                'OPEN OWNER ADMIN PANEL',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: isMobile ? 11.5 : 13),
              ),
              onPressed: () async {
                await AdminPanelDialog.show(context, widget.theme);
                final s = await _supabase.fetchMyStats();
                if (mounted) {
                  setState(() => _myStats = s);
                }
              },
            ),
          ),
          SizedBox(height: isMobile ? 8 : 10),
        ],

        // Bottom Actions: Sync & Log Out
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: cyan),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 9 : 12),
                ),
                icon: Icon(Icons.sync, color: cyan, size: isMobile ? 15 : 18),
                label: Text('SYNC STATS', style: TextStyle(color: cyan, fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12)),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _supabase.syncLocalRecords(
                    StorageService.instance.getHighScore(),
                    StorageService.instance.getBestRally(),
                    localLevel: StorageService.instance.getLevel(),
                    localCoins: StorageService.instance.getCoins(),
                    localKills: StorageService.instance.getKills(),
                    localWins: StorageService.instance.getWins(),
                  );
                  final s = await _supabase.fetchMyStats();
                  if (s != null) {
                    await StorageService.instance.syncFromRemoteStats(
                      level: s.level,
                      coins: s.coins,
                      kills: s.kills,
                      wins: s.wins,
                      highScore: s.highScore,
                      bestRally: s.bestRally,
                    );
                  }
                  if (mounted) {
                    setState(() {
                      _myStats = s;
                      _isLoading = false;
                      _successMessage = 'Stats & Progress synchronized!';
                    });
                  }
                },
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0x33FF1744),
                  foregroundColor: const Color(0xFFFF1744),
                  side: const BorderSide(color: Color(0xFFFF1744)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 9 : 12),
                ),
                icon: Icon(Icons.logout, size: isMobile ? 15 : 18),
                label: Text('LOG OUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 12)),
                onPressed: _isLoading ? null : _handleLogOut,
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }

  Widget _buildLeaderboardView(Color cyan) {
    final activeColor = _leaderboardType.color;
    final localHigh = StorageService.instance.getHighScore();
    final localBestRally = StorageService.instance.getBestRally();
    final localLevel = StorageService.instance.getLevel();
    final localCoins = StorageService.instance.getCoins();
    final localKills = StorageService.instance.getKills();
    final localWins = StorageService.instance.getWins();

    String userRecordText;
    switch (_leaderboardType) {
      case LeaderboardType.level:
        userRecordText = 'LEVEL $localLevel   •   $localCoins COINS';
        break;
      case LeaderboardType.kills:
        userRecordText = '$localKills KILLS RECORD';
        break;
      case LeaderboardType.wins:
        userRecordText = '$localWins WINS TOTAL';
        break;
      case LeaderboardType.score:
        userRecordText = 'HIGH SCORE: $localHigh   •   BEST RALLY: $localBestRally';
        break;
    }

    return Column(
      children: [
        // Category Selector Bar (LEVEL, KILLS, WINS, SCORE)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF10132C),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: LeaderboardType.values.map((type) {
              final isSelected = _leaderboardType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_leaderboardType != type) {
                      _fetchLeaderboard(type: type);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? type.color.withValues(alpha: 0.22) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? type.color : Colors.transparent,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: type.color.withValues(alpha: 0.35),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type.icon,
                          size: 13,
                          color: isSelected ? type.color : Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          type.label,
                          style: TextStyle(
                            color: isSelected ? type.color : Colors.white60,
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        if (!_isLoggedIn)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Want to rank on the board?',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: () => _tabController.animateTo(2),
                  child: Text(
                    'SIGN UP ➔',
                    style: TextStyle(color: cyan, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _isLoadingLeaderboard
              ? Center(child: CircularProgressIndicator(color: activeColor))
              : _leaderboard.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activeColor.withValues(alpha: 0.1),
                              border: Border.all(color: activeColor.withValues(alpha: 0.4)),
                            ),
                            child: Icon(_leaderboardType.icon, size: 44, color: activeColor),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'YOUR RECORD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            userRecordText,
                            style: TextStyle(
                              color: activeColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: activeColor,
                              side: BorderSide(color: activeColor.withValues(alpha: 0.6)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.refresh, size: 15),
                            label: const Text('RELOAD', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            onPressed: () => _fetchLeaderboard(),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _leaderboard.length,
                      itemBuilder: (context, idx) {
                        final item = _leaderboard[idx];
                        final rankMedal = idx == 0 ? '🥇' : (idx == 1 ? '🥈' : (idx == 2 ? '🥉' : '#${idx + 1}'));
                        final isTop3 = idx < 3;
                        final isVerified = UserUtils.isVerified(item.username);

                        String mainValue;
                        String subInfo;
                        switch (_leaderboardType) {
                          case LeaderboardType.level:
                            mainValue = 'LV. ${item.level}';
                            subInfo = '${item.wins} wins • ${item.kills} kills';
                            break;
                          case LeaderboardType.kills:
                            mainValue = '${item.kills} KILLS';
                            subInfo = 'LV. ${item.level} • ${item.wins} wins';
                            break;
                          case LeaderboardType.wins:
                            mainValue = '${item.wins} WINS';
                            subInfo = 'LV. ${item.level} • ${item.winRate.toStringAsFixed(0)}% win rate';
                            break;
                          case LeaderboardType.score:
                            mainValue = '${item.highScore} PTS';
                            subInfo = 'LV. ${item.level} • rally ${item.bestRally}';
                            break;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: isTop3 ? activeColor.withValues(alpha: 0.1) : const Color(0xFF10132C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isTop3 ? activeColor.withValues(alpha: 0.8) : Colors.white12,
                            ),
                            boxShadow: isTop3
                                ? [
                                    BoxShadow(
                                      color: activeColor.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                    )
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text(rankMedal, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.username,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (isVerified) UserUtils.verifiedBadge(size: 13),
                                        if (_leaderboardType != LeaderboardType.level)
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: const Color(0x2200FF88),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0x6600FF88)),
                                            ),
                                            child: Text(
                                              'LV.${item.level}',
                                              style: const TextStyle(
                                                color: Color(0xFF00FF88),
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subInfo,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: activeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: activeColor.withValues(alpha: 0.45)),
                                ),
                                child: Text(
                                  mainValue,
                                  style: TextStyle(
                                    color: activeColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    shadows: [Shadow(color: activeColor.withValues(alpha: 0.7), blurRadius: 8)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNeonField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color glowColor,
    bool obscureText = false,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: glowColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10132C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: glowColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.12),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(icon, color: glowColor, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  cursorColor: glowColor,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlowButton({
    required String title,
    required List<Color> gradientColors,
    required Color glowColor,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: gradientColors),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, [bool isMobile = false]) {
    return Container(
      width: isMobile ? 74 : 82,
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10132C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isMobile ? 14 : 16,
              shadows: [Shadow(color: color, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: color, fontSize: isMobile ? 7.5 : 8, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}
