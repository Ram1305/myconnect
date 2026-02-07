import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/api_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _lastError;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get lastError => _lastError;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      await getCurrentUser();
    }
    notifyListeners();
  }

  Future<bool> signup(Map<String, dynamic> data, String? imagePath) async {
    debugPrint('🟡 [AUTH] Starting signup in AuthProvider...');
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      debugPrint('🟡 [AUTH] Calling ApiService.signup...');
      final response = await ApiService.signup(data, imagePath);
      debugPrint('🟡 [AUTH] Response received: $response');
      
      // Check if signup was successful (must have user data in response)
      // Backend returns user data on success, or just an error message on failure
      if (response['user'] != null) {
        debugPrint('✅ [AUTH] Signup successful');
        
        // Store user info (but no token - user needs to login after approval)
        _user = response['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _user!['id']);
        await prefs.setString('status', _user!['status']);
        debugPrint('✅ [AUTH] User data saved (status: ${_user!['status']})');
        
        _isLoading = false;
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        // Signup failed - there's an error
        debugPrint('❌ [AUTH] Signup failed. Response: $response');
        _lastError = response['error'] ?? response['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [AUTH] Exception during signup: $e');
      debugPrint('❌ [AUTH] Stack trace: $stackTrace');
      _lastError = 'Network error. Please check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String mobileNumber, String password) async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await ApiService.login(mobileNumber, password);
      
      if (response['token'] != null) {
        _token = response['token'];
        _user = response['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('userId', _user!['id']);
        await prefs.setString('status', _user!['status']);
        await prefs.setBool('isAdmin', _user!['isAdmin'] ?? false);
        if (_user!['role'] != null) {
          await prefs.setString('role', _user!['role'].toString());
        }
        
        // Update FCM token in backend after login
        final fcmToken = NotificationService.fcmToken;
        if (fcmToken != null) {
          await NotificationService.updateTokenInBackend(fcmToken);
        }
        
        _isLoading = false;
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        _lastError = response['message'] ?? response['error'] ?? 'Invalid credentials';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Network error. Please check your connection.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> getCurrentUser() async {
    try {
      final user = await ApiService.getCurrentUser();
      if (user['_id'] != null) {
        _user = user;
        
        // Update SharedPreferences with admin status and role if available
        final prefs = await SharedPreferences.getInstance();
        if (user['isAdmin'] != null) {
          await prefs.setBool('isAdmin', user['isAdmin'] ?? false);
        }
        if (user['role'] != null) {
          await prefs.setString('role', user['role'].toString());
        }
        
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<bool> updateProfile(
    Map<String, dynamic> data, 
    String? profilePhotoPath, {
    String? spousePhotoPath,
    String? familyPhotoPath,
    List<String>? kidPhotoPaths,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.updateProfile(
        data,
        profilePhotoPath,
        spousePhotoPath: spousePhotoPath,
        familyPhotoPath: familyPhotoPath,
        kidPhotoPaths: kidPhotoPaths,
      );
      
      if (response['error'] == null && response['user'] != null) {
        // Update user data with the response
        _user = response['user'];
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ [AUTH] Profile update error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // Clear token from backend
    try {
      final response = await ApiService.logout();
      
      // Check if logout failed due to token mismatch
      if (response['error'] == 'TOKEN_MISMATCH' || 
          (response['message'] != null && response['message'].toString().contains('Token mismatch'))) {
        _lastError = 'Token mismatch. Please ask your administrator to allow login.';
        notifyListeners();
        return; // Don't clear local storage if logout failed
      }
    } catch (e) {
      debugPrint('⚠️ [AUTH] Backend logout error: $e');
      // Check if error message contains token mismatch
      if (e.toString().contains('Token mismatch') || e.toString().contains('TOKEN_MISMATCH')) {
        _lastError = 'Token mismatch. Please ask your administrator to allow login.';
        notifyListeners();
        return;
      }
    }
    
    // Clear FCM token from backend before logout
    await NotificationService.clearTokenFromBackend();
    await NotificationService.deleteToken();
    
    _token = null;
    _user = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('status');
    await prefs.remove('isAdmin');
    await prefs.remove('role');
    
    notifyListeners();
  }

  String? getStatus() {
    return _user?['status'];
  }

  String? get role => _user?['role']?.toString();

  bool isAdmin() {
    return _user?['isAdmin'] ?? false;
  }

  bool isSuperAdmin() {
    return role == 'super-admin';
  }
}

