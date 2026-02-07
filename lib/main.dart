import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard.dart';
import 'screens/status_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/mylist_provider.dart';
import 'utils/theme.dart';
import 'config/app_config.dart';
import 'services/notification_service.dart';
import 'providers/notification_provider.dart';
import 'desktop/desktop_init.dart';

void main() async {
  // Catch async errors (like font loading) - must be in same zone as ensureInitialized
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize desktop window manager for Windows/macOS/Linux
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        await initDesktop();
        debugPrint('✅ Desktop window manager initialized');
      } catch (e) {
        debugPrint('⚠️ Desktop initialization error: $e');
      }
    }
    
    // Handle font loading errors gracefully (including async errors)
    FlutterError.onError = (FlutterErrorDetails details) {
      // Suppress Google Fonts loading errors (non-fatal)
      if (details.exception.toString().contains('google_fonts') ||
          details.exception.toString().contains('fonts.gstatic.com') ||
          details.exception.toString().contains('Failed to load font')) {
        debugPrint('⚠️ Font loading error (using system font fallback)');
        return; // Don't crash, just use system font
      }
      // Let other errors be handled normally
      FlutterError.presentError(details);
    };
    
    // Initialize Firebase (skip on Windows due to build issues)
    if (defaultTargetPlatform != TargetPlatform.windows) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized');
      } catch (e) {
        debugPrint('❌ Firebase initialization error: $e');
        // Continue even if Firebase fails to prevent white screen
      }
      
      // Initialize notification service (only on mobile platforms, not web)
      if (!kIsWeb) {
        try {
          await NotificationService.initialize();
          debugPrint('✅ Notification service initialized');
        } catch (e) {
          debugPrint('⚠️ Notification service initialization error: $e');
          // Continue even if notifications fail
        }
      } else {
        debugPrint('⚠️ Notification service skipped on web platform');
      }
    } else {
      debugPrint('⚠️ Firebase skipped on Windows platform');
    }
    
    // System UI overlay style (only for mobile platforms)
    if (defaultTargetPlatform != TargetPlatform.windows && 
        defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    }
    
    runApp(const MyApp());
  }, (error, stack) {
    // Handle async errors (like font loading failures)
    if (error.toString().contains('google_fonts') ||
        error.toString().contains('fonts.gstatic.com') ||
        error.toString().contains('Failed to load font')) {
      debugPrint('⚠️ Font loading error (using system font fallback)');
      return; // Don't crash, just use system font
    }
    // Let other errors be handled normally
    debugPrint('❌ Unhandled error: $error');
    debugPrint('Stack trace: $stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => MyListProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/dashboard': (context) => const Dashboard(),
          '/status': (context) => const StatusScreen(),
        },
      ),
    );
  }
}

