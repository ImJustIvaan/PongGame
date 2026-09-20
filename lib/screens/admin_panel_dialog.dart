import 'package:flutter/material.dart';
import '../game/game_theme.dart';
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

class _AdminPanelDialogState extends State<AdminPanelDialog> {
  final _usernameController = TextEditingController();
  final _reasonController = TextEditingController();
  BanDurationOption _selectedDuration = BanDurationOption.sevenDays;

  bool _isLoading = false;
  bool _isLoadingList = true;
  String? _statusMessage;
  bool _isError = false;

  List<BanRecord> _bannedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchBans();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchBans() async {
    setState(() => _isLoadingList = true);
    final bans = await SupabaseService.instance.fetchBannedUsers();
    if (mounted) {
      setState(() {
        _bannedUsers = bans;
        _isLoadingList = false;
      });
    }
  }

  void _submitBan() async {
    final username = _usernameController.text.trim();
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
          _usernameController.clear();
          _reasonController.clear();
        }
      });
      _fetchBans();
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
      _fetchBans();
    }
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF1744);
    const cyan = Color(0xFF00E5FF);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 700),
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
                          'Ban Enforcement & Moderation (ImJustIvaan)',
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
            const Divider(color: Colors.white12, height: 1),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status feedback
                    if (_statusMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isError ? red.withValues(alpha: 0.15) : const Color(0xFF00E676).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isError ? red.withValues(alpha: 0.5) : const Color(0xFF00E676).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isError ? Icons.error_outline : Icons.check_circle_outline,
                              color: _isError ? red : const Color(0xFF00E676),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  color: _isError ? red : const Color(0xFF00E676),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Ban Form Box
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BAN A USER',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Target Username Field
                          TextField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            cursorColor: red,
                            decoration: InputDecoration(
                              labelText: 'Target Username',
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                              hintText: 'e.g. BadPlayer123',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              prefixIcon: const Icon(Icons.person_remove_outlined, color: red, size: 20),
                              filled: true,
                              fillColor: const Color(0xFF12152C),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: red.withValues(alpha: 0.4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: red, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Duration Dropdown
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF12152C),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, color: Colors.white70, size: 20),
                                const SizedBox(width: 12),
                                const Text('Duration: ', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                DropdownButton<BanDurationOption>(
                                  value: _selectedDuration,
                                  dropdownColor: const Color(0xFF12152C),
                                  style: const TextStyle(color: red, fontWeight: FontWeight.bold, fontSize: 13),
                                  underline: const SizedBox(),
                                  items: BanDurationOption.values.map((opt) {
                                    return DropdownMenuItem(
                                      value: opt,
                                      child: Text(opt.label),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedDuration = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Reason Field
                          TextField(
                            controller: _reasonController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            cursorColor: red,
                            decoration: InputDecoration(
                              labelText: 'Ban Reason (Optional)',
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                              hintText: 'e.g. Cheating / Toxic behavior / Stat farming',
                              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                              prefixIcon: const Icon(Icons.note_alt_outlined, color: Colors.white54, size: 20),
                              filled: true,
                              fillColor: const Color(0xFF12152C),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: red, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Ban Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _isLoading ? null : _submitBan,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.gavel, size: 18),
                              label: Text(
                                _isLoading ? 'PROCESSING...' : 'EXECUTE BAN',
                                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Active Bans List Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'BANNED USERS (${_bannedUsers.length})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: cyan, size: 20),
                          tooltip: 'Refresh Banned List',
                          onPressed: _fetchBans,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isLoadingList)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(strokeWidth: 2, color: cyan),
                        ),
                      )
                    else if (_bannedUsers.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Center(
                          child: Text(
                            'No users are currently banned.',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _bannedUsers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final ban = _bannedUsers[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10132B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ban.isActive ? red.withValues(alpha: 0.3) : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: ban.isActive ? red.withValues(alpha: 0.2) : Colors.white12,
                                  child: Icon(
                                    ban.isActive ? Icons.block : Icons.lock_open,
                                    color: ban.isActive ? red : Colors.white54,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '@${ban.username}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (ban.isActive ? red : Colors.white24).withValues(alpha: 0.18),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              ban.durationLabel,
                                              style: TextStyle(
                                                color: ban.isActive ? red : Colors.white54,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Reason: ${ban.reason}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white70,
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _unban(ban.username),
                                  child: const Text('UNBAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
