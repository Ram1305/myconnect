import 'package:flutter/foundation.dart';
import '../utils/api_service.dart';

class NotificationProvider with ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  
  int get unreadCount => _notifications.where((n) => !(n['isRead'] ?? false)).length;

  NotificationProvider() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final notificationsList = await ApiService.getNotifications();
      _notifications = List<Map<String, dynamic>>.from(notificationsList);
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addNotification(Map<String, dynamic> notification) async {
    // Optimistically add to list
    final newNotification = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
      'title': notification['title'] ?? 'New Notification',
      'body': notification['body'] ?? '',
      'data': notification['data'] ?? {},
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    };
    
    _notifications.insert(0, newNotification);
    notifyListeners();
    
    // Refresh from server to get sync
    await _loadNotifications();
  }

  Future<void> markAsRead(String id) async {
    // Optimistic update
    final index = _notifications.indexWhere((n) => n['_id'] == id);
    if (index != -1) {
      _notifications[index]['isRead'] = true;
      notifyListeners();
      
      await ApiService.markNotificationRead(id);
    }
  }

  Future<void> markAllAsRead() async {
    for (var notification in _notifications) {
      notification['isRead'] = true;
    }
    notifyListeners();
    
    await ApiService.markAllNotificationsRead();
  }

  Future<void> clearAll() async {
    try {
      await ApiService.deleteAllNotifications();
      _notifications.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
      // Still clear locally even if API call fails
    _notifications.clear();
    notifyListeners();
    }
  }
  
  // Method to reload notifications (useful if updated from background service)
  Future<void> reloadNotifications() async {
    await _loadNotifications();
  }
}
