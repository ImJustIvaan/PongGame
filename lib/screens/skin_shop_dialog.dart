import 'package:flutter/material.dart';
import '../game/game_theme.dart';
import '../game/paddle_skin.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../utils/user_utils.dart';

class SkinShopDialog extends StatefulWidget {
  final PongTheme theme;

  const SkinShopDialog({super.key, required this.theme});

  static Future<void> show(BuildContext context, PongTheme theme) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => SkinShopDialog(theme: theme),
    );
  }

  @override
  State<SkinShopDialog> createState() => _SkinShopDialogState();
}

class _SkinShopDialogState extends State<SkinShopDialog> {
  late String _equippedSkinId;
  late List<String> _ownedSkins;
  late int _coins;
  late String _currentUsername;
  bool _isUserVerified = false;

  int _selectedCategoryIndex = 0; // 0: All, 1: Solid, 2: Pattern, 3: Exclusive
  late PaddleSkin _previewSkin;
  String? _feedbackMessage;
  bool _isErrorFeedback = false;

  final List<String> _categories = ['ALL SKINS', 'SOLID COLORS', 'PATTERNS', 'EXCLUSIVE'];

  @override
  void initState() {
    super.initState();
    _refreshState();
    _previewSkin = PaddleSkinCatalog.byId(_equippedSkinId);
    _checkRemoteSync();
  }

  void _refreshState() {
    _equippedSkinId = StorageService.instance.getEquippedSkin();
    _ownedSkins = StorageService.instance.getOwnedSkins();
    _coins = StorageService.instance.getCoins();
    _currentUsername = SupabaseService.instance.currentUsername;
    _isUserVerified = UserUtils.isVerified(_currentUsername);
  }

  Future<void> _checkRemoteSync() async {
    final granted = await SupabaseService.instance.fetchGrantedSkins(_currentUsername);
    final verified = await SupabaseService.instance.checkVerifiedStatus(_currentUsername);
    if (mounted) {
      setState(() {
        for (final g in granted) {
          if (!_ownedSkins.contains(g)) {
            _ownedSkins.add(g);
          }
        }
        _isUserVerified = verified || UserUtils.isVerified(_currentUsername);
      });
    }
  }

  List<PaddleSkin> get _filteredSkins {
    switch (_selectedCategoryIndex) {
      case 1:
        return PaddleSkinCatalog.allSkins.where((s) => s.type == SkinType.solid).toList();
      case 2:
        return PaddleSkinCatalog.allSkins.where((s) => s.type == SkinType.pattern).toList();
      case 3:
        return PaddleSkinCatalog.allSkins.where((s) => s.type == SkinType.exclusive).toList();
      default:
        return PaddleSkinCatalog.allSkins;
    }
  }

  void _equipSkin(PaddleSkin skin) async {
    await StorageService.instance.saveEquippedSkin(skin.id);
    SoundService.instance.playPaddleHit();
    setState(() {
      _equippedSkinId = skin.id;
      _previewSkin = skin;
      _feedbackMessage = 'Equipped "${skin.name}"!';
      _isErrorFeedback = false;
    });
  }

  void _buySkin(PaddleSkin skin) async {
    if (_coins < skin.price) {
      setState(() {
        _feedbackMessage = 'Not enough coins! Need ${skin.price - _coins} more 🪙 (Win matches to earn).';
        _isErrorFeedback = true;
      });
      return;
    }

    // Deduct coins & add skin
    final newCoins = _coins - skin.price;
    await StorageService.instance.saveCoins(newCoins);
    await StorageService.instance.addOwnedSkin(skin.id);
    await StorageService.instance.saveEquippedSkin(skin.id);

    // Sync with Supabase if online
    SupabaseService.instance.syncLocalRecords(
      StorageService.instance.getHighScore(),
      StorageService.instance.getBestRally(),
      localCoins: newCoins,
      localLevel: StorageService.instance.getLevel(),
    );

    SoundService.instance.playScore();
    setState(() {
      _coins = newCoins;
      _ownedSkins.add(skin.id);
      _equippedSkinId = skin.id;
      _previewSkin = skin;
      _feedbackMessage = 'Purchased and equipped "${skin.name}" for 🪙 ${skin.price}!';
      _isErrorFeedback = false;
    });
  }

