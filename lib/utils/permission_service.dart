import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

class PermissionService {
  /// Request location permission and return true if granted
  static Future<bool> requestLocationPermission(BuildContext? context) async {
    // On Windows/macOS/Linux, permissions work differently - return true for desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return true; // Desktop platforms don't require runtime permissions
    }
    
    // Check global location service status first
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null && context.mounted) {
          final shouldOpen = await _showPermissionDialog(
            context,
            'Location Services Disabled',
            'Location services are disabled on your device. Please enable them in settings to use this feature.',
            showOpenSettings: true,
          );
          if (shouldOpen) {
            // On iOS, this should take them to the Privacy > Location Services page
            // On Android, it takes them to app settings, they might need to go to location too
            await openAppSettings();
          }
        }
        return false;
      }
    }

    // Check current permission status
    PermissionStatus status = await Permission.locationWhenInUse.status;
    
    // If already granted, return true immediately
    if (status.isGranted) {
      return true;
    }
    
    // Request permission
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
      if (status.isGranted) {
        return true;
      }
    }

    // If still denied, restricted or permanently denied
    if (!status.isGranted) {
      if (context != null && context.mounted) {
        String platformMessage;
        if (status.isRestricted) {
          platformMessage = 'Location access is restricted on this device (possibly due to parental controls).';
        } else {
          platformMessage = Platform.isIOS
              ? 'Location permission is required to show your position and find nearby people. Please enable it in Settings > My Connect > Location.'
              : 'Location permission is required. Please enable it in app settings.';
        }
        
        final shouldOpen = await _showPermissionDialog(
          context,
          'Location Permission Required',
          platformMessage,
          showOpenSettings: true,
        );
        if (shouldOpen) {
          await openAppSettings();
        }
      }
      return false;
    }

    return status.isGranted;
  }

  /// Request camera permission and return true if granted
  static Future<bool> requestCameraPermission(BuildContext? context) async {
    // On Windows/macOS/Linux, permissions work differently - return true for desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return true; // Desktop platforms handle permissions through system dialogs
    }
    
    PermissionStatus status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      status = await Permission.camera.request();
      if (status.isGranted) {
        return true;
      }
    }

    if (status.isPermanentlyDenied) {
      if (context != null && context.mounted) {
        final platformMessage = Platform.isIOS
            ? 'Camera permission is required to take photos. Please enable it in Settings > Privacy & Security > Camera.'
            : 'Camera permission is required to take photos. Please enable it in app settings.';
        
        final shouldOpen = await _showPermissionDialog(
          context,
          'Camera Permission Required',
          platformMessage,
          showOpenSettings: true,
        );
        if (shouldOpen) {
          await openAppSettings();
        }
      }
      return false;
    }

    return false;
  }

  /// Request storage/photos permission and return true if granted
  static Future<bool> requestStoragePermission(BuildContext? context) async {
    // On Windows/macOS/Linux, permissions work differently - return true for desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return true; // Desktop platforms handle file access through system dialogs
    }
    
    Permission permission;
    PermissionStatus status;
    
    // iOS: Use photos permission (NSPhotoLibraryUsageDescription)
    if (Platform.isIOS) {
      permission = Permission.photos;
      status = await permission.status;
    }
    // Android: Use photos permission for Android 13+ (API 33+), storage for older versions
    else if (Platform.isAndroid) {
      // For Android 13+ (API 33+), use photos permission
      // For older Android versions, use storage permission
      permission = Permission.photos;
      status = await permission.status;
      
      // Check if photos permission is available on this platform
      // If not available or restricted, try storage permission for older Android
      if (status.isRestricted || status.isPermanentlyDenied) {
        try {
          final storageStatus = await Permission.storage.status;
          if (!storageStatus.isPermanentlyDenied) {
            permission = Permission.storage;
            status = storageStatus;
          }
        } catch (e) {
          // Continue with photos permission
        }
      }
    } else {
      // Fallback for other platforms
      permission = Permission.photos;
      status = await permission.status;
    }
    
    if (status.isGranted) {
      return true;
    }

    // Request permission if denied
    if (status.isDenied) {
      status = await permission.request();
      if (status.isGranted) {
        return true;
      }
      
      // If still denied after request, return false
      if (status.isDenied) {
        return false;
      }
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      if (context != null && context.mounted) {
        final platformMessage = Platform.isIOS
            ? 'Photo library access is required to select photos. Please enable it in Settings > Privacy & Security > Photos.'
            : 'Storage permission is required to access photos. Please enable it in app settings.';
        
        final shouldOpen = await _showPermissionDialog(
          context,
          Platform.isIOS ? 'Photos Permission Required' : 'Storage Permission Required',
          platformMessage,
          showOpenSettings: true,
        );
        if (shouldOpen) {
          await openAppSettings();
        }
      }
      return false;
    }

    return false;
  }

  /// Request phone permission and return true if granted
  static Future<bool> requestPhonePermission(BuildContext? context) async {
    // On Windows/macOS/Linux, phone permission is not applicable
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      return true; // Desktop platforms don't have phone functionality
    }
    
    // iOS: Phone permission may not be needed for basic functionality
    // iOS handles phone calls through system dialogs
    if (Platform.isIOS) {
      // On iOS, phone calls are typically handled through URL schemes
      // which don't require explicit permission
      return true;
    }
    
    // Android: Requires explicit phone permission
    if (Platform.isAndroid) {
      PermissionStatus status = await Permission.phone.status;
      
      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        status = await Permission.phone.request();
        if (status.isGranted) {
          return true;
        }
      }

      if (status.isPermanentlyDenied) {
        if (context != null && context.mounted) {
          final shouldOpen = await _showPermissionDialog(
            context,
            'Phone Permission Required',
            'Phone permission is required to make calls. Please enable it in app settings.',
            showOpenSettings: true,
          );
          if (shouldOpen) {
            await openAppSettings();
          }
        }
        return false;
      }
    }

    return false;
  }

  /// Show permission dialog with option to open settings
  static Future<bool> _showPermissionDialog(
    BuildContext context,
    String title,
    String message, {
    bool showOpenSettings = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          if (showOpenSettings)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Helper method to pick an image with proper iOS/Android permission handling.
  /// Request permission first so the system dialog shows with correct usage descriptions.
  /// Returns the picked File or null if cancelled/denied.
  static Future<File?> pickImageWithPermission({
    required BuildContext context,
    required ImageSource source,
  }) async {
    // Request permission before opening picker on both iOS and Android so the system
    // permission dialog is shown properly (requires Info.plist keys on iOS and
    // uses-permission in AndroidManifest on Android).
    if (Platform.isAndroid || Platform.isIOS) {
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        hasPermission = await requestCameraPermission(context);
      } else {
        hasPermission = await requestStoragePermission(context);
      }
      
      if (!hasPermission) {
        return null;
      }
    }

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      // Handle permission denied errors gracefully
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || 
          errorString.contains('denied') ||
          errorString.contains('access')) {
        if (context.mounted) {
          final errorMessage = source == ImageSource.camera
              ? 'Camera permission was denied. Please allow camera access in Settings.'
              : 'Photo library access was denied. Please allow access in Settings.';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error picking image: ${e.toString()}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      return null;
    }
  }
}

