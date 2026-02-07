import 'package:flutter/foundation.dart';
import '../utils/api_service.dart';

class MyListProvider with ChangeNotifier {
  Map<String, dynamic>? _myList;
  bool _isLoading = false;

  Map<String, dynamic>? get myList => _myList;
  bool get isLoading => _isLoading;
  List<dynamic> get members => _myList?['members'] ?? [];

  Future<void> fetchMyList({double? latitude, double? longitude}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _myList = await ApiService.getMyList(latitude: latitude, longitude: longitude);
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addToMyList(List<String> memberIds) async {
    _isLoading = true;
    notifyListeners();

    try {
      _myList = await ApiService.addToMyList(memberIds);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleMemberStatus(String memberId) async {
    try {
      _myList = await ApiService.toggleMemberStatus(memberId);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }

  Future<bool> removeFromMyList(String memberId) async {
    try {
      await ApiService.removeFromMyList(memberId);
      await fetchMyList();
      return true;
    } catch (e) {
      return false;
    }
  }
}

