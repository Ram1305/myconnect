import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class SocketService {
  static IO.Socket? _socket;
  static bool _isConnected = false;

  static IO.Socket? get socket => _socket;

  static Future<void> connect() async {
    if (_socket != null && _isConnected) {
      return; // Already connected
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        return;
      }

      // Extract base URL without /api
      final baseUrl = AppConfig.baseUrl.replaceAll('/api', '');
      
      _socket = IO.io(
        baseUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('Socket connected');
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('Socket disconnected');
      });

      _socket!.onError((error) {
        debugPrint('Socket error: $error');
        _isConnected = false;
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('Error connecting socket: $e');
      _isConnected = false;
    }
  }

  static void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }

  static void joinChat(String chatId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('join_chat', chatId);
    }
  }

  static void leaveChat(String chatId) {
    if (_socket != null && _isConnected) {
      _socket!.emit('leave_chat', chatId);
    }
  }

  static void onMessage(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.on('new_message', (data) {
        if (data is Map<String, dynamic>) {
          callback(data);
        }
      });
    }
  }

  static void onChatUpdate(Function(Map<String, dynamic>) callback) {
    if (_socket != null) {
      _socket!.on('chat_updated', (data) {
        if (data is Map<String, dynamic>) {
          callback(data);
        }
      });
    }
  }

  static void offMessage() {
    if (_socket != null) {
      _socket!.off('new_message');
    }
  }

  static void offChatUpdate() {
    if (_socket != null) {
      _socket!.off('chat_updated');
    }
  }
}