  void _claimVerifiedSkin(PaddleSkin skin) async {
    if (!_isUserVerified) {
      setState(() {
        _feedbackMessage = 'This skin is reserved exclusively for Verified players!';
        _isErrorFeedback = true;
      });
      return;
    }

    await StorageService.instance.addOwnedSkin(skin.id);
    await StorageService.instance.saveEquippedSkin(skin.id);
    SoundService.instance.playScore();
    setState(() {
      if (!_ownedSkins.contains(skin.id)) {
        _ownedSkins.add(skin.id);
      }
      _equippedSkinId = skin.id;
      _previewSkin = skin;
      _feedbackMessage = 'Unlocked and equipped Verified Legend Skin!';
      _isErrorFeedback = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const cyan = Color(0xFF00E5FF);
    const gold = Color(0xFFFFD700);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0D1E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cyan.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: cyan.withValues(alpha: 0.2),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cyan.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.palette, color: cyan, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PADDLE SKINS & WARDROBE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Customize your paddle • Solid colors & premium patterns',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  // Coins pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14172B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: gold.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.monetization_on, color: gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$_coins',
                          style: const TextStyle(
                            color: gold,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Live Preview Card
            Container(
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF070914),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _previewSkin.primaryColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  // Interactive Paddle Canvas Box
                  Container(
                    width: 50,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(16, 70),
                        painter: _SkinPreviewPainter(skin: _previewSkin),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _previewSkin.name.toUpperCase(),
                              style: TextStyle(
                                color: _previewSkin.primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildTypeTag(_previewSkin),
                            if (_equippedSkinId == _previewSkin.id) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00FF88).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF00FF88)),
                                ),
                                child: const Text(
                                  'EQUIPPED',
                                  style: TextStyle(color: Color(0xFF00FF88), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _previewSkin.description,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (_previewSkin.isVerifiedOnly) ...[
                              const Icon(Icons.verified, color: cyan, size: 14),
                              const SizedBox(width: 4),
                              const Text(
                                'Exclusive Verified Reward',
                                style: TextStyle(color: cyan, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ] else if (_previewSkin.price == 0) ...[
                              const Text('Default Starter Skin (Free)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            ] else ...[
                              const Icon(Icons.monetization_on, color: gold, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${_previewSkin.price} Coins',
                                style: const TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Feedback Message
            if (_feedbackMessage != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (_isErrorFeedback ? Colors.redAccent : const Color(0xFF00FF88)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_isErrorFeedback ? Colors.redAccent : const Color(0xFF00FF88)).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isErrorFeedback ? Icons.info_outline : Icons.check_circle_outline,
                      color: _isErrorFeedback ? Colors.redAccent : const Color(0xFF00FF88),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _feedbackMessage!,
                        style: TextStyle(
                          color: _isErrorFeedback ? Colors.redAccent : const Color(0xFF00FF88),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Filter Categories Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_categories.length, (index) {
                    final isSelected = _selectedCategoryIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          _categories[index],
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: cyan,
                        backgroundColor: const Color(0xFF14172B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? cyan : Colors.white12,
                          ),
                        ),
                        onSelected: (_) => setState(() => _selectedCategoryIndex = index),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Skins Grid / List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                itemCount: _filteredSkins.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final skin = _filteredSkins[index];
                  final isEquipped = _equippedSkinId == skin.id;
                  final isOwned = _ownedSkins.contains(skin.id) || skin.price == 0;
                  final isSelected = _previewSkin.id == skin.id;

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _previewSkin = skin),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF151936) : const Color(0xFF0E1126),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? skin.primaryColor
                              : isEquipped
                                  ? const Color(0xFF00FF88).withValues(alpha: 0.6)
                                  : Colors.white10,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Mini paddle preview
                          Container(
                            width: 32,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(10, 38),
                                painter: _SkinPreviewPainter(skin: skin),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      skin.name,
                                      style: TextStyle(
                                        color: isSelected ? skin.primaryColor : Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTypeTag(skin),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  skin.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Action Button
                          _buildSkinActionButton(skin, isEquipped, isOwned),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTag(PaddleSkin skin) {
    Color tagColor;
    String label;

    switch (skin.type) {
      case SkinType.solid:
        tagColor = const Color(0xFF00F0FF);
        label = 'SOLID';
        break;
      case SkinType.pattern:
        tagColor = const Color(0xFFFF007F);
        label = 'PATTERN';
        break;
      case SkinType.exclusive:
        tagColor = const Color(0xFFFFD700);
        label = 'VERIFIED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tagColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: tagColor, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSkinActionButton(PaddleSkin skin, bool isEquipped, bool isOwned) {
    if (isEquipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00FF88)),
        ),
        child: const Text(
          'EQUIPPED',
          style: TextStyle(color: Color(0xFF00FF88), fontWeight: FontWeight.bold, fontSize: 11),
        ),
      );
    }

    if (skin.isVerifiedOnly) {
      if (_isUserVerified || isOwned) {
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _claimVerifiedSkin(skin),
          child: const Text('EQUIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, color: Colors.white54, size: 12),
            SizedBox(width: 4),
            Text(
              'VERIFIED ONLY',
              style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ],
        ),
      );
    }

    if (isOwned) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00E5FF),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: () => _equipSkin(skin),
        child: const Text('EQUIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }

    // Purchase button
    final canAfford = _coins >= skin.price;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: canAfford ? const Color(0xFFFFD700) : Colors.white12,
        foregroundColor: canAfford ? Colors.black : Colors.white38,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => _buySkin(skin),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on, size: 13, color: canAfford ? Colors.black : Colors.white38),
          const SizedBox(width: 4),
          Text(
            '${skin.price}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _SkinPreviewPainter extends CustomPainter {
  final PaddleSkin skin;

  _SkinPreviewPainter({required this.skin});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width / 2),
    );
    skin.paintPaddle(canvas, rrect, isAutoPilot: false, hasGlow: true);
  }

  @override
  bool shouldRepaint(covariant _SkinPreviewPainter oldDelegate) => oldDelegate.skin.id != skin.id;
}
