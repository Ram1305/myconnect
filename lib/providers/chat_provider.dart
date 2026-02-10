import 'package:flutter/foundation.dart';
import '../utils/api_service.dart';
import '../services/socket_service.dart';

class ChatProvider with ChangeNotifier {
  List<dynamic> _chats = [];
  Map<String, dynamic>? _currentChat;
  Map<String, dynamic>? _publicChat; // My Connect public chat
  bool _isLoading = false;
  String? _currentChatId;

  List<dynamic> get chats => _chats;
  Map<String, dynamic>? get currentChat => _currentChat;
  Map<String, dynamic>? get publicChat => _publicChat;
  bool get isLoading => _isLoading;

  ChatProvider() {
    _initializeSocket();
  }

  void _initializeSocket() {
    SocketService.connect();
    
    // Listen for new messages
    SocketService.onMessage((messageData) {
      final chatId = messageData['chatId'];
      if (chatId == _currentChatId) {
        // Add message to current chat
        if (_currentChat != null) {
          final messages = _currentChat!['messages'] as List? ?? [];
          messages.add(messageData['message']);
          _currentChat!['messages'] = messages;
          _currentChat!['lastMessage'] = messageData['message']['message'];
          _currentChat!['lastMessageTime'] = messageData['message']['createdAt'];
          notifyListeners();
        }
      }
      
      // Immediately update chat list without waiting for full fetch
      _updateChatListOnNewMessage(chatId, messageData['message']);
    });

    // Listen for chat updates
    SocketService.onChatUpdate((chatData) {
      final chatId = chatData['chatId'];
      final lastMessage = chatData['lastMessage'];
      final lastMessageTime = chatData['lastMessageTime'];
      
      // Immediately update chat list
      _updateChatListOnChatUpdate(chatId, lastMessage, lastMessageTime);
    });
  }
  
  void _updateChatListOnNewMessage(String chatId, Map<String, dynamic> message) {
    // Find the chat in the list and update it immediately
    bool chatFound = false;
    for (var i = 0; i < _chats.length; i++) {
      if (_chats[i]['_id']?.toString() == chatId || 
          _chats[i]['id']?.toString() == chatId) {
        _chats[i]['lastMessage'] = message['message']?.toString() ?? '';
        _chats[i]['lastMessageTime'] = message['createdAt']?.toString() ?? message['timestamp']?.toString() ?? '';
        chatFound = true;
        break;
      }
    }
    
    // If chat not found in list, it might be a new chat - fetch to get it
    if (!chatFound) {
      fetchChats();
    } else {
      // Sort by lastMessageTime (most recent first)
      _chats.sort((a, b) {
        final timeA = a['lastMessageTime'] != null 
            ? DateTime.parse(a['lastMessageTime'].toString()).millisecondsSinceEpoch 
            : 0;
        final timeB = b['lastMessageTime'] != null 
            ? DateTime.parse(b['lastMessageTime'].toString()).millisecondsSinceEpoch 
            : 0;
        return timeB.compareTo(timeA);
      });
      notifyListeners();
    }
  }
  
  void _updateChatListOnChatUpdate(String chatId, String? lastMessage, String? lastMessageTime) {
    // Find the chat in the list and update it immediately
    bool chatFound = false;
    for (var i = 0; i < _chats.length; i++) {
      if (_chats[i]['_id']?.toString() == chatId || 
          _chats[i]['id']?.toString() == chatId) {
        if (lastMessage != null) {
          _chats[i]['lastMessage'] = lastMessage;
        }
        if (lastMessageTime != null) {
          _chats[i]['lastMessageTime'] = lastMessageTime;
        }
        chatFound = true;
        break;
      }
    }
    
    // Also check public chat
    if (_publicChat != null) {
      final publicChatId = _publicChat!['_id']?.toString() ?? _publicChat!['id']?.toString();
      if (publicChatId == chatId) {
        if (lastMessage != null) {
          _publicChat!['lastMessage'] = lastMessage;
        }
        if (lastMessageTime != null) {
          _publicChat!['lastMessageTime'] = lastMessageTime;
        }
        chatFound = true;
      }
    }
    
    // If chat not found in list, it might be a new chat - fetch to get it
    if (!chatFound) {
      fetchChats();
    } else {
      // Sort by lastMessageTime (most recent first)
      _chats.sort((a, b) {
        final timeA = a['lastMessageTime'] != null 
            ? DateTime.parse(a['lastMessageTime'].toString()).millisecondsSinceEpoch 
            : 0;
        final timeB = b['lastMessageTime'] != null 
            ? DateTime.parse(b['lastMessageTime'].toString()).millisecondsSinceEpoch 
            : 0;
        return timeB.compareTo(timeA);
      });
      notifyListeners();
    }
  }

