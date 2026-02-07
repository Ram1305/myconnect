import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  static String get baseUrl => AppConfig.baseUrl;

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> getHeaders({bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Auth APIs
  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data, String? imagePath) async {
    try {
      debugPrint('🟢 [API] Starting signup request...');
      debugPrint('🟢 [API] Base URL: $baseUrl');
      final uri = Uri.parse('$baseUrl/auth/signup');
      debugPrint('🟢 [API] Signup URL: $uri');
      var request = http.MultipartRequest('POST', uri);

      // Add fields
      debugPrint('🟢 [API] Adding form fields...');
      data.forEach((key, value) {
        if (value is Map || value is List) {
          final jsonValue = jsonEncode(value);
          request.fields[key] = jsonValue;
          debugPrint('   $key: $jsonValue');
        } else {
          request.fields[key] = value.toString();
          debugPrint('   $key: ${value.toString()}');
        }
      });

      // Add image if provided
      if (imagePath != null && imagePath.isNotEmpty) {
        debugPrint('🟢 [API] Adding profile photo: $imagePath');
        // Determine MIME type from file extension
        final extension = imagePath.toLowerCase().split('.').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'profilePhoto',
            imagePath,
            filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.$extension',
            contentType: http.MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
          ),
        );
      } else {
        debugPrint('🟡 [API] No profile photo provided');
      }

      final headers = await getHeaders(includeAuth: false);
      request.headers.addAll(headers);
      debugPrint('🟢 [API] Headers: $headers');

      debugPrint('🟢 [API] Sending request...');
      final streamedResponse = await request.send();
      debugPrint('🟢 [API] Response status: ${streamedResponse.statusCode}');
      
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('🟢 [API] Response body: ${response.body}');

      // Check if response is JSON
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        final decodedResponse = jsonDecode(response.body);
        debugPrint('🟢 [API] Decoded response: $decodedResponse');
        return decodedResponse;
      } else {
        // Handle non-JSON error responses (like HTML error pages)
        debugPrint('❌ [API] Non-JSON response received');
        return {
          'error': 'Server error: ${response.statusCode}',
          'message': response.body.length > 200 
              ? response.body.substring(0, 200) 
              : response.body,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [API] Signup error: $e');
      debugPrint('❌ [API] Stack trace: $stackTrace');
      return {'error': e.toString()};
    }
  }

  static Future<Map<String,dynamic>> login(String mobileNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: await getHeaders(includeAuth: false),
        body: jsonEncode({
          'mobileNumber': mobileNumber,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      
      // If response is not successful, return error
      if (response.statusCode != 200) {
        return {
          'error': data['message'] ?? 'Login failed',
          'message': data['message'] ?? 'Invalid credentials'
        };
      }
      
      return data;
    } catch (e) {
      return {'error': e.toString(), 'message': 'Network error. Please check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data, 
    String? profilePhotoPath,
    {String? spousePhotoPath, String? familyPhotoPath, List<String>? kidPhotoPaths}
  ) async {
    return _updateProfileInternal(
      '$baseUrl/auth/profile', 
      data, 
      profilePhotoPath, 
      spousePhotoPath: spousePhotoPath, 
      familyPhotoPath: familyPhotoPath, 
      kidPhotoPaths: kidPhotoPaths
    );
  }

  static Future<Map<String, dynamic>> updateProfileAdmin(
    String userId,
    Map<String, dynamic> data, 
    String? profilePhotoPath,
    {String? spousePhotoPath, String? familyPhotoPath, List<String>? kidPhotoPaths}
  ) async {
    return _updateProfileInternal(
      '$baseUrl/admin/users/$userId', 
      data, 
      profilePhotoPath, 
      spousePhotoPath: spousePhotoPath, 
      familyPhotoPath: familyPhotoPath, 
      kidPhotoPaths: kidPhotoPaths
    );
  }

  static Future<Map<String, dynamic>> _updateProfileInternal(
    String apiUrl,
    Map<String, dynamic> data, 
    String? profilePhotoPath,
    {String? spousePhotoPath, String? familyPhotoPath, List<String>? kidPhotoPaths}
  ) async {
    try {
      debugPrint('🟢 [API] Starting profile update request...');
      final uri = Uri.parse(apiUrl);
      debugPrint('🟢 [API] Update profile URL: $uri');
      var request = http.MultipartRequest('PUT', uri);

      // Add fields
      debugPrint('🟢 [API] Adding form fields...');
      data.forEach((key, value) {
        if (value == null) return; // Skip null values
        if (value is Map || value is List) {
          final jsonValue = jsonEncode(value);
          request.fields[key] = jsonValue;
          debugPrint('   $key: $jsonValue');
        } else {
          request.fields[key] = value.toString();
          debugPrint('   $key: ${value.toString()}');
        }
      });

      // Add profile photo if provided
      if (profilePhotoPath != null && profilePhotoPath.isNotEmpty) {
        debugPrint('🟢 [API] Adding profile photo: $profilePhotoPath');
        final extension = profilePhotoPath.toLowerCase().split('.').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'profilePhoto',
            profilePhotoPath,
            filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.$extension',
            contentType: http.MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
          ),
        );
      }

      // Add spouse photo if provided
      if (spousePhotoPath != null && spousePhotoPath.isNotEmpty) {
        debugPrint('🟢 [API] Adding spouse photo: $spousePhotoPath');
        final extension = spousePhotoPath.toLowerCase().split('.').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'spousePhoto',
            spousePhotoPath,
            filename: 'spouse_${DateTime.now().millisecondsSinceEpoch}.$extension',
            contentType: http.MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
          ),
        );
      }

      // Add family photo if provided
      if (familyPhotoPath != null && familyPhotoPath.isNotEmpty) {
        debugPrint('🟢 [API] Adding family photo: $familyPhotoPath');
        final extension = familyPhotoPath.toLowerCase().split('.').last;
        request.files.add(
          await http.MultipartFile.fromPath(
            'familyPhoto',
            familyPhotoPath,
            filename: 'family_${DateTime.now().millisecondsSinceEpoch}.$extension',
            contentType: http.MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
          ),
        );
      }

      // Add kid photos if provided
      if (kidPhotoPaths != null && kidPhotoPaths.isNotEmpty) {
        debugPrint('🟢 [API] Adding ${kidPhotoPaths.length} kid photo(s)');
        for (int i = 0; i < kidPhotoPaths.length; i++) {
          final kidPhotoPath = kidPhotoPaths[i];
          if (kidPhotoPath.isNotEmpty) {
            final extension = kidPhotoPath.toLowerCase().split('.').last;
            request.files.add(
              await http.MultipartFile.fromPath(
                'kidPhotos',
                kidPhotoPath,
                filename: 'kid_${i}_${DateTime.now().millisecondsSinceEpoch}.$extension',
                contentType: http.MediaType('image', extension == 'jpg' ? 'jpeg' : extension),
              ),
            );
          }
        }
      }

      final headers = await getHeaders();
      request.headers.addAll(headers);
      debugPrint('🟢 [API] Headers: $headers');

      debugPrint('🟢 [API] Sending request...');
      final streamedResponse = await request.send();
      debugPrint('🟢 [API] Response status: ${streamedResponse.statusCode}');
      
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('🟢 [API] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final decodedResponse = jsonDecode(response.body);
        debugPrint('🟢 [API] Profile updated successfully');
        return decodedResponse;
      } else {
        debugPrint('❌ [API] Profile update failed: ${response.statusCode}');
        final decodedResponse = jsonDecode(response.body);
        return {'error': decodedResponse['message'] ?? 'Update failed', 'statusCode': response.statusCode};
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [API] Profile update error: $e');
      debugPrint('❌ [API] Stack trace: $stackTrace');
      return {'error': e.toString()};
    }
  }

  // User APIs
  static Future<List<dynamic>> getApprovedUsers({String? search, double? latitude, double? longitude}) async {
    try {
      final uri = Uri.parse('$baseUrl/users/approved').replace(queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (latitude != null && longitude != null) ...{
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
        },
      });

      final response = await http.get(
        uri,
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getUserById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$id'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Admin APIs
  static Future<List<dynamic>> getPendingUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/pending'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getApprovedUsersAdmin() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/approved'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getRejectedUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/rejected'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> approveUser(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/approve/$id'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> rejectUser(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/reject/$id'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Chat APIs
  static Future<List<dynamic>> getChats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getOrCreateChat(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/with/$userId'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> sendMessage(String chatId, String message) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$chatId/message'),
        headers: await getHeaders(),
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {'error': data['message'] ?? 'Failed to send message'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getChatMessages(String chatId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$chatId/messages'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Admin: Get chat messages (no participant check required)
  static Future<Map<String, dynamic>> getAdminChatMessages(String chatId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/chat/$chatId/messages'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {'error': data['message'] ?? 'Failed to load chat messages'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Admin: Delete a single chat
  static Future<Map<String, dynamic>> deleteChat(String chatId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/chat/$chatId'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Admin: Delete multiple chats
  static Future<Map<String, dynamic>> deleteChats(List<String> chatIds) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/chats'),
        headers: await getHeaders(),
        body: jsonEncode({'chatIds': chatIds}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Get or create public My Connect chat
  static Future<Map<String, dynamic>> getOrCreatePublicChat() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/public'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // My List APIs
  static Future<Map<String, dynamic>> getMyList({double? latitude, double? longitude}) async {
    try {
      String url = '$baseUrl/mylist';
      if (latitude != null && longitude != null) {
        url += '?latitude=$latitude&longitude=$longitude';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addToMyList(List<String> memberIds) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/mylist/add'),
        headers: await getHeaders(),
        body: jsonEncode({'memberIds': memberIds}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> toggleMemberStatus(String memberId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/mylist/toggle/$memberId'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> removeFromMyList(String memberId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/mylist/remove/$memberId'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  // Notification APIs
  static Future<List<dynamic>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$id/read'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/read-all'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAllNotifications() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Forgot Password APIs
  static Future<Map<String, dynamic>> requestPasswordResetOTP(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/request-otp'),
        headers: await getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode != 200) {
        return {
          'error': data['message'] ?? 'Failed to send OTP',
          'message': data['message'] ?? 'Failed to send OTP'
        };
      }
      
      return data;
    } catch (e) {
      return {'error': e.toString(), 'message': 'Network error. Please check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> verifyPasswordResetOTP(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/verify-otp'),
        headers: await getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode != 200) {
        return {
          'error': data['message'] ?? 'OTP verification failed',
          'message': data['message'] ?? 'Invalid OTP',
          'verified': false
        };
      }
      
      return data;
    } catch (e) {
      return {'error': e.toString(), 'message': 'Network error. Please check your connection.', 'verified': false};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/forgot-password/reset'),
        headers: await getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode != 200) {
        return {
          'error': data['message'] ?? 'Password reset failed',
          'message': data['message'] ?? 'Failed to reset password'
        };
      }
      
      return data;
    } catch (e) {
      return {'error': e.toString(), 'message': 'Network error. Please check your connection.'};
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {
          'error': data['error'] ?? data['message'] ?? 'Logout failed',
          'message': data['message'] ?? 'Logout failed'
        };
      }
    } catch (e) {
      return {'error': e.toString(), 'message': 'Network error during logout'};
    }
  }

  // Delete account
  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/auth/delete-account'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {
          'error': data['error'] ?? data['message'] ?? 'Failed to delete account',
          'message': data['message'] ?? 'Failed to delete account'
        };
      }
    } catch (e) {
      return {'error': e.toString(), 'message': 'Network error during account deletion'};
    }
  }

  // Get users who cannot login
  static Future<List<dynamic>> getCannotLoginUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/cannot-login'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  // Allow user to login
  static Future<Map<String, dynamic>> allowUserLogin(String id) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/allow-login/$id'),
        headers: await getHeaders(),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Super-admin: list all admins (with related user count)
  static Future<List<dynamic>> getAdmins() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/admins'),
        headers: await getHeaders(),
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  // Super-admin: get users related to an admin (createdByAdmin = adminId)
  static Future<List<dynamic>> getAdminRelatedUsers(String adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/admins/$adminId/related'),
        headers: await getHeaders(),
      );
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  // Super-admin: assign a user to an admin (set createdByAdmin)
  static Future<Map<String, dynamic>> assignUserToAdmin(String userId, String adminId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/admin/users/$userId/assign-admin'),
        headers: await getHeaders(),
        body: jsonEncode({'adminId': adminId}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Delete event (admin only)
  static Future<Map<String, dynamic>> deleteEvent(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/events/$id'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {'error': data['message'] ?? 'Failed to delete event'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Delete blog (admin only)
  static Future<Map<String, dynamic>> deleteBlog(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/blogs/$id'),
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final data = jsonDecode(response.body);
        return {'error': data['message'] ?? 'Failed to delete blog'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Get all events (for admin)
  static Future<List<dynamic>> getAllEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

  // Get all blogs (for admin)
  static Future<List<dynamic>> getAllBlogs() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/blogs'),
        headers: await getHeaders(),
      );

      final data = jsonDecode(response.body);
      return data is List ? data : [];
    } catch (e) {
      return [];
    }
  }

}

