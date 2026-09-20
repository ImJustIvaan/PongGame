import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../game/paddle_skin.dart';
import '../services/supabase_service.dart';
import '../utils/user_utils.dart';

enum BanDurationOption {
  oneDay,
  threeDays,
  sevenDays,
  oneMonth,
  oneYear,
  permanent;

  String get label {
    switch (this) {
      case BanDurationOption.oneDay:
        return '1 Day';
      case BanDurationOption.threeDays:
        return '3 Days';
      case BanDurationOption.sevenDays:
        return '7 Days';
      case BanDurationOption.oneMonth:
        return '1 Month (30d)';
      case BanDurationOption.oneYear:
        return '1 Year (365d)';
      case BanDurationOption.permanent:
        return 'Permanent Ban';
    }
  }

  Duration? get duration {
    switch (this) {
      case BanDurationOption.oneDay:
        return const Duration(days: 1);
      case BanDurationOption.threeDays:
        return const Duration(days: 3);
      case BanDurationOption.sevenDays:
        return const Duration(days: 7);
      case BanDurationOption.oneMonth:
        return const Duration(days: 30);
      case BanDurationOption.oneYear:
        return const Duration(days: 365);
      case BanDurationOption.permanent:
        return null;
    }
  }
}

class AdminPanelDialog extends StatefulWidget {
  final PongTheme theme;

  const AdminPanelDialog({super.key, required this.theme});

  static Future<void> show(BuildContext context, PongTheme theme) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => AdminPanelDialog(theme: theme),
    );
  }

  @override
  State<AdminPanelDialog> createState() => _AdminPanelDialogState();
}

