import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

/// Application Entrypoint for BackTap.
/// Configures system edge-to-edge UI overlay styling and boots the MaterialApp.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI navigation and status bar for a clean light theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFF8FAFC),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const BackTapApp());
}

/// Root widget configuring Material 3 light theme with soft slate canvas,
/// pure white surfaces, and rich blue/violet accents.
class BackTapApp extends StatelessWidget {
  const BackTapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BackTap',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          secondary: Color(0xFF4F46E5),
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