  Future<void> fetchChats() async {
    _isLoading = true;
    notifyListeners();

    try {
      final allChats = await ApiService.getChats();
      
      // Filter: Only show chats with messages (excluding public chats)
      _chats = allChats.where((chat) {
        final isPublic = chat['isPublic'] == true;
        final hasMessages = (chat['messages'] as List?)?.isNotEmpty ?? false;
        // Exclude public chats from regular list, only include chats with messages
        return !isPublic && hasMessages;
      }).toList();
      
      // Sort by lastMessageTime (most recent first)
      _chats.sort((a, b) {
        final timeA = a['lastMessageTime'] != null 
            ? DateTime.parse(a['lastMessageTime'].toString()).millisecondsSinceEpoch 
            : 0;
        final timeB = b['lastMessageTime'] != null 
            ? DateTime.parse(b['lastMessageTime'].toString()).millisecondsSinceEpoch 
            : 0;
        return timeB.compareTo(timeA);
      });
      
      // Fetch public chat separately
      _publicChat = await ApiService.getOrCreatePublicChat();
      
      // Join all chat rooms for real-time updates
      _joinAllChatRooms();
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }
  
  void _joinAllChatRooms() {
    // Join all chat rooms to receive real-time updates
    for (var chat in _chats) {
      final chatId = chat['_id']?.toString() ?? chat['id']?.toString();
      if (chatId != null && chatId != _currentChatId) {
        SocketService.joinChat(chatId);
      }
    }
    
    // Also join public chat room
    if (_publicChat != null) {
      final publicChatId = _publicChat!['_id']?.toString() ?? _publicChat!['id']?.toString();
      if (publicChatId != null && publicChatId != _currentChatId) {
        SocketService.joinChat(publicChatId);
      }
    }
  }

  Future<void> getOrCreateChat(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentChat = await ApiService.getOrCreateChat(userId);
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadChatMessages(String chatId) async {
    _isLoading = true;
    notifyListeners();

    // Leave previous chat room
    if (_currentChatId != null) {
      SocketService.leaveChat(_currentChatId!);
    }

    try {
      _currentChat = await ApiService.getChatMessages(chatId);
      _currentChatId = chatId;
      
      // Join new chat room for real-time updates
      SocketService.joinChat(chatId);
    } catch (e) {
      // Handle error
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String chatId, String message) async {
    try {
      // Send message via API (backend already handles socket emissions)
      final response = await ApiService.sendMessage(chatId, message);
      
      // Check for errors
      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
      
      // Update current chat with the new message immediately for instant UI feedback
      if (_currentChat != null && _currentChat!['_id'] == chatId && response['message'] != null) {
        final messages = _currentChat!['messages'] as List? ?? [];
        messages.add(response['message']);
        _currentChat!['messages'] = messages;
        _currentChat!['lastMessage'] = response['lastMessage'] ?? message;
        _currentChat!['lastMessageTime'] = response['lastMessageTime'];
        notifyListeners();
      }
      
      // No need to call fetchChats() - socket listeners will handle refreshing the chat list
      // This makes message sending much faster!
    } catch (e) {
      // Handle error
      rethrow; // Re-throw to let UI handle the error
    }
  }

  @override
  void dispose() {
    if (_currentChatId != null) {
      SocketService.leaveChat(_currentChatId!);
    }
    SocketService.offMessage();
    SocketService.offChatUpdate();
    super.dispose();
  }
}

