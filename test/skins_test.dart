import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pong_game/game/paddle_skin.dart';
import 'package:pong_game/services/storage_service.dart';
import 'package:pong_game/utils/user_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.instance.init();
  });

  group('PaddleSkinCatalog Tests', () {
    test('Catalog contains default starter skin, solid colors, patterns, and verified skin', () {
      expect(PaddleSkinCatalog.allSkins.length, greaterThanOrEqualTo(10));
      expect(PaddleSkinCatalog.defaultSkin.id, 'classic_cyan');
      expect(PaddleSkinCatalog.defaultSkin.price, 0);

      final solidSkins = PaddleSkinCatalog.allSkins.where((s) => s.type == SkinType.solid).toList();
      expect(solidSkins.isNotEmpty, true);

      final patternSkins = PaddleSkinCatalog.allSkins.where((s) => s.type == SkinType.pattern).toList();
      expect(patternSkins.isNotEmpty, true);

      // Patterns cost more than solid colors
      for (final p in patternSkins) {
        expect(p.price, greaterThanOrEqualTo(500));
      }

      final verifiedSkin = PaddleSkinCatalog.byId('verified_legend');
      expect(verifiedSkin.isVerifiedOnly, true);
      expect(verifiedSkin.type, SkinType.exclusive);
    });

    test('Catalog byId returns default skin on unknown or null id', () {
      expect(PaddleSkinCatalog.byId(null).id, 'classic_cyan');
      expect(PaddleSkinCatalog.byId('unknown_nonexistent').id, 'classic_cyan');
      expect(PaddleSkinCatalog.byId('hazard_stripes').id, 'hazard_stripes');
    });
  });

  group('StorageService & Skin Shop Purchases', () {
    test('Default equipped skin is classic_cyan and owned skins include classic_cyan', () {
      expect(StorageService.instance.getEquippedSkin(), 'classic_cyan');
      expect(StorageService.instance.getOwnedSkins(), contains('classic_cyan'));
      expect(StorageService.instance.isSkinOwned('classic_cyan'), true);
      expect(StorageService.instance.isSkinOwned('hazard_stripes'), false);
    });

    test('Equipping and purchasing skins persists properly', () async {
      await StorageService.instance.saveCoins(1000);
      expect(StorageService.instance.getCoins(), 1000);

      final skinToBuy = PaddleSkinCatalog.byId('hazard_stripes');
      expect(skinToBuy.price, 500);

      // Purchase skin
      await StorageService.instance.addOwnedSkin(skinToBuy.id);
      await StorageService.instance.saveCoins(1000 - skinToBuy.price);
      await StorageService.instance.saveEquippedSkin(skinToBuy.id);

      expect(StorageService.instance.getCoins(), 500);
      expect(StorageService.instance.isSkinOwned('hazard_stripes'), true);
      expect(StorageService.instance.getEquippedSkin(), 'hazard_stripes');
    });
  });

  group('Verified Player Status & Admin Controls', () {
    test('Owner ImJustIvaan is always owner and verified', () {
      expect(UserUtils.isOwner('ImJustIvaan'), true);
      expect(UserUtils.isOwner('imjustivaan'), true);
      expect(UserUtils.isOwner('regularPlayer'), false);

      expect(UserUtils.isVerified('ImJustIvaan'), true);
      expect(UserUtils.isVerified('imjustivaan'), true);
    });

    test('Admin verifying another player makes them verified', () async {
      const testUser = 'championPongUser';
      expect(UserUtils.isVerified(testUser), false);

      final verifiedList = StorageService.instance.getLocalVerifiedUsers();
      verifiedList.add(testUser);
      await StorageService.instance.saveLocalVerifiedUsers(verifiedList);

      expect(StorageService.instance.isLocalVerified(testUser), true);
      expect(UserUtils.isVerified(testUser), true);

      // But non-owner does not have owner privileges
      expect(UserUtils.isOwner(testUser), false);
    });

    test('Admin granting a skin stores it for the receiver', () async {
      const testUser = 'luckyPlayer';
      expect(StorageService.instance.getLocalGrantedSkins(testUser), isEmpty);

      await StorageService.instance.saveLocalGrantedSkin(testUser, 'cosmic_stars');
      expect(StorageService.instance.getLocalGrantedSkins(testUser), contains('cosmic_stars'));
    });
  });
}
