import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../utils/permission_service.dart';
import '../config/app_config.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class VideoDetailsScreen extends StatefulWidget {
  final String userId;
  const VideoDetailsScreen({super.key, required this.userId});

  @override
  State<VideoDetailsScreen> createState() => _VideoDetailsScreenState();
}

class _VideoDetailsScreenState extends State<VideoDetailsScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isAdmin = false;
  List<dynamic> _chats = [];
  bool _isLoadingChats = false;
  final GlobalKey _chatListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadUserDetails();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isAdmin = prefs.getBool('isAdmin') ?? false;
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userIsAdmin = authProvider.isAdmin() || isAdmin;
    
    if (!mounted) return;
    setState(() {
      _isAdmin = userIsAdmin;
    });
    
    if (_isAdmin) {
      _loadUserChats();
    }
  }

  Future<void> _loadUserDetails() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = await userProvider.getUserById(widget.userId);
    setState(() {
      _user = user;
      _isLoading = false;
    });
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadUserChats() async {
    setState(() => _isLoadingChats = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/user/${widget.userId}/chats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _chats = jsonDecode(response.body);
          _isLoadingChats = false;
        });
      } else {
        setState(() => _isLoadingChats = false);
      }
    } catch (e) {
      setState(() => _isLoadingChats = false);
    }
  }

  String _getOtherParticipantName(List? participants, String currentUserId) {
    if (participants == null || participants.isEmpty) {
      return 'Unknown';
    }
    try {
      final other = participants.firstWhere(
        (p) => p['_id']?.toString() != currentUserId,
        orElse: () => participants.first,
      );
      return other['username']?.toString() ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getOtherParticipantPhoto(List? participants, String currentUserId) {
    if (participants == null || participants.isEmpty) {
      return '';
    }
    try {
      final other = participants.firstWhere(
        (p) => p['_id']?.toString() != currentUserId,
        orElse: () => participants.first,
      );
      return other['profilePhoto']?.toString() ?? '';
    } catch (e) {
      return '';
    }
  }

  Color _getAccentColor(int index) {
    final colors = [
      const Color(0xFF6C63FF),
      const Color(0xFFFF6B9D),
      const Color(0xFF4ECDC4),
      const Color(0xFFFFA502),
      const Color(0xFF9B59B6),
    ];
    return colors[index % colors.length];
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'User not found',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'User Details',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          // Edit button for admin
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                // Navigate to profile screen in edit mode for this user
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: widget.userId, isAdminEdit: true),
                  ),
                );
                // Reload user details after editing
                if (result == true) {
                  _loadUserDetails();
                }
              },
              tooltip: 'Edit User',
            ),
          // Chat Icon
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () async {
              if (_isAdmin) {
                // For admin: scroll to chat list section
                if (_chatListKey.currentContext != null) {
                  await Scrollable.ensureVisible(
                    _chatListKey.currentContext!,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                } else {
                  // Fallback: show snackbar if chat list not available
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Chat list is shown below',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  }
                }
              } else {
                // For regular users: create 1-on-1 chat
                if (_user!['_id'] != null) {
                  final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                  await chatProvider.getOrCreateChat(_user!['_id'].toString());
                  if (chatProvider.currentChat != null && mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(chatId: chatProvider.currentChat!['_id']),
                      ),
                    );
                  }
                }
              }
            },
            tooltip: _isAdmin ? 'View Chats' : 'Chat',
          ),
          // Call Icon
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () async {
              if (_user!['mobileNumber'] != null) {
                final phoneNumber = _user!['mobileNumber'].toString().trim();
                if (phoneNumber.isEmpty) {
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

                final uri = Uri.parse('tel:$cleanedNumber');
                try {
                  final bool launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
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
                          'Could not open dialer. Please dial $cleanedNumber manually.',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  }
                }
              } else {
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
              }
            },
            tooltip: 'Call',
          ),
          // Map Icon
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () async {
              // Use current address coordinates if available, otherwise fall back to main coordinates
              double? lat;
              double? lon;
              
              final currentAddress = _user!['currentAddress'] as Map<String, dynamic>?;
              if (currentAddress != null && 
                  currentAddress['latitude'] != null && 
                  currentAddress['longitude'] != null) {
                // Use current address coordinates
                if (currentAddress['latitude'] is double) {
                  lat = currentAddress['latitude'] as double;
                } else if (currentAddress['latitude'] is int) {
                  lat = (currentAddress['latitude'] as int).toDouble();
                } else if (currentAddress['latitude'] is num) {
                  lat = (currentAddress['latitude'] as num).toDouble();
                } else {
                  lat = double.tryParse(currentAddress['latitude'].toString());
                }
                
                if (currentAddress['longitude'] is double) {
                  lon = currentAddress['longitude'] as double;
                } else if (currentAddress['longitude'] is int) {
                  lon = (currentAddress['longitude'] as int).toDouble();
                } else if (currentAddress['longitude'] is num) {
                  lon = (currentAddress['longitude'] as num).toDouble();
                } else {
                  lon = double.tryParse(currentAddress['longitude'].toString());
                }
              } else if (_user!['latitude'] != null && _user!['longitude'] != null) {
                // Fall back to main user coordinates
                if (_user!['latitude'] is double) {
                  lat = _user!['latitude'] as double;
                } else if (_user!['latitude'] is int) {
                  lat = (_user!['latitude'] as int).toDouble();
                } else if (_user!['latitude'] is num) {
                  lat = (_user!['latitude'] as num).toDouble();
                } else {
                  lat = double.tryParse(_user!['latitude'].toString());
                }
                
                if (_user!['longitude'] is double) {
                  lon = _user!['longitude'] as double;
                } else if (_user!['longitude'] is int) {
                  lon = (_user!['longitude'] as int).toDouble();
                } else if (_user!['longitude'] is num) {
                  lon = (_user!['longitude'] as num).toDouble();
                } else {
                  lon = double.tryParse(_user!['longitude'].toString());
                }
              }
              
              if (lat != null && lon != null) {
                // Open in Google Maps
                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Cannot open maps',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  }
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Location coordinates not available',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  );
                }
              }
            },
            tooltip: 'View on Map',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Photo
            CircleAvatar(
              radius: 50,
              backgroundImage: _user!['profilePhoto'] != null && _user!['profilePhoto'].toString().isNotEmpty
                  ? NetworkImage(_user!['profilePhoto'].toString())
                  : null,
              child: _user!['profilePhoto'] == null || _user!['profilePhoto'].toString().isEmpty
                  ? const Icon(Icons.person, size: 100)
                  : null,
            ),
            const SizedBox(height: 16),
            
            // Username below profile photo
            Text(
              _user!['username']?.toString() ?? 'N/A',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
            ),
            ),
            const SizedBox(height: 24),
            
            // Mobile Number
            _buildInfoCard('Contact Information', [
              _buildInfoRow('Mobile Number', _user!['mobileNumber']?.toString() ?? 'N/A'),
              if (_user!['secondaryMobileNumber'] != null && _user!['secondaryMobileNumber'].toString().isNotEmpty)
                _buildInfoRow('Secondary Mobile Number', _user!['secondaryMobileNumber']?.toString() ?? 'N/A'),
            ]),
            
            const SizedBox(height: 16),
            
            // Highest Qualification
            _buildInfoCard('Qualification', [
              _buildInfoRow('Highest Qualification', _user!['highestQualification']?.toString() ?? 'N/A'),
            ]),
            
            const SizedBox(height: 16),
            
            // Family Information (Father Name, Grandfather Name)
            _buildInfoCard('Family Information', [
              _buildInfoRow('Father Name', _user!['fatherName']?.toString() ?? 'N/A'),
              _buildInfoRow('Grandfather Name', _user!['grandfatherName']?.toString() ?? 'N/A'),
            ]),
            
            const SizedBox(height: 16),
            
            // Address Information
            _buildInfoCard('Address Information', [
              _buildAddressSection('Current Address', _user!['currentAddress']),
              // Map for current address
              if (_user!['currentAddress'] != null && 
                  _user!['currentAddress']['latitude'] != null && 
                  _user!['currentAddress']['longitude'] != null)
                  Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildAddressMap(_user!['currentAddress'], 'Current Address Location'),
                        ),
              const SizedBox(height: 16),
              _buildAddressSection('Native Address', _user!['nativeAddress']),
              // Map for native address
              if (_user!['nativeAddress'] != null && 
                  _user!['nativeAddress']['latitude'] != null && 
                  _user!['nativeAddress']['longitude'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildAddressMap(_user!['nativeAddress'], 'Native Address Location'),
                  ),
              ]),
            
              const SizedBox(height: 16),
            
            // Professional Details (changed from Working Details)
            _buildProfessionalDetailsCard(),
            
            const SizedBox(height: 16),
            
            // Additional Personal Information
            _buildInfoCard('Additional Information', [
              if (_user!['emailId'] != null && _user!['emailId'].toString().isNotEmpty)
                _buildInfoRow('Email ID', _user!['emailId']?.toString() ?? 'N/A'),
              if (_user!['dateOfBirth'] != null)
                _buildInfoRow('Date of Birth', _formatDate(_user!['dateOfBirth'])),
              if (_user!['bloodGroup'] != null && _user!['bloodGroup'].toString().isNotEmpty)
                _buildInfoRow('Blood Group', _user!['bloodGroup']?.toString() ?? 'N/A'),
            ]),
            
            const SizedBox(height: 16),
            
            // Education Information
            if (_user!['hasEducation'] == true) ...[
              _buildInfoCard('Education Information', [
                if (_user!['college'] != null && _user!['college'].toString().isNotEmpty)
                  _buildInfoRow('College', _user!['college']?.toString() ?? 'N/A'),
                if (_user!['course'] != null && _user!['course'].toString().isNotEmpty)
                  _buildInfoRow('Course', _user!['course']?.toString() ?? 'N/A'),
                if (_user!['startYear'] != null && _user!['startYear'].toString().isNotEmpty)
                  _buildInfoRow('Start Year', _user!['startYear']?.toString() ?? 'N/A'),
                if (_user!['endYear'] != null && _user!['endYear'].toString().isNotEmpty)
                  _buildInfoRow('End Year', _user!['endYear']?.toString() ?? 'N/A'),
                if (_user!['yearOfCompletion'] != null && _user!['yearOfCompletion'].toString().isNotEmpty)
                  _buildInfoRow('Year of Completion', _user!['yearOfCompletion']?.toString() ?? 'N/A'),
                if (_user!['extraDegrees'] != null && (_user!['extraDegrees'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Extra Degrees',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  ...(_user!['extraDegrees'] as List).map((degree) => Padding(
                    padding: const EdgeInsets.only(top: 4, left: 16),
                    child: Text(
                      '${degree['degree'] ?? ''} - ${degree['college'] ?? ''} (${degree['year'] ?? ''})',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                    ),
                  )).toList(),
                ],
              ]),
              const SizedBox(height: 16),
            ],
            
            // Family Photo
            if (_user!['familyPhoto'] != null && _user!['familyPhoto'].toString().isNotEmpty) ...[
              _buildInfoCard('Family Photo', [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _user!['familyPhoto'].toString(),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey[300],
                          child: const Icon(Icons.photo_library, size: 48),
                        );
                      },
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],
            
            // Account Information
            _buildInfoCard('Account Information', [
              _buildInfoRow('Status', _getStatusText(_user!['status'])),
            ]),
            
            // Chat List (Only for Admin)
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              _buildChatListCard(),
            ],
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChatListCard() {
    return Container(
      key: _chatListKey,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassyDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chat List',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoadingChats)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_chats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No chats found',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            ...List.generate(
              _chats.length,
              (index) {
                final chat = _chats[index];
                final participants = chat['participants'] as List?;
                if (participants == null || participants.isEmpty) {
                  return const SizedBox.shrink();
                }
                final otherName = _getOtherParticipantName(participants, widget.userId);
                final otherPhoto = _getOtherParticipantPhoto(participants, widget.userId);
                final accentColor = _getAccentColor(index);

                return GestureDetector(
                  onTap: () {
                    final chatId = chat['_id']?.toString();
                    if (chatId == null || chatId.isEmpty) {
                      return;
                    }
                    // Navigate to chat screen in read-only mode for admin viewing from details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chatId,
                          isReadOnly: true,
                          chatName: '$otherName & ${_user!['username'] ?? 'User'}',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: otherPhoto.isNotEmpty
                              ? NetworkImage(otherPhoto)
                              : null,
                          child: otherPhoto.isEmpty
                              ? const Icon(Icons.person, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$otherName & ${_user!['username'] ?? 'User'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                chat['lastMessage']?.toString() ?? 'No messages yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatTime(chat['lastMessageTime']),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassyDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(dynamic status) {
    if (status == null) return 'N/A';
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status.toString();
    }
  }

  Widget _buildAddressSection(String title, Map<String, dynamic>? address) {
    if (address == null || address.isEmpty) {
      return _buildInfoRow(title, 'N/A');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title:',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        if (address['address'] != null && address['address'].toString().isNotEmpty)
          Text(
            address['address'].toString(),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        if (address['state'] != null && address['state'].toString().isNotEmpty)
          Text(
            'State: ${address['state']}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        if (address['pincode'] != null && address['pincode'].toString().isNotEmpty)
          Text(
            'Pincode: ${address['pincode']}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
      ],
    );
  }

  Widget _buildProfessionalDetailsCard() {
    final workingDetails = _user!['workingDetails'] as Map<String, dynamic>?;
    final isWorking = workingDetails?['isWorking'] == true;
    
    if (!isWorking || workingDetails == null) {
      return _buildInfoCard('Professional Details', [
        _buildInfoRow('Professional Status', 'Not Available'),
      ]);
    }

    final professionType = workingDetails['professionType']?.toString() ?? '';
    
    List<Widget> professionalDetails = [];
    
    // Check profession type and display accordingly
    if (professionType == 'student') {
      professionalDetails.addAll([
        _buildInfoRow('Profession Type', 'Student'),
        if (workingDetails['collegeName'] != null && workingDetails['collegeName'].toString().isNotEmpty)
          _buildInfoRow('College Name', workingDetails['collegeName'].toString()),
        if (workingDetails['studentYear'] != null && workingDetails['studentYear'].toString().isNotEmpty)
          _buildInfoRow('Year', workingDetails['studentYear'].toString()),
        if (workingDetails['department'] != null && workingDetails['department'].toString().isNotEmpty)
          _buildInfoRow('Department', workingDetails['department'].toString()),
      ]);
    } else if (professionType == 'business') {
      // Get multiple business addresses
      List<String> businessAddresses = [];
      if (workingDetails['businessAddresses'] != null && workingDetails['businessAddresses'] is List) {
        businessAddresses = (workingDetails['businessAddresses'] as List)
            .map((addr) => addr.toString())
            .where((addr) => addr.isNotEmpty)
            .toList();
      }
      // Fallback to single address for backward compatibility
      if (businessAddresses.isEmpty) {
        final singleAddr = workingDetails['businessAddress']?.toString() ?? 
                          workingDetails['organizationAddress']?.toString() ?? '';
        if (singleAddr.isNotEmpty) {
          businessAddresses = [singleAddr];
        }
      }
      
      professionalDetails.addAll([
        _buildInfoRow('Profession Type', 'Business'),
        if (workingDetails['businessType'] != null && workingDetails['businessType'].toString().isNotEmpty)
          _buildInfoRow('Business Type', workingDetails['businessType'].toString()),
        if (workingDetails['businessName'] != null && workingDetails['businessName'].toString().isNotEmpty)
          _buildInfoRow('Business Name', workingDetails['businessName'].toString()),
      ]);
      
      // Display multiple business addresses
      if (businessAddresses.isNotEmpty) {
        if (businessAddresses.length == 1) {
          professionalDetails.add(_buildInfoRow('Business Address', businessAddresses[0]));
        } else {
          professionalDetails.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Addresses:',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...businessAddresses.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(
                        '${entry.key + 1}. ${entry.value}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        }
      }
      
      professionalDetails.addAll([
        if (workingDetails['organizationName'] != null && workingDetails['organizationName'].toString().isNotEmpty)
          _buildInfoRow('Organization Name', workingDetails['organizationName'].toString()),
        if (workingDetails['organizationNumber'] != null && workingDetails['organizationNumber'].toString().isNotEmpty)
          _buildInfoRow('Organization Number', workingDetails['organizationNumber'].toString()),
      ]);
    } else if (professionType == 'job') {
      professionalDetails.addAll([
        _buildInfoRow('Profession Type', 'Job'),
        if (workingDetails['companyName'] != null && workingDetails['companyName'].toString().isNotEmpty)
          _buildInfoRow('Company Name', workingDetails['companyName'].toString()),
        if (workingDetails['position'] != null && workingDetails['position'].toString().isNotEmpty)
          _buildInfoRow('Position', workingDetails['position'].toString()),
        if (workingDetails['workingMeans'] != null && workingDetails['workingMeans'].toString().isNotEmpty)
          _buildInfoRow('Working Type', workingDetails['workingMeans'].toString()),
        if (workingDetails['totalYearsExperience'] != null)
          _buildInfoRow('Years of Experience', '${workingDetails['totalYearsExperience']} years'),
        if (workingDetails['designation'] != null && workingDetails['designation'].toString().isNotEmpty)
          _buildInfoRow('Designation', workingDetails['designation'].toString()),
        if (workingDetails['organizationName'] != null && workingDetails['organizationName'].toString().isNotEmpty)
          _buildInfoRow('Organization Name', workingDetails['organizationName'].toString()),
        if (workingDetails['organizationNumber'] != null && workingDetails['organizationNumber'].toString().isNotEmpty)
          _buildInfoRow('Organization Number', workingDetails['organizationNumber'].toString()),
        if (workingDetails['organizationAddress'] != null && workingDetails['organizationAddress'].toString().isNotEmpty)
          _buildInfoRow('Organization Address', workingDetails['organizationAddress'].toString()),
      ]);
    } else {
      // Fallback for old data or unknown type
      professionalDetails.add(_buildInfoRow('Professional Status', 'Not Specified'));
    }
    
    return _buildInfoCard('Professional Details', professionalDetails);
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      DateTime dateTime;
      if (date is String) {
        dateTime = DateTime.parse(date);
      } else if (date is DateTime) {
        dateTime = date;
      } else {
        return date.toString();
      }
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildAddressMap(Map<String, dynamic> address, String title) {
    double? lat;
    double? lon;
    
    // Handle different number types from backend
    if (address['latitude'] != null) {
      if (address['latitude'] is double) {
        lat = address['latitude'] as double;
      } else if (address['latitude'] is int) {
        lat = (address['latitude'] as int).toDouble();
      } else if (address['latitude'] is num) {
        lat = (address['latitude'] as num).toDouble();
      } else {
        lat = double.tryParse(address['latitude'].toString());
      }
    }
    
    if (address['longitude'] != null) {
      if (address['longitude'] is double) {
        lon = address['longitude'] as double;
      } else if (address['longitude'] is int) {
        lon = (address['longitude'] as int).toDouble();
      } else if (address['longitude'] is num) {
        lon = (address['longitude'] as num).toDouble();
      } else {
        lon = double.tryParse(address['longitude'].toString());
      }
    }
    
    if (lat == null || lon == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lon),
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: MarkerId('${title}_location'),
              position: LatLng(lat, lon),
              infoWindow: InfoWindow(
                title: title,
                snippet: address['address']?.toString() ?? '',
              ),
            ),
          },
          mapType: MapType.normal,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}

