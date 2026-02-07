import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/user_provider.dart';
import '../providers/mylist_provider.dart';
import '../providers/notification_provider.dart';
import '../utils/theme.dart';
import '../utils/permission_service.dart';
import '../config/app_config.dart';
import 'video_details_screen.dart';
import 'mylist_screen.dart';
import 'family_locations_screen.dart';
import 'notification_sheet.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  FamilyMembersScreenState createState() => _FamilyMembersScreenState();
}

abstract class FamilyMembersScreenState extends State<FamilyMembersScreen> {
  void refreshUsers();
}

class _FamilyMembersScreenState extends FamilyMembersScreenState with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  double? _userLatitude;
  double? _userLongitude;
  bool _isSelectionMode = false;
  final Set<String> _tickedUsers = {}; // Track users with strikethrough
  final Set<String> _addedUsers = {}; // Track users added to my list

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTickedUsers(); // Load ticked users from SharedPreferences
    _getCurrentLocation();
    _loadUsers();
    _loadAddedUsers();
  }

  Future<void> _loadTickedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tickedUsersJson = prefs.getString('home_ticked_users');
      if (tickedUsersJson != null) {
        final List<dynamic> tickedUsersList = jsonDecode(tickedUsersJson);
        if (mounted) {
          setState(() {
            _tickedUsers.clear();
            _tickedUsers.addAll(tickedUsersList.cast<String>());
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading ticked users: $e');
    }
  }

  Future<void> _saveTickedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tickedUsersList = _tickedUsers.toList();
      await prefs.setString('home_ticked_users', jsonEncode(tickedUsersList));
    } catch (e) {
      debugPrint('Error saving ticked users: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh users when app resumes
      _loadUsers();
    }
  }

  // Public method to refresh users (called from dashboard)
  @override
  void refreshUsers() {
    _loadUsers();
  }

  Future<void> _loadAddedUsers() async {
    final myListProvider = Provider.of<MyListProvider>(context, listen: false);
    await myListProvider.fetchMyList();
    if (mounted) {
      setState(() {
        _addedUsers.clear();
        for (var member in myListProvider.members) {
          final memberId = member['memberId']?['_id']?.toString();
          if (memberId != null) {
            _addedUsers.add(memberId);
          }
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    // Skip geolocator on Windows
    if (!kIsWeb && Platform.isWindows) {
      _loadUsers();
      return;
    }

    // Request location permission first
    final hasPermission = await PermissionService.requestLocationPermission(context);
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location permission is required to show nearby users',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });
      _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error getting location: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadUsers() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.fetchApprovedUsers(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      latitude: _userLatitude,
      longitude: _userLongitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
        title: Text(
          'Family Members',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          // Notification Bell
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const NotificationSheet(),
                      );
                    },
                    tooltip: 'Notifications',
                  ),
                  if (notificationProvider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${notificationProvider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.public),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FamilyLocationsScreen(),
                ),
              );
            },
            tooltip: 'Family Locations',
          ),
          if (_isSelectionMode && Provider.of<UserProvider>(context).hasSelection)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addToMyList,
            ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyListScreen()),
              );
              // Refresh added users when returning from MyListScreen
              _loadAddedUsers();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadUsers();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (_) => _loadUsers(),
            ),
          ),
          if (_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Text(
                    '${Provider.of<UserProvider>(context).selectedUsers.length} selected',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        Provider.of<UserProvider>(context, listen: false).clearSelection();
                      });
                    },
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                if (userProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (userProvider.approvedUsers.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: userProvider.approvedUsers.length,
                  itemBuilder: (context, index) {
                    final user = userProvider.approvedUsers[index];
                    final isSelected = userProvider.selectedUsers.contains(user['_id']);

                    return GestureDetector(
                      onLongPress: () {
                        setState(() => _isSelectionMode = true);
                        userProvider.toggleUserSelection(user['_id']);
                      },
                      onTap: () {
                        if (_isSelectionMode) {
                          userProvider.toggleUserSelection(user['_id']);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoDetailsScreen(userId: user['_id']),
                            ),
                          );
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.only(right: 16, bottom: 16, left: 10),
                            decoration: AppTheme.glassyDecoration().copyWith(
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: user['profilePhoto'] != null &&
                                      user['profilePhoto'].isNotEmpty
                                      ? NetworkImage(user['profilePhoto'])
                                      : null,
                                  child: user['profilePhoto'] == null ||
                                      user['profilePhoto'].isEmpty
                                      ? const Icon(Icons.person, size: 14)
                                      : null,
                                ),

                                const SizedBox(width: 16),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      Text(
                                        user['username'] ?? '',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          decoration: _tickedUsers.contains(user['_id'].toString())
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                          decorationColor: Colors.black,
                                          decorationThickness: 2,
                                        ),
                                      ),
                                      Text(
                                        'Father: ${user['fatherName'] ?? ''}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      if (user['currentAddress'] != null) ...[
                                        const SizedBox(height: 4),
                                        _buildAddressDisplay(user),
                                      ],
                                    ],
                                  ),
                                ),

                                Column(
                                  children: [
                                    const SizedBox(height: 25),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.phone, color: AppTheme.primaryColor),
                                          onPressed: () => _makeCall(user['mobileNumber']),
                                          tooltip: 'Call',
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.map, color: AppTheme.primaryColor),
                                          onPressed: () => _openMap(user),
                                          tooltip: 'Map',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ✔ KM at bottom-right
                          if (user['distance'] != null && user['distance'].toString().isNotEmpty)
                            Positioned(
                              bottom: 5,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${user['distance']} km',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),

                          // ✔ Add to list badge (Top-right) - Shows primary color when added to list
                          Positioned(
                            top: 10,
                            right: 75,
                            child: GestureDetector(
                              onTap: () => _addSingleUserToMyList(user['_id']),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_addedUsers.contains(user['_id'])
                                      ? AppTheme.primaryColor
                                      : Colors.white)
                                      .withOpacity(0.95),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(50),
                                    bottomRight: Radius.circular(50),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _addedUsers.contains(user['_id'])
                                      ? Icons.add_box_rounded
                                      : Icons.add,
                                  size: 18,
                                  color: _addedUsers.contains(user['_id'])
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),

                          // ✔ Tick badge (Top-right) - Toggles strikethrough on username
                          Positioned(
                            top: 10,
                            right: 30,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  final userId = user['_id'].toString();
                                  if (_tickedUsers.contains(userId)) {
                                    _tickedUsers.remove(userId);
                                  } else {
                                    _tickedUsers.add(userId);
                                  }
                                });
                                _saveTickedUsers(); // Save to SharedPreferences
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (_tickedUsers.contains(user['_id'].toString())
                                      ? Colors.black
                                      : Colors.white)
                                      .withOpacity(0.95),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(50),
                                    bottomRight: Radius.circular(50),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _tickedUsers.contains(user['_id'].toString())
                                      ? Icons.verified
                                      : Icons.check_circle_outline,
                                  size: 18,
                                  color: _tickedUsers.contains(user['_id'].toString())
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );

              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyListScreen()),
          );
          // Refresh added users when returning from MyListScreen
          _loadAddedUsers();
        },
        icon: const Icon(Icons.list),
        label: Text(
          'My List',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _makeCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phone number not available',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
      return;
    }

    // Open dialer directly with the phone number
    // No permission needed to open dialer (only needed to actually make the call)
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not launch dialer',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open dialer',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openMap(Map<String, dynamic> user) async {
    if (user['latitude'] != null && user['longitude'] != null) {
      final lat = user['latitude'].toDouble();
      final lng = user['longitude'].toDouble();
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _addToMyList() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final myListProvider = Provider.of<MyListProvider>(context, listen: false);

    final selectedUserIds = userProvider.selectedUsers.map((e) => e.toString()).toList();
    final success = await myListProvider.addToMyList(selectedUserIds);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added to My List',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        setState(() {
          _isSelectionMode = false;
          userProvider.clearSelection();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to add to list',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _addSingleUserToMyList(String userId) async {
    final myListProvider = Provider.of<MyListProvider>(context, listen: false);
    final isAlreadyAdded = _addedUsers.contains(userId);

    if (isAlreadyAdded) {
      // Remove from list
      final success = await myListProvider.removeFromMyList(userId);
      if (mounted) {
        if (success) {
          setState(() {
            _addedUsers.remove(userId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Removed from My List',
                style: GoogleFonts.poppins(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to remove from list',
                style: GoogleFonts.poppins(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // Add to list
      final success = await myListProvider.addToMyList([userId.toString()]);
      if (mounted) {
        if (success) {
          setState(() {
            _addedUsers.add(userId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added to My List',
                style: GoogleFonts.poppins(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to add to list',
                style: GoogleFonts.poppins(),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Widget _buildAddressDisplay(Map<String, dynamic> user) {
    final address = user['currentAddress'] as Map<String, dynamic>?;
    if (address == null) return const SizedBox.shrink();

    final distance = user['distance'] != null 
        ? double.tryParse(user['distance'].toString()) 
        : null;
    
    final isFarAway = distance != null && distance > 100;
    
    String addressText;
    if (isFarAway) {
      // Show only state and pincode if > 100km
      final state = address['state']?.toString().trim() ?? '';
      final pincode = address['pincode']?.toString().trim() ?? '';
      
      // Combine state and pincode
      if (state.isNotEmpty && pincode.isNotEmpty) {
        addressText = '$state, $pincode';
      } else if (state.isNotEmpty) {
        addressText = state;
      } else if (pincode.isNotEmpty) {
        addressText = pincode;
      } else {
        addressText = address['address']?.toString().trim() ?? '';
      }
    } else {
      // Show full address if <= 100km
      addressText = address['address']?.toString().trim() ?? '';
    }

    if (addressText.isEmpty) return const SizedBox.shrink();

    return Text(
      addressText,
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.grey[600],
        fontWeight: FontWeight.normal,
      ),
    );
  }
}

