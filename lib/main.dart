// lib/main.dart
// ========================================================
// THÊM: Auto-update check khi mở app
// ========================================================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/api_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/call_service.dart';
import 'core/services/update_service.dart';
import 'core/constants/app_constants.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/chat/screens/create_room_screen.dart';
import 'features/chatbot/screens/chatbot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }

  ApiService().init();
  await ApiService().loadSession();

  try {
    await Get.putAsync(() => NotificationService().init());
  } catch (e) {
    debugPrint('NotificationService init skipped: $e');
  }
  Get.put(CallService());

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getString(AppConstants.keyToken) != null;

  runApp(NTGApp(isLoggedIn: isLoggedIn));
}

class NTGApp extends StatelessWidget {
  final bool isLoggedIn;
  const NTGApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // Check update sau khi app render xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isLoggedIn) {
        UpdateService.checkForUpdate();
      }
    });

    return GetMaterialApp(
      title: 'NTG',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: isLoggedIn ? '/home' : '/login',
      getPages: _routes(),
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(AppColors.primary),
        brightness: Brightness.light,
      ),
      primaryColor: const Color(AppColors.primary),
      scaffoldBackgroundColor: const Color(AppColors.bgSecondary),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(AppColors.primary),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppColors.primary),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: const Size(double.infinity, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(AppColors.primary), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      fontFamily: 'Roboto',
    );
  }

  List<GetPage> _routes() => [
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(name: '/home', page: () => const HomeScreen()),
        GetPage(name: '/chat/room/:id', page: () => const Placeholder()),
        GetPage(name: '/chat/new', page: () => const CreateRoomScreen()),
        GetPage(name: '/chatbot', page: () => const ChatbotScreen()),
        GetPage(name: '/tasks/:id', page: () => const Placeholder()),
      ];
}
