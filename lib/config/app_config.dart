import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // API Configuration - Production URL
  // Production: https://myconnect.onrender.com/api
  // For local development: http://192.168.29.61:1000/api
  // For Android Emulator: http://10.0.2.2:1000/api
  // For iOS Simulator: http://localhost:1000/api
  // For Web: Must use HTTPS to avoid mixed content errors
  static String get baseUrl {
    if (kIsWeb) {
      // Use HTTPS for web to avoid mixed content blocking
      return 'https://72.61.236.154:1000/api';
    }
    // Use HTTP for mobile platforms
    return 'http://72.61.236.154:1000/api';
  }
  static const int apiTimeout = 30;
  
  // Color Configuration (Historical Burgundy and Maroon color scheme)
  static const Color primaryColor = Color(0xFF800020); // Burgundy (Historical)
  static const Color secondaryColor = Color(0xFF800000); // Maroon
  static const Color backgroundColor = Color(0xFFF5F5F0); // Light cream/beige
  static const Color mutedGold = Color(0xFFA0522D); // Sienna (complementary)
  static const Color darkBackground = Color(0xFF2C1A1A); // Dark burgundy tint
  static const Color lightGold = Color(0xFFE8D5C9); // Light burgundy/cream

  // App Information
  static const String appName = 'My Connect';
  static const String appVersion = '1.0.0+3';

  // Admin Contact Information
  static const String adminContactPhone = '+91 9884559988';
  static const String adminContactEmail = 'admin@myconnect.com';

  // Get all colors as a map (useful for debugging)
  static Map<String, Color> get colors => {
    'primary': primaryColor,
    'secondary': secondaryColor,
    'background': backgroundColor,
    'mutedGold': mutedGold,
    'darkBackground': darkBackground,
    'lightGold': lightGold,
  };
}
