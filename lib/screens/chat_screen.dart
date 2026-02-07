import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../utils/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? chatName;
  final bool isPublicChat;
  final Color? accentColor;
  final bool isReadOnly;
  
  const ChatScreen({
    super.key,
    required this.chatId,
    this.chatName,
    this.isPublicChat = false,
    this.accentColor,
    this.isReadOnly = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  Map<String, dynamic>? _readOnlyChat;
  bool _isLoadingReadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isReadOnly) {
        _loadReadOnlyChat();
      } else {
        final chatProvider = Provider.of<ChatProvider>(context, listen: false);
        chatProvider.loadChatMessages(widget.chatId);
      }
    });
  }

  Future<void> _loadReadOnlyChat() async {
    setState(() => _isLoadingReadOnly = true);
    try {
      final chatData = await ApiService.getAdminChatMessages(widget.chatId);
      if (mounted) {
        setState(() {
          _readOnlyChat = chatData;
          _isLoadingReadOnly = false;
        });
        // Scroll to bottom after loading
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReadOnly = false);
      }
    }
  }

  Color get _accentColor => widget.accentColor ?? AppTheme.primaryColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _accentColor,
              _accentColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildDateDivider('Today'),
                      Expanded(
                        child: widget.isReadOnly
                            ? _buildReadOnlyChatView()
                            : Consumer<ChatProvider>(
                                builder: (context, chatProvider, _) {
                                  final chat = chatProvider.currentChat;
                                  if (chat == null) {
                                    return const Center(child: CircularProgressIndicator());
                                  }

                                  final messages = chat['messages'] as List? ?? [];
                                  final participants = chat['participants'] as List? ?? [];
                                  
                                  // Get current user ID from auth provider
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  final currentUserId = authProvider.user?['_id']?.toString() ?? 
                                                       authProvider.user?['id']?.toString();

                                  // Scroll to bottom when new messages arrive
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_scrollController.hasClients) {
                                      _scrollController.animateTo(
                                        _scrollController.position.maxScrollExtent,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  });

                                  return ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      if (index >= messages.length) {
                                        return const SizedBox.shrink();
                                      }
                                      final message = messages[index];
                                      if (message == null) {
                                        return const SizedBox.shrink();
                                      }
                                      // Get sender ID - handle both object and string formats
                                      final sender = message['sender'];
                                      final senderId = sender is Map 
                                          ? (sender['_id']?.toString() ?? sender['id']?.toString())
                                          : sender?.toString();
                                      // Check if message is from current user (sender)
                                      final isMe = senderId != null && 
                                                  currentUserId != null && 
                                                  senderId.toString() == currentUserId.toString();

                                      return TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration: Duration(milliseconds: 300 + (index * 80)),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, value, child) {
                                          return Transform.translate(
                                            offset: Offset(0, 20 * (1 - value)),
                                            child: Opacity(
                                              opacity: value,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: _buildMessage(message, isMe, participants, currentUserId),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      if (!widget.isReadOnly) _buildInputArea(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    // Get chat data to display profile photo
    if (widget.isReadOnly) {
      // For read-only mode, get participants from _readOnlyChat
      if (_readOnlyChat != null) {
        final participants = _readOnlyChat!['participants'] as List? ?? [];
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = authProvider.user?['_id']?.toString() ?? 
                             authProvider.user?['id']?.toString();
        
        // Find the other participant (not the current user)
        dynamic otherParticipant;
        if (!widget.isPublicChat && participants.isNotEmpty) {
          for (var participant in participants) {
            if (participant == null || participant is! Map) continue;
            
            final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
            if (participantId == null) continue;
            
            if (participantId != currentUserId) {
              otherParticipant = participant;
              break;
            }
          }
        }
        
        return _buildAppBarContent(otherParticipant);
      }
      return _buildAppBarContent(null);
    }
    
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        final chat = chatProvider.currentChat;
        if (chat == null) {
          return _buildAppBarContent(null);
        }
        
        final participants = chat['participants'] as List? ?? [];
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = authProvider.user?['_id']?.toString() ?? 
                             authProvider.user?['id']?.toString();
        
        // Find the other participant (not the current user)
        dynamic otherParticipant;
        if (!widget.isPublicChat && participants.isNotEmpty) {
          for (var participant in participants) {
            if (participant == null || participant is! Map) continue;
            
            final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
            if (participantId == null) continue;
            
            if (participantId != currentUserId) {
              otherParticipant = participant;
              break;
            }
          }
        }
        
        return _buildAppBarContent(otherParticipant);
      },
    );
  }

  Widget _buildAppBarContent(dynamic otherParticipant) {
    final profilePhoto = otherParticipant != null && otherParticipant is Map
        ? otherParticipant['profilePhoto']?.toString()
        : null;
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 12),
          Hero(
            tag: 'avatar_${widget.chatId}',
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.95),
              ),
              child: widget.isPublicChat
                  ? const Center(
                      child: Text('👥', style: TextStyle(fontSize: 20)),
                    )
                  : (profilePhoto != null && profilePhoto.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            profilePhoto,
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(Icons.person, size: 20),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.person, size: 20),
                        )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatName ?? 'Chat',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isReadOnly 
                      ? 'Read Only' 
                      : widget.isPublicChat 
                          ? 'Public Chat' 
                          : 'Online',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildDateDivider(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.shade300,
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                date,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.shade300,
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _getSenderName(dynamic message, List? participants, String? currentUserId) {
    if (message['sender'] == null || participants == null || participants.isEmpty) {
      return '';
    }
    
    final currentUserIdStr = currentUserId?.toString().trim();
    if (currentUserIdStr == null || currentUserIdStr.isEmpty) return '';
    
    // Extract sender ID from message to verify it's not from current user
    final sender = message['sender'];
    String? senderId;
    
    if (sender is Map) {
      senderId = sender['_id']?.toString() ?? sender['id']?.toString();
    } else {
      senderId = sender?.toString();
    }
    
    if (senderId != null) {
      final senderIdStr = senderId.toString().trim();
      // If message is from current user, don't show sender name
      if (senderIdStr == currentUserIdStr) {
        return '';
      }
    }
    
    // For 1-on-1 chats: Simply return the other participant's name
    // (the one who is NOT the current user)
    if (participants.length == 2) {
      for (var participant in participants) {
        if (participant == null || participant is! Map) continue;
        
        final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
        if (participantId == null) continue;
        
        final participantIdStr = participantId.toString().trim();
        
        // Return the participant who is NOT the current user
        if (participantIdStr != currentUserIdStr) {
          final username = participant['username']?.toString().trim() ?? 
                          participant['name']?.toString().trim();
          if (username != null && username.isNotEmpty) {
            return username;
          }
        }
      }
    } else {
      // For group chats: Find participant by matching sender ID
      if (senderId != null) {
        final senderIdStr = senderId.toString().trim();
        for (var participant in participants) {
          if (participant == null || participant is! Map) continue;
          
          final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
          if (participantId == null) continue;
          
          final participantIdStr = participantId.toString().trim();
          
          // Skip current user
          if (participantIdStr == currentUserIdStr) continue;
          
          // Match found - return this participant's username
          if (participantIdStr == senderIdStr) {
            final username = participant['username']?.toString().trim() ?? 
                            participant['name']?.toString().trim();
            if (username != null && username.isNotEmpty) {
              return username;
            }
          }
        }
      }
    }
    
    return '';
  }

  Widget _buildMessage(dynamic message, bool isMe, List? participants, String? currentUserId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: isMe
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _accentColor,
                        _accentColor.withOpacity(0.85),
                      ],
                    )
                  : null,
              color: isMe ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(22),
                topRight: const Radius.circular(22),
                bottomLeft: Radius.circular(isMe ? 22 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 22),
              ),
              boxShadow: [
                BoxShadow(
                  color: isMe
                      ? _accentColor.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMe && message['sender'] != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _getSenderName(message, participants, currentUserId),
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  message['message']?.toString() ?? '',
                  style: GoogleFonts.poppins(
                    color: isMe ? Colors.white : const Color(0xFF1A1D29),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatMessageTime(message['timestamp'] ?? message['createdAt']),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withOpacity(0.7)
                        : Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyChatView() {
    if (_isLoadingReadOnly) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_readOnlyChat == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No chat found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final messages = _readOnlyChat!['messages'] as List? ?? [];
    final participants = _readOnlyChat!['participants'] as List? ?? [];

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // Get current user ID from auth provider (for determining message alignment)
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?['_id']?.toString() ?? 
                         authProvider.user?['id']?.toString();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return const SizedBox.shrink();
        }
        final message = messages[index];
        if (message == null) {
          return const SizedBox.shrink();
        }
        // Get sender ID - handle both object and string formats
        final sender = message['sender'];
        final senderId = sender is Map 
            ? (sender['_id']?.toString() ?? sender['id']?.toString())
            : sender?.toString();
        // Check if message is from current user (sender)
        // For read-only mode, we'll show all messages as "not me" to align left
        final isMe = false; // Always show as received messages in read-only mode

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 80)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: _buildMessage(message, isMe, participants, currentUserId),
        );
      },
    );
  }

  String _formatMessageTime(dynamic time) {
    if (time == null) return 'Now';
    try {
      final dateTime = DateTime.parse(time.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return 'Now';
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.add_circle_rounded,
                  color: _accentColor,
                  size: 24,
                ),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FE),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _accentColor,
                    _accentColor.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _accentColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    await chatProvider.sendMessage(widget.chatId, _messageController.text.trim());
    _messageController.clear();

    // Scroll to bottom after a short delay to allow UI to update
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
