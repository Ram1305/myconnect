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
// 🔴 Primary: Icon Red (Main brand color)
  static const Color primaryColor = Color(0xFFE41E26);
// Bright, confident red used in the icon

// 🔵 Secondary: Navy Blue from icon symbol
  static const Color secondaryColor = Color(0xFF0D1B4C);
// Deep navy for buttons, icons, highlights

// ⚪ Background: Clean white with slight warmth
  static const Color backgroundColor = Color(0xFFF9FAFC);
// Keeps UI clean and professional

// 🔴 Accent / Muted Red (for warnings, chips, borders)
  static const Color mutedGold = Color(0xFFB1121A);
// Darker red tone instead of gold (fits icon better)

// 🌑 Dark Background (for dark mode / headers)
  static const Color darkBackground = Color(0xFF121212);
// Modern dark UI base

// 🔵 Light Secondary (cards, containers, selection)
  static const Color lightGold = Color(0xFFE8ECF9);
// Soft navy tint for subtle UI depth

  // App Information
  static const String appName = 'My_Connect';
  static const String appVersion = '1.0.0+1';

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