class _AdminPanelDialogState extends State<AdminPanelDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Ban Tab Controllers
  final _banUsernameController = TextEditingController();
  final _reasonController = TextEditingController();
  BanDurationOption _selectedDuration = BanDurationOption.sevenDays;

  // Verification Tab Controllers
  final _verifyUsernameController = TextEditingController();

  // Grant Skin Tab Controllers
  final _skinUsernameController = TextEditingController();
  PaddleSkin _selectedSkinToGrant = PaddleSkinCatalog.allSkins.first;

  bool _isLoading = false;
  bool _isLoadingList = true;
  String? _statusMessage;
  bool _isError = false;

  List<BanRecord> _bannedUsers = [];
  List<String> _verifiedUsers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() => _statusMessage = null);
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _banUsernameController.dispose();
    _reasonController.dispose();
    _verifyUsernameController.dispose();
    _skinUsernameController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoadingList = true);
    final bans = await SupabaseService.instance.fetchBannedUsers();
    final verified = await SupabaseService.instance.fetchVerifiedUsers();
    if (mounted) {
      setState(() {
        _bannedUsers = bans;
        _verifiedUsers = verified;
        _isLoadingList = false;
      });
    }
  }

  void _submitBan() async {
    final username = _banUsernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Please enter a username to ban';
      });
      return;
    }

    if (UserUtils.isOwner(username)) {
      setState(() {
        _isError = true;
        _statusMessage = 'You cannot ban the owner account!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final reason = _reasonController.text.trim().isEmpty ? 'Terms of Service violation' : _reasonController.text.trim();
    final currentAdmin = SupabaseService.instance.currentUsername;

    final err = await SupabaseService.instance.banUser(
      username: username,
      duration: _selectedDuration.duration,
      reason: reason,
      bannedBy: currentAdmin,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (err != null) {
          _isError = true;
          _statusMessage = err;
        } else {
          _isError = false;
          _statusMessage = 'Successfully banned @$username (${_selectedDuration.label})';
          _banUsernameController.clear();
          _reasonController.clear();
        }
      });
      _fetchData();
    }
  }

  void _unban(String username) async {
    setState(() => _isLoading = true);
    await SupabaseService.instance.unbanUser(username);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isError = false;
        _statusMessage = 'Unbanned @$username';
      });
      _fetchData();
    }
  }

  void _submitVerification({required bool makeVerified}) async {
    final username = _verifyUsernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Please enter a username to verify';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final err = await SupabaseService.instance.setVerifiedStatus(
      username: username,
      isVerified: makeVerified,
      setBy: SupabaseService.instance.currentUsername,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (err != null) {
          _isError = true;
          _statusMessage = err;
        } else {
          _isError = false;
          _statusMessage = makeVerified
              ? 'Successfully verified @$username! Verified badge & exclusive skin granted.'
              : 'Revoked verification for @$username.';
          _verifyUsernameController.clear();
        }
      });
      _fetchData();
    }
  }

  void _revokeVerification(String username) async {
    if (UserUtils.isOwner(username)) {
      setState(() {
        _isError = true;
        _statusMessage = 'Cannot revoke owner verification!';
      });
      return;
    }

    setState(() => _isLoading = true);
    await SupabaseService.instance.setVerifiedStatus(
      username: username,
      isVerified: false,
      setBy: SupabaseService.instance.currentUsername,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isError = false;
        _statusMessage = 'Revoked verification for @$username';
      });
      _fetchData();
    }
  }

  void _submitGrantSkin() async {
    final username = _skinUsernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        _isError = true;
        _statusMessage = 'Please enter a username to receive the skin';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final err = await SupabaseService.instance.grantSkinToUser(
      username: username,
      skinId: _selectedSkinToGrant.id,
      grantedBy: SupabaseService.instance.currentUsername,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (err != null) {
          _isError = true;
          _statusMessage = err;
        } else {
          _isError = false;
          _statusMessage = 'Successfully granted "${_selectedSkinToGrant.name}" to @$username!';
          _skinUsernameController.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF1744);
    const cyan = Color(0xFF00E5FF);
    const gold = Color(0xFFFFD700);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C1B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: red.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: red.withValues(alpha: 0.25),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings, color: red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OWNER ADMIN PANEL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Bans • Verified Status • Give Skins (ImJustIvaan)',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF121528),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: red.withValues(alpha: 0.25),
                  border: Border.all(color: red.withValues(alpha: 0.8)),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(icon: Icon(Icons.block, size: 16), text: 'BAN PLAYERS'),
                  Tab(icon: Icon(Icons.verified, size: 16, color: cyan), text: 'VERIFY USERS'),
                  Tab(icon: Icon(Icons.card_giftcard, size: 16, color: gold), text: 'GIVE SKINS'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Status message
            if (_statusMessage != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _isError ? red.withValues(alpha: 0.15) : const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isError ? red.withValues(alpha: 0.5) : const Color(0xFF00E676).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError ? Icons.error_outline : Icons.check_circle_outline,
                      color: _isError ? red : const Color(0xFF00E676),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isError ? red : const Color(0xFF00E676),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Body Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBanTab(red),
                  _buildVerifyTab(cyan),
                  _buildGiveSkinsTab(gold),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: BAN USERS ---
  Widget _buildBanTab(Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TARGET USERNAME',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _banUsernameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter username to ban...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF14172B),
              prefixIcon: const Icon(Icons.person_off, color: Colors.white38, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'BAN DURATION',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BanDurationOption.values.map((option) {
              final isSelected = _selectedDuration == option;
              final isPerm = option == BanDurationOption.permanent;
              return ChoiceChip(
                label: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                  ),
                ),
                selected: isSelected,
                selectedColor: isPerm ? accentColor : const Color(0xFFD50000),
                backgroundColor: const Color(0xFF14172B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isSelected ? accentColor : Colors.white12),
                ),
                onSelected: (_) => setState(() => _selectedDuration = option),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          const Text(
            'REASON (OPTIONAL)',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _reasonController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'e.g. Cheating / Macro, Abusive behavior',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
              filled: true,
              fillColor: const Color(0xFF14172B),
              prefixIcon: const Icon(Icons.notes, color: Colors.white38, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitBan,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('ENFORCE ${_selectedDuration.label.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 20),

          // Active bans list
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ACTIVE BANNED USERS (${_bannedUsers.length})', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh, size: 16, color: Colors.white60), onPressed: _fetchData),
            ],
          ),
          const SizedBox(height: 6),
          if (_isLoadingList)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else if (_bannedUsers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF14172B), borderRadius: BorderRadius.circular(12)),
              child: const Text('No users are currently banned.', style: TextStyle(color: Colors.white38, fontSize: 12), textAlign: TextAlign.center),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bannedUsers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final ban = _bannedUsers[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFF14172B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@${ban.username}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('${ban.durationLabel} • Reason: ${ban.reason}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF00FF88)),
                        onPressed: () => _unban(ban.username),
                        child: const Text('UNBAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- TAB 2: VERIFY USERS ---
  Widget _buildVerifyTab(Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MAKE SOMEONE VERIFIED',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verified players get the official glowing cyan badge and unlock the exclusive Verified Legend paddle skin.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),

          const Text(
            'PLAYER USERNAME',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _verifyUsernameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter username to verify...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF14172B),
              prefixIcon: Icon(Icons.verified, color: accentColor, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('GRANT VERIFIED STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : () => _submitVerification(makeVerified: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // Current Verified Users List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('VERIFIED PLAYERS (${_verifiedUsers.length})', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.refresh, size: 16, color: Colors.white60), onPressed: _fetchData),
            ],
          ),
          const SizedBox(height: 6),
          if (_isLoadingList)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _verifiedUsers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final username = _verifiedUsers[index];
                final isOwner = UserUtils.isOwner(username);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14172B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: accentColor, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@$username ${isOwner ? "(Owner)" : ""}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (!isOwner)
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                          onPressed: () => _revokeVerification(username),
                          child: const Text('REVOKE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // --- TAB 3: GIVE SKINS ---
  Widget _buildGiveSkinsTab(Color accentColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GIVE OUT SKINS TO USERS',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          const Text(
            'Instantly grant any paddle skin (solid color, pattern, or exclusive) directly to any player by entering their username.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 12),

          const Text(
            'RECEIVER USERNAME',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _skinUsernameController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter username to receive skin...',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF14172B),
              prefixIcon: Icon(Icons.card_giftcard, color: accentColor, size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor)),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            'SELECT SKIN TO GRANT',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF14172B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<PaddleSkin>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF0F1226),
                    value: _selectedSkinToGrant,
                    items: PaddleSkinCatalog.allSkins.map((skin) {
                      return DropdownMenuItem<PaddleSkin>(
                        value: skin,
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 24,
                              decoration: BoxDecoration(
                                color: skin.primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              skin.name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${skin.type.name.toUpperCase()})',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (skin) {
                      if (skin != null) setState(() => _selectedSkinToGrant = skin);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedSkinToGrant.description,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 16),
              label: Text(
                'GRANT "${_selectedSkinToGrant.name.toUpperCase()}" TO USER',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _submitGrantSkin,
            ),
          ),
        ],
      ),
    );
  }
}
