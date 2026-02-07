import 'package:flutter/foundation.dart';
import '../utils/api_service.dart';

class UserProvider with ChangeNotifier {
  List<dynamic> _approvedUsers = [];
  final List<dynamic> _selectedUsers = [];
  bool _isLoading = false;

  List<dynamic> get approvedUsers => _approvedUsers;
  List<dynamic> get selectedUsers => _selectedUsers;
  bool get isLoading => _isLoading;
  bool get hasSelection => _selectedUsers.isNotEmpty;

  Future<void> fetchApprovedUsers({String? search, double? latitude, double? longitude}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _approvedUsers = await ApiService.getApprovedUsers(
        search: search,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  void toggleUserSelection(String userId) {
    if (_selectedUsers.contains(userId)) {
      _selectedUsers.remove(userId);
    } else {
      _selectedUsers.add(userId);
    }
    notifyListeners();
  }

  void clearSelection() {
    _selectedUsers.clear();
    notifyListeners();
  }

  Future<Map<String, dynamic>> getUserById(String id) async {
    try {
      return await ApiService.getUserById(id);
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  Future<bool> updateUser(
    String userId,
    Map<String, dynamic> data,
    String? profilePhotoPath,
    {String? spousePhotoPath, String? familyPhotoPath, List<String>? kidPhotoPaths}
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await ApiService.updateProfileAdmin(
        userId, 
        data, 
        profilePhotoPath,
        spousePhotoPath: spousePhotoPath,
        familyPhotoPath: familyPhotoPath,
        kidPhotoPaths: kidPhotoPaths
      );
      
      _isLoading = false;
      notifyListeners();
      
      if (result['error'] != null) {
        return false;
      }
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}

