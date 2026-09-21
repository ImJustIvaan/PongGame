import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_menu_screen.dart';
import 'services/fullscreen_service.dart';
import 'services/storage_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  try {
    await FullscreenService.instance.init();
  } catch (e) {
    debugPrint('Fullscreen init error: $e');
  }

  if (!kIsWeb) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {}
  }

  try {
    await StorageService.instance.init();
  } catch (e) {
    debugPrint('Storage init fallback: $e');
  }

  try {
    await SupabaseService.instance.initialize();
  } catch (e) {
    debugPrint('Supabase init fallback: $e');
  }

  runApp(const PongApp());
}

class PongApp extends StatelessWidget {
  const PongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: StorageService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'The Pong Game!',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData.light(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            textTheme: GoogleFonts.robotoTextTheme(ThemeData.light().textTheme),
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            scaffoldBackgroundColor: const Color(0xFF090A15),
            textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
          ),
          home: const MainMenuScreen(),
        );
      },
    );
  }
}
