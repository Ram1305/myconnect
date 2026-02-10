import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../utils/api_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _searchedUsers = [];
  bool _isSearchingUsers = false;
  List<dynamic> _allChatsForSearch = []; // Store all chats including ones without messages

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fabController.forward();
    
    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ChatProvider>(context, listen: false).fetchChats();
      _loadAllChatsForSearch();
    });
  }
  
  Future<void> _loadAllChatsForSearch() async {
    try {
      final allChats = await ApiService.getChats();
      if (mounted) {
        setState(() {
          _allChatsForSearch = allChats;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _searchQuery = query.toLowerCase();
    });
    
    // Search users if query is not empty
    if (query.isNotEmpty) {
      _searchUsers(query);
    } else {
      setState(() {
        _searchedUsers = [];
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchedUsers = [];
        _isSearchingUsers = false;
      });
      return;
    }

    setState(() {
      _isSearchingUsers = true;
    });

    try {
      print('🔍 USER SEARCH DEBUG - Searching for: "$query"');
      
      // Ensure _allChatsForSearch is populated before searching
      if (_allChatsForSearch.isEmpty) {
        print('🔍 USER SEARCH DEBUG - _allChatsForSearch is empty, fetching...');
        await _loadAllChatsForSearch();
      }
      print('🔍 USER SEARCH DEBUG - _allChatsForSearch length: ${_allChatsForSearch.length}');
      
      final users = await ApiService.getApprovedUsers(search: query);
      print('🔍 USER SEARCH DEBUG - Users returned from API: ${users.length}');
      for (var user in users) {
        final username = user['username']?.toString() ?? 'No username';
        final userId = user['_id']?.toString() ?? user['id']?.toString();
        print('🔍 USER SEARCH DEBUG - User: ID=$userId, Username="$username"');
      }
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?['_id']?.toString() ?? 
                           authProvider.user?['id']?.toString();
      
      // Filter out current user and get chat provider to check existing chats
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Get user IDs who already have ANY chat (including ones without messages)
      // If a user has a chat (even without messages), show that chat in filtered chats, not in user search
      final existingChatUserIds = <String>{};
      
      // Check ALL chats (including ones without messages) from _allChatsForSearch
      // This ensures users with chats (even without messages) are excluded from user search
      for (var chat in _allChatsForSearch) {
        final isPublic = chat['isPublic'] == true;
        if (isPublic) continue; // Skip public chats
        
        final participants = (chat['participants'] as List?) ?? [];
        for (var participant in participants) {
          if (participant is Map) {
            final userId = participant['_id']?.toString() ?? 
                          participant['id']?.toString();
            if (userId != null && userId != currentUserId) {
              existingChatUserIds.add(userId);
            }
          }
        }
      }
      
      print('🔍 USER SEARCH DEBUG - Existing chat user IDs (ALL chats including without messages): $existingChatUserIds');
      print('🔍 USER SEARCH DEBUG - Current User ID: $currentUserId');
      
      // Filter users: exclude current user and users who already have ANY chat
      // If a user has a chat (even without messages), it will appear in filtered chats instead
      final filteredUsers = users.where((user) {
        final userId = user['_id']?.toString() ?? user['id']?.toString();
        final username = user['username']?.toString() ?? 'No username';
        final hasExistingChat = existingChatUserIds.contains(userId);
        final shouldInclude = userId != null && 
               userId != currentUserId && 
               !hasExistingChat;
        print('🔍 USER SEARCH DEBUG - User "$username" (ID: $userId) - Has existing chat: $hasExistingChat, Include: $shouldInclude');
        return shouldInclude;
      }).toList();
      
      print('🔍 USER SEARCH DEBUG - Filtered Users Count: ${filteredUsers.length}');
      for (var user in filteredUsers) {
        final username = user['username']?.toString() ?? 'No username';
        print('🔍 USER SEARCH DEBUG - ✅ Filtered User: "$username"');
      }

      if (mounted) {
        setState(() {
          _searchedUsers = filteredUsers;
          _isSearchingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchedUsers = [];
          _isSearchingUsers = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getAccentColor(int index, bool isPublic) {
    if (isPublic) return AppTheme.primaryColor;
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF6B9D),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFA502),
      const Color(0xFF9B59B6),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
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
                      const SizedBox(height: 20),
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Consumer<ChatProvider>(
                          builder: (context, chatProvider, _) {
                            if (chatProvider.isLoading) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            // Combine public chat and regular chats
                            // For search, use ALL chats (including ones without messages) from _allChatsForSearch
                            // For display without search, use only chats with messages from chatProvider.chats
                            final List<dynamic> allChats = [];
                            
                            // Add My Connect public chat as first item (always show, even if no messages)
                            if (chatProvider.publicChat != null) {
                              allChats.add(chatProvider.publicChat!);
                            }
                            
                            // For search, use all chats (including ones without messages)
                            // For normal display, use only chats with messages
                            if (_searchQuery.isNotEmpty) {
                              // Ensure _allChatsForSearch is populated
                              if (_allChatsForSearch.isEmpty) {
                                // Trigger a refresh (this will happen asynchronously)
                                _loadAllChatsForSearch();
                              }
                              
                              // Use all chats for search (including ones without messages)
                              for (var chat in _allChatsForSearch) {
                                final isPublic = chat['isPublic'] == true;
                                if (!isPublic) {
                                  allChats.add(chat);
                                }
                              }
                            } else {
                              // Normal display: only show chats with messages
                              allChats.addAll(chatProvider.chats);
                            }

                            // Filter chats based on search query (by username only)
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final currentUserId = authProvider.user?['_id']?.toString() ?? 
                                                 authProvider.user?['id']?.toString();
                            
                            print('🔍 SEARCH DEBUG - Search Query: "$_searchQuery"');
                            print('🔍 SEARCH DEBUG - Current User ID: $currentUserId');
                            print('🔍 SEARCH DEBUG - _allChatsForSearch length: ${_allChatsForSearch.length}');
                            print('🔍 SEARCH DEBUG - chatProvider.chats length: ${chatProvider.chats.length}');
                            print('🔍 SEARCH DEBUG - Total Chats (allChats): ${allChats.length}');
                            
                            // Print all chats and their participants
                            for (var i = 0; i < allChats.length; i++) {
                              final chat = allChats[i];
                              final chatId = chat['_id']?.toString() ?? 'No ID';
                              final participants = (chat['participants'] as List?) ?? [];
                              final isPublic = chat['isPublic'] == true;
                              print('🔍 SEARCH DEBUG - Chat $i: ID=$chatId, isPublic=$isPublic, Participants Count=${participants.length}');
                              for (var j = 0; j < participants.length; j++) {
                                final participant = participants[j];
                                if (participant == null || participant is! Map) {
                                  print('🔍 SEARCH DEBUG -   Participant $j: null or not Map');
                                  continue;
                                }
                                final participantId = participant['_id']?.toString() ?? participant['id']?.toString() ?? 'No ID';
                                final username = participant['username']?.toString() ?? 'No username';
                                final isCurrentUser = participantId == currentUserId;
                                print('🔍 SEARCH DEBUG -   Participant $j: ID=$participantId, Username="$username", IsCurrentUser=$isCurrentUser');
                                
                                // Check if this username matches the search query
                                if (_searchQuery.isNotEmpty && !isCurrentUser) {
                                  final usernameLower = username.toLowerCase().trim();
                                  final searchLower = _searchQuery.toLowerCase().trim();
                                  final matches = usernameLower.contains(searchLower);
                                  print('🔍 SEARCH DEBUG -     Username match check: "$usernameLower" contains "$searchLower" = $matches');
                                }
                              }
                            }
                            
                            final List<dynamic> filteredChats = _searchQuery.isEmpty
                                ? allChats
                                : allChats.where((chat) {
                                    final participants = (chat['participants'] as List?) ?? [];
                                    final isPublicChat = chat['isPublic'] == true;
                                    
                                    // Exclude public/My Connect chat from search results
                                    if (isPublicChat) {
                                      print('🔍 SEARCH DEBUG - Excluding public chat from search results');
                                      return false;
                                    }
                                    
                                    // Check other participant's username only (case-insensitive)
                                    // Trim and normalize spaces in username for better matching
                                    for (var participant in participants) {
                                      if (participant == null || participant is! Map) continue;
                                      
                                      final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
                                      if (participantId == null) continue;
                                      
                                      // Skip current user - only check other participants
                                      if (participantId == currentUserId) {
                                        print('🔍 SEARCH DEBUG - Skipping current user: ID=$participantId');
                                        continue;
                                      }
                                      
                                      final username = (participant['username']?.toString() ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
                                      final searchQueryTrimmed = _searchQuery.trim();
                                      
                                      print('🔍 SEARCH DEBUG - Checking participant: ID=$participantId, Username="$username", Search Query="$searchQueryTrimmed", Match=${username.contains(searchQueryTrimmed)}');
                                      
                                      if (username.contains(searchQueryTrimmed)) {
                                        print('🔍 SEARCH DEBUG - ✅ MATCH FOUND for username: "$username"');
                                        return true;
                                      }
                                    }
                                    
                                    return false;
                                  }).toList();
                            
                            print('🔍 SEARCH DEBUG - Filtered Chats Count: ${filteredChats.length}');
                            
                            // Sort filtered chats: names starting with search query come first
                            if (_searchQuery.isNotEmpty) {
                              filteredChats.sort((a, b) {
                                final participantsA = (a['participants'] as List?) ?? [];
                                final participantsB = (b['participants'] as List?) ?? [];
                                final isPublicA = a['isPublic'] == true;
                                final isPublicB = b['isPublic'] == true;
                                
                                // Get display usernames for comparison
                                String usernameA = '';
                                String usernameB = '';
                                
                                if (!isPublicA) {
                                  for (var participant in participantsA) {
                                    if (participant == null || participant is! Map) continue;
                                    final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
                                    if (participantId != null && participantId != currentUserId) {
                                      usernameA = (participant['username']?.toString() ?? '').toLowerCase();
                                      break;
                                    }
                                  }
                                } else {
                                  usernameA = 'my connect'; // Public chats go to bottom
                                }
                                
                                if (!isPublicB) {
                                  for (var participant in participantsB) {
                                    if (participant == null || participant is! Map) continue;
                                    final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
                                    if (participantId != null && participantId != currentUserId) {
                                      usernameB = (participant['username']?.toString() ?? '').toLowerCase();
                                      break;
                                    }
                                  }
                                } else {
                                  usernameB = 'my connect'; // Public chats go to bottom
                                }
                                
                                // Check if username starts with search query
                                final startsWithA = usernameA.startsWith(_searchQuery);
                                final startsWithB = usernameB.startsWith(_searchQuery);
                                
                                // Names starting with search query come first
                                if (startsWithA && !startsWithB) return -1;
                                if (!startsWithA && startsWithB) return 1;
                                
                                // Otherwise sort alphabetically
                                return usernameA.compareTo(usernameB);
                              });
                            }
                            
                            for (var i = 0; i < filteredChats.length; i++) {
                              final chat = filteredChats[i];
                              final chatId = chat['_id']?.toString() ?? 'No ID';
                              final isPublic = chat['isPublic'] == true;
                              print('🔍 SEARCH DEBUG - Filtered Chat $i: ID=$chatId, isPublic=$isPublic');
                            }

                            // Combine filtered chats and searched users
                            final bool hasSearchQuery = _searchQuery.isNotEmpty;
                            
                            // Sort searched users: names starting with search query come first
                            List<dynamic> sortedSearchedUsers = List.from(_searchedUsers);
                            if (hasSearchQuery) {
                              sortedSearchedUsers.sort((a, b) {
                                final usernameA = (a['username']?.toString() ?? '').toLowerCase();
                                final usernameB = (b['username']?.toString() ?? '').toLowerCase();
                                
                                final startsWithA = usernameA.startsWith(_searchQuery);
                                final startsWithB = usernameB.startsWith(_searchQuery);
                                
                                // Names starting with search query come first
                                if (startsWithA && !startsWithB) return -1;
                                if (!startsWithA && startsWithB) return 1;
                                
                                // Otherwise sort alphabetically
                                return usernameA.compareTo(usernameB);
                              });
                            }
                            
                            final int chatCount = filteredChats.length;
                            final int userCount = hasSearchQuery ? sortedSearchedUsers.length : 0;
                            final int totalItems = chatCount + userCount;
                            
                            print('🔍 SEARCH DEBUG - chatCount=$chatCount, userCount=$userCount, totalItems=$totalItems');

                            if (totalItems == 0) {
                              if (_isSearchingUsers) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return Center(
                                child: Text(
                                  _searchQuery.isEmpty ? 'No chats yet' : 'No chats or users found',
                                  style: GoogleFonts.poppins(),
                                ),
                              );
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: totalItems,
                              itemBuilder: (context, index) {
                                // Show chats first, then users
                                if (index < chatCount) {
                                  // Existing chat
                                  final chat = filteredChats[index];
                                  final participants = (chat['participants'] as List?) ?? [];
                                  
                                  print('🔍 UI DEBUG - Building chat item at index $index');
                                  
                                  // Get current user ID to filter out from participants
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  final currentUserId = authProvider.user?['_id']?.toString() ?? 
                                                       authProvider.user?['id']?.toString();
                                  
                                  final isPublicChat = chat['isPublic'] == true;
                                  
                                  print('🔍 UI DEBUG - Chat at index $index: isPublicChat=$isPublicChat');
                                  
                                  // Find the other participant (not the current user)
                                  String displayName = 'Unknown User';
                                  dynamic displayPhoto;
                                  
                                  if (!isPublicChat) {
                                    for (var participant in participants) {
                                      if (participant == null || participant is! Map) continue;
                                      
                                      final participantId = participant['_id']?.toString() ?? participant['id']?.toString();
                                      if (participantId == null) continue;
                                      
                                      // If this participant is NOT the current user, use their info
                                      if (participantId != currentUserId) {
                                        displayName = participant['username']?.toString() ?? 
                                                     participant['name']?.toString() ?? 
                                                     'Unknown User';
                                        displayPhoto = participant;
                                        break;
                                      }
                                    }
                                    
                                    // Fallback if no other participant found
                                    if (displayName == 'Unknown User' && participants.isNotEmpty) {
                                      final firstParticipant = participants[0];
                                      if (firstParticipant is Map) {
                                        displayName = firstParticipant['username']?.toString() ?? 
                                                     firstParticipant['name']?.toString() ?? 
                                                     'Unknown User';
                                        displayPhoto = firstParticipant;
                                      }
                                    }
                                  } else {
                                    final publicName = chat['name']?.toString().trim();
                                    displayName = (publicName != null && publicName.isNotEmpty) ? publicName : 'My Connect';
                                  }
                                  
                                  print('🔍 UI DEBUG - Display name set to: "$displayName" for chat at index $index');
                                  
                                  final accentColor = _getAccentColor(index, isPublicChat);

                                  return TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: Duration(milliseconds: 300 + (index * 100)),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 30 * (1 - value)),
                                        child: Opacity(
                                          opacity: value,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _buildChatItem(chat, displayName, displayPhoto, isPublicChat, accentColor, index),
                                  );
                                } else {
                                  // New user to start chat with
                                  final userIndex = index - chatCount;
                                  if (userIndex < sortedSearchedUsers.length) {
                                    final user = sortedSearchedUsers[userIndex];
                                    final username = user['username']?.toString() ?? 'Unknown User';
                                    final name = user['name']?.toString() ?? '';
                                    final displayName = name.isNotEmpty ? name : username;
                                    final accentColor = _getAccentColor(index, false);

                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(milliseconds: 300 + (index * 100)),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, child) {
                                        return Transform.translate(
                                          offset: Offset(0, 30 * (1 - value)),
                                          child: Opacity(
                                            opacity: value,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: _buildNewUserItem(user, displayName, accentColor, index),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }
                              },
                            );
                          },
                        ),
                      ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(-30 * (1 - value), 0),
                        child: Opacity(opacity: value, child: child),
                      );
                    },
                    child: Text(
                      'Messages',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name...',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.grey.shade400,
                size: 24,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(dynamic chat, String displayName, dynamic displayPhoto, bool isPublicChat, Color accentColor, int index) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ChatScreen(chatId: chat['_id'], chatName: displayName, isPublicChat: isPublicChat, accentColor: accentColor),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
        // Refresh chat list when returning from chat screen
        if (mounted) {
          Provider.of<ChatProvider>(context, listen: false).fetchChats();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Hero(
                  tag: 'avatar_${chat['_id']}',
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withOpacity(0.8),
                          accentColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isPublicChat
                          ? const Text('👥', style: TextStyle(fontSize: 24))
                          : (displayPhoto != null && displayPhoto['profilePhoto'] != null && displayPhoto['profilePhoto'].isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    displayPhoto['profilePhoto'],
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Text('👤', style: TextStyle(fontSize: 24)),
                                  ),
                                )
                              : const Text('👤', style: TextStyle(fontSize: 24))),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1D29),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    chat['lastMessage'] ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatTime(chat['lastMessageTime']),
                    style: TextStyle(
                      fontSize: 12,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewUserItem(dynamic user, String displayName, Color accentColor, int index) {
    return GestureDetector(
      onTap: () async {
        // Create or get chat with this user
        final userId = user['_id']?.toString() ?? user['id']?.toString();
        if (userId == null) return;

        try {
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          await chatProvider.getOrCreateChat(userId);
          
          // Get the chat that was created/retrieved
          final newChat = chatProvider.currentChat;
          
          if (newChat != null && mounted) {
            final participants = (newChat['participants'] as List?) ?? [];
            final otherParticipant = participants.length > 1 ? participants[1] : (participants.isNotEmpty ? participants[0] : null);
            final chatName = otherParticipant?['username']?.toString() ?? 
                           otherParticipant?['name']?.toString() ?? 
                           displayName;
            
            await Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    ChatScreen(chatId: newChat['_id'], chatName: chatName, isPublicChat: false, accentColor: accentColor),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  var tween = Tween(begin: begin, end: end).chain(
                    CurveTween(curve: curve),
                  );
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
            
            // Refresh chat list when returning
            if (mounted) {
              await chatProvider.fetchChats();
              // Clear search to show updated list
              _searchController.clear();
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to start chat: ${e.toString()}')),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withOpacity(0.8),
                        accentColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: user['profilePhoto'] != null && user['profilePhoto'].toString().isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              user['profilePhoto'],
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Text('👤', style: TextStyle(fontSize: 24)),
                            ),
                          )
                        : const Text('👤', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A1D29),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to start a chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: accentColor,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return 'Just now';
    try {
      final dateTime = DateTime.parse(time.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Just now';
    }
  }
}
