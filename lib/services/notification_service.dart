import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static String? _fcmToken;
  
  static String? get fcmToken => _fcmToken;

  // Request notification permission
  static Future<bool> requestPermission() async {
    try {
      // Request Firebase messaging permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ Notification permission granted provisionally');
        return true;
      } else {
        debugPrint('❌ Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  // Check if permission was already requested
  static Future<bool> hasPermissionBeenRequested() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_permission_requested') ?? false;
  }

  // Mark permission as requested
  static Future<void> markPermissionAsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permission_requested', true);
  }

  // Initialize FCM and get token
  static Future<String?> initialize() async {
    try {
      // Get FCM token
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // On iOS, we need to wait for the APNs token to be available
        // This is a known requirement for reliability on some iOS versions
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('🍎 APNs Token: $apnsToken');
        } else {
          debugPrint('⚠️ APNs Token not available yet, FCM token might be delayed');
          // Wait a bit and try once more
          await Future.delayed(const Duration(seconds: 3));
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null) {
            debugPrint('🍎 APNs Token (after retry): $apnsToken');
          }
        }
      }

      _fcmToken = await _messaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 FCM Token refreshed: $newToken');
        // Update token in backend if user is logged in
        _updateTokenInBackend(newToken);
      });

      // Configure foreground message handling
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 RECEIVED FOREGROUND MESSAGE:');
        debugPrint('   Title: ${message.notification?.title}');
        debugPrint('   Body: ${message.notification?.body}');
        debugPrint('   Data: ${message.data}');
        // Handle foreground notification
        _handleForegroundMessage(message);
      });

      // Handle background messages (when app is terminated)
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle notification taps (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 NOTIFICATION OPENED APP:');
        debugPrint('   Title: ${message.notification?.title}');
        debugPrint('   Data: ${message.data}');
        _handleNotificationTap(message);
      });

      // Check if app was opened from notification
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 App opened from notification: ${initialMessage.notification?.title}');
        _handleNotificationTap(initialMessage);
      }

      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
      return null;
    }
  }

  // Update FCM token in backend
  static Future<void> updateTokenInBackend(String? token) async {
    if (token == null || token.isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');
      
      if (authToken == null) {
        debugPrint('⚠️ No auth token found, skipping FCM token update');
        return;
      }

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token updated in backend');
      } else {
        debugPrint('❌ Failed to update FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating FCM token in backend: $e');
    }
  }

  // Private method to update token
  static Future<void> _updateTokenInBackend(String token) async {
    await updateTokenInBackend(token);
  }

  // Clear FCM token from backend
  static Future<void> clearTokenFromBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');
      
      if (authToken == null) {
        debugPrint('⚠️ No auth token found, skipping FCM token clear');
        return;
      }

      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcmToken': null}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token cleared from backend');
      } else {
        debugPrint('❌ Failed to clear FCM token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error clearing FCM token from backend: $e');
    }
  }


  // Save notification locally
  static Future<void> _saveNotificationLocally(RemoteMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? notificationsString = prefs.getString('local_notifications');
      List<Map<String, dynamic>> notifications = [];
      
      if (notificationsString != null) {
        final List<dynamic> decodedList = jsonDecode(notificationsString);
        notifications = List<Map<String, dynamic>>.from(decodedList);
      }
      
      final newNotification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': message.notification?.title ?? 'New Notification',
        'body': message.notification?.body ?? '',
        'data': message.data,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
      };
      
      notifications.insert(0, newNotification);
      if (notifications.length > 50) {
        notifications.removeLast(); // Keep only last 50
      }
      
      await prefs.setString('local_notifications', jsonEncode(notifications));
      debugPrint('✅ Notification saved locally');
    } catch (e) {
      debugPrint('❌ Error saving notification locally: $e');
    }
  }

  // Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    // You can show a local notification or update UI here
    debugPrint('📨 Foreground notification: ${message.notification?.title}');
    debugPrint('📨 Body: ${message.notification?.body}');
    debugPrint('📨 Data: ${message.data}');
    _saveNotificationLocally(message);
  }

  // Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    // Navigate to appropriate screen based on notification data
    final data = message.data;
    debugPrint('🔔 Notification data: $data');
    
    // You can use a navigator key or event bus to navigate
    // This will be handled by the app's navigation system
  }

  // Delete FCM token (on logout)
  static Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      debugPrint('🗑️ FCM token deleted');
    } catch (e) {
      debugPrint('❌ Error deleting FCM token: $e');
    }
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 Background message received: ${message.notification?.title}');
  debugPrint('📨 Body: ${message.notification?.body}');
  debugPrint('📨 Data: ${message.data}');
  await NotificationService._saveNotificationLocally(message);
}

