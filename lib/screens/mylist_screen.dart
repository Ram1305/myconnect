import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/mylist_provider.dart';
import '../utils/theme.dart';
import '../utils/permission_service.dart';
import 'video_details_screen.dart';
import 'family_locations_screen.dart';

class MyListScreen extends StatefulWidget {
  const MyListScreen({super.key});

  @override
  State<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends State<MyListScreen> {
  final Set<String> _tickedUsers = {}; // Track users with strikethrough
  final TextEditingController _searchController = TextEditingController();
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTickedUsers(); // Load ticked users from SharedPreferences
      _getCurrentLocation(); // This will call _loadMyList() after getting location
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tickedUsersJson = prefs.getString('mylist_ticked_users');
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
      await prefs.setString('mylist_ticked_users', jsonEncode(tickedUsersList));
    } catch (e) {
      debugPrint('Error saving ticked users: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    // Skip geolocator on Windows
    if (!kIsWeb && Platform.isWindows) {
      _loadMyList();
      return;
    }

    final hasPermission = await PermissionService.requestLocationPermission(context);
    if (!hasPermission) {
      _loadMyList();
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
      _loadMyList();
    } catch (e) {
      _loadMyList();
    }
  }

  Future<void> _loadMyList() async {
    await Provider.of<MyListProvider>(context, listen: false)
        .fetchMyList(latitude: _userLatitude, longitude: _userLongitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My List',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          Consumer<MyListProvider>(
            builder: (context, myListProvider, _) {
              return IconButton(
                icon: const Icon(Icons.public),
                onPressed: () {
                  final members = myListProvider.members;
                  
                  if (members.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No members in your list to show on map',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                    return;
                  }
                  
                  // Filter out striked users - only show non-striked members on map
                  final nonStrikedMembers = members.where((member) {
                    final memberId = member['memberId']?['_id']?.toString();
                    return memberId != null && !_tickedUsers.contains(memberId);
                  }).toList();
                  
                  if (nonStrikedMembers.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No non-striked members to show on map',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                    return;
                  }
                  
                  // Extract member data from filtered list (excluding striked users)
                  final memberDataList = nonStrikedMembers.map((member) => member['memberId']).toList();
                  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FamilyLocationsScreen(usersToShow: memberDataList),
                    ),
                  );
                },
                tooltip: 'My List Locations',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToExcel,
            tooltip: 'Export to Excel',
          ),
        ],
      ),
      body: Consumer<MyListProvider>(
        builder: (context, myListProvider, _) {
          if (myListProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allMembers = myListProvider.members;
          
          // Filter members based on search query
          final filteredMembers = _searchController.text.isEmpty
              ? allMembers
              : allMembers.where((member) {
                  final memberData = member['memberId'];
                  final searchQuery = _searchController.text.toLowerCase();
                  final username = (memberData['username'] ?? '').toString().toLowerCase();
                  final fatherName = (memberData['fatherName'] ?? '').toString().toLowerCase();
                  final mobileNumber = (memberData['mobileNumber'] ?? '').toString().toLowerCase();
                  
                  // Search in address fields
                  String addressText = '';
                  if (memberData['currentAddress'] != null) {
                    final address = memberData['currentAddress'] as Map<String, dynamic>;
                    addressText = [
                      address['address'],
                      address['city'],
                      address['state'],
                      address['pincode'],
                    ].where((e) => e != null).map((e) => e.toString().toLowerCase()).join(' ');
                  }
                  
                  return username.contains(searchQuery) ||
                      fatherName.contains(searchQuery) ||
                      mobileNumber.contains(searchQuery) ||
                      addressText.contains(searchQuery);
                }).toList();

          if (allMembers.isEmpty) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, father name, mobile, or address...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'No members in your list',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, father name, mobile, or address...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (filteredMembers.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No members found matching "${_searchController.text}"',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
              final memberData = member['memberId'];
              final isActive = member['isActive'] ?? true;

              return Dismissible(
                key: Key(memberData['_id'] ?? index.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'Delete Member',
                        style: GoogleFonts.poppins(),
                      ),
                      content: Text(
                        'Are you sure you want to delete this member from your list?',
                        style: GoogleFonts.poppins(),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.poppins(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  myListProvider.removeFromMyList(memberData['_id']);
                },
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoDetailsScreen(userId: memberData['_id']),
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.only(right: 16, bottom: 16, left: 10),
                        decoration: AppTheme.glassyDecoration().copyWith(
                          color: !isActive ? Colors.grey.withValues(alpha: 0.3) : null,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: memberData['profilePhoto'] != null && memberData['profilePhoto'].isNotEmpty
                                  ? NetworkImage(memberData['profilePhoto'])
                                  : null,
                              child: memberData['profilePhoto'] == null || memberData['profilePhoto'].isEmpty
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
                                    memberData['username'] ?? '',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      decoration: _tickedUsers.contains(memberData['_id'].toString())
                                          ? TextDecoration.lineThrough
                                          : TextDecoration.none,
                                      decorationColor: Colors.black,
                                      decorationThickness: 2,
                                    ),
                                  ),
                                  Text(
                                    'Father: ${memberData['fatherName'] ?? ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (memberData['currentAddress'] != null) ...[
                                    const SizedBox(height: 4),
                                    _buildAddressDisplay(memberData),
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
                                      onPressed: () => _makeCall(memberData['mobileNumber']),
                                      tooltip: 'Call',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.map, color: AppTheme.primaryColor),
                                      onPressed: () => _openMap(memberData),
                                      tooltip: 'Map',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Positioned(

                        top: 10,
                        right: 30,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              final userId = memberData['_id'].toString();
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
                              color: (_tickedUsers.contains(memberData['_id'].toString())
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
                              _tickedUsers.contains(memberData['_id'].toString())
                                  ? Icons.verified
                                  : Icons.check_circle_outline,
                              size: 18,
                              color: _tickedUsers.contains(memberData['_id'].toString())
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      // Remove badge (Top-right) - Shows primary color, opens confirmation on click
                      Positioned(
                        top: 10,
                        right: 75,
                        child: GestureDetector(
                          onTap: () => _removeFromListWithConfirmation(memberData['_id'], myListProvider),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.95),
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
                            child: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Tick badge (Top-right) - Toggles strikethrough on username
                      // Distance display at bottom-right (same as home screen)
                      if (memberData != null && 
                          memberData['distance'] != null && 
                          memberData['distance'].toString().isNotEmpty)
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
                              '${memberData['distance']} km',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddressDisplay(Map<String, dynamic> memberData) {
    final address = memberData['currentAddress'] as Map<String, dynamic>?;
    if (address == null) return const SizedBox.shrink();

    final distance = memberData['distance'] != null 
        ? double.tryParse(memberData['distance'].toString()) 
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

    // Clean phone number - remove spaces, dashes, parentheses, and other non-digit characters
    // Keep only digits and + sign at the beginning
    String cleanedNumber = phoneNumber.trim();
    if (cleanedNumber.startsWith('+')) {
      cleanedNumber = '+' + cleanedNumber.substring(1).replaceAll(RegExp(r'[^\d]'), '');
    } else {
      cleanedNumber = cleanedNumber.replaceAll(RegExp(r'[^\d]'), '');
    }

    if (cleanedNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid phone number',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
      return;
    }

    final hasPermission = await PermissionService.requestPhonePermission(context);
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phone permission is required to make calls',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse('tel:$cleanedNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not make phone call. Please check if your device supports phone calls.',
                style: GoogleFonts.poppins(),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error making call: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openMap(Map<String, dynamic> memberData) async {
    if (memberData['latitude'] != null && memberData['longitude'] != null) {
      final lat = memberData['latitude'].toDouble();
      final lng = memberData['longitude'].toDouble();
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _removeFromListWithConfirmation(String memberId, MyListProvider myListProvider) async {
    final shouldRemove = await _showRemoveConfirmationSheet(context);
    if (shouldRemove == true) {
      final success = await myListProvider.removeFromMyList(memberId);
      if (mounted) {
        if (success) {
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
    }
  }

  Future<bool?> _showRemoveConfirmationSheet(BuildContext context) async {
    return await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to remove from the list?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Remove',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _exportToExcel() async {
    final myListProvider = Provider.of<MyListProvider>(context, listen: false);
    final members = myListProvider.members;

    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No data to export',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['My List'];

      // Headers
      sheetObject.appendRow([
        'Username',
        'Father Name',
        'Mobile Number',
        'Status',
      ]);

      // Data
      for (var member in members) {
        final memberData = member['memberId'];
        final isActive = member['isActive'] ?? true;
        sheetObject.appendRow([
          memberData['username'] ?? '',
          memberData['fatherName'] ?? '',
          memberData['mobileNumber'] ?? '',
          isActive ? 'Active' : 'Inactive',
        ]);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/myconnect_list_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      // Open immediately after download
      await OpenFilex.open(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Excel file exported and opened',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export failed: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }
}

