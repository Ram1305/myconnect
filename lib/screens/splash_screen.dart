import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';
import 'package:in_app_update/in_app_update.dart';
import 'dart:convert';
import 'dart:io';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'dashboard.dart';
import 'status_screen.dart';
import 'chat_screen.dart';
import 'video_details_screen.dart';
import 'signup_screen.dart';
import 'add_event_screen.dart';
import 'add_blog_screen.dart';
import 'admin_banner_list_screen.dart';
import 'gallery_screen.dart';
import 'temple_list_screen.dart';
import 'admin_list_view_screen.dart';
import '../utils/theme.dart';
import '../config/app_config.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  int _tapCount = 0;
  DateTime? _lastTapTime;
  bool _isAdminDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _checkForAppUpdate();
    _requestNotificationPermission();
    _checkAuthStatus();
  }

  Future<void> _checkForAppUpdate() async {
    // Google Play in-app updates are Android-only
    if (!Platform.isAndroid) return;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint('⚠️ In-app update check failed: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    // Check if permission was already requested
    final hasBeenRequested = await NotificationService.hasPermissionBeenRequested();
    
    if (!hasBeenRequested) {
      // Request permission on first launch
      final granted = await NotificationService.requestPermission();
      if (granted) {
        await NotificationService.markPermissionAsRequested();
        // Get and store FCM token
        final token = await NotificationService.initialize();
        if (token != null) {
          debugPrint('✅ FCM token obtained: $token');
        }
      }
    } else {
      // Just initialize if permission was already requested
      await NotificationService.initialize();
    }
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Don't navigate if admin dialog is open
    if (_isAdminDialogOpen) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final status = prefs.getString('status');

    if (!mounted) return;
    
    // Check again after async operations
    if (_isAdminDialogOpen) return;
    
    if (token != null && status != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.getCurrentUser();

      if (!mounted) return;
      
      // Check again after async operations
      if (_isAdminDialogOpen) return;
      
      // Check if user is admin
      final isAdmin = prefs.getBool('isAdmin') ?? false;
      
      // Also check from auth provider user data
      final userIsAdmin = authProvider.isAdmin() || isAdmin;
      
      if (userIsAdmin) {
        // Navigate to admin panel
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminPanel()),
        );
      } else if (status == 'approved') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const Dashboard()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const StatusScreen()),
        );
      }
    } else {
      if (!mounted) return;
      
      // Check again before navigation
      if (_isAdminDialogOpen) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _handleTripleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(seconds: 2)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;

    if (_tapCount >= 3) {
      _tapCount = 0;
      _showAdminLogin();
    }
  }

  void _showAdminLogin() {
    setState(() {
      _isAdminDialogOpen = true;
    });
    
    showDialog(
      context: context,
      builder: (context) => const AdminLoginDialog(),
    ).then((_) {
      // Reset flag when dialog closes
      if (mounted) {
        setState(() {
          _isAdminDialogOpen = false;
        });
        // If dialog was closed without login, continue with normal flow
        _checkAuthStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _handleTripleTap,
        child: Container(
          decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
           Colors.white,
              Colors.white,
            ],
          ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                // const SizedBox(height: 30),

              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: AppTheme.glassyDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Admin / Super Admin Login',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _mobileController,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: Text(
                      'Login',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _mobileController.text,
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && authProvider.isAdmin()) {
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminPanel()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invalid admin credentials',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Admin Panel Screen with Card-based Layout
class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;
  int _chatCount = 0;
  int _cannotLoginCount = 0;
  int _eventsCount = 0;
  int _blogsCount = 0;
  int _templesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      
      // Load pending count
      final pendingResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/pending'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (pendingResponse.statusCode == 200) {
        _pendingCount = (jsonDecode(pendingResponse.body) as List).length;
      }

      // Load approved count
      final approvedResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/approved'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (approvedResponse.statusCode == 200) {
        _approvedCount = (jsonDecode(approvedResponse.body) as List).length;
      }

      // Load rejected count
      final rejectedResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/rejected'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (rejectedResponse.statusCode == 200) {
        _rejectedCount = (jsonDecode(rejectedResponse.body) as List).length;
      }

      // Load chat count
      final chatResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/chats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (chatResponse.statusCode == 200) {
        _chatCount = (jsonDecode(chatResponse.body) as List).length;
      }

      // Load cannot login count
      final cannotLoginResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/cannot-login'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (cannotLoginResponse.statusCode == 200) {
        _cannotLoginCount = (jsonDecode(cannotLoginResponse.body) as List).length;
      }

      // Load events count
      final eventsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (eventsResponse.statusCode == 200) {
        _eventsCount = (jsonDecode(eventsResponse.body) as List).length;
      }

      // Load blogs count
      final blogsResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/blogs'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (blogsResponse.statusCode == 200) {
        _blogsCount = (jsonDecode(blogsResponse.body) as List).length;
      }

      // Load temples count
      final templesResponse = await http.get(
        Uri.parse('${AppConfig.baseUrl}/temples'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (templesResponse.statusCode == 200) {
        final data = jsonDecode(templesResponse.body);
        _templesCount = (data['temples'] as List).length;
      }
    } catch (e) {
      // Handle error
    }
    setState(() => _isLoading = false);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isSuperAdmin = authProvider.isSuperAdmin();
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Text(
              isSuperAdmin ? 'Super Admin Dashboard' : 'Admin Panel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: _handleLogout,
              ),
            ],
          ),
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.0,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          if (isSuperAdmin)
                            _buildCard(
                              context,
                              title: 'Admin View',
                              subtitle: 'View Admins',
                              count: -1,
                              icon: Icons.admin_panel_settings,
                              color: Colors.indigo,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminListViewScreen(),
                                  ),
                                ).then((_) => _loadCounts());
                              },
                            ),
                          _buildCard(
                            context,
                            title: 'Add User',
                            subtitle: 'Create New User',
                            count: -1, // Use -1 to hide count for action cards
                            icon: Icons.person_add,
                            color: AppTheme.primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(adminCreated: true),
                                ),
                              );
                            },
                          ),
                  // _buildCard(
                  //   context,
                  //       title: 'User Allow Login',
                  //       subtitle: 'Pending Users',
                  //   count: _pendingCount,
                  //   icon: Icons.login,
                  //   color: Colors.orange,
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (_) => const AdminUsersListScreen(status: 'pending'),
                  //       ),
                  //     ).then((_) => _loadCounts());
                  //   },
                  // ),
                  _buildCard(
                    context,
                        title: 'Users Cannot Login',
                        subtitle: 'Token Issues',
                    count: _cannotLoginCount,
                    icon: Icons.block,
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersListScreen(status: 'cannot-login'),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'Pending',
                        subtitle: 'Family Members',
                    count: _pendingCount,
                    icon: Icons.pending_actions,
                        svgPath: 'assets/pending.svg',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersListScreen(status: 'pending'),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'Approved',
                        subtitle: 'Family Members',
                    count: _approvedCount,
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersListScreen(status: 'approved'),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'Rejected',
                        subtitle: 'Family Members',
                    count: _rejectedCount,
                    icon: Icons.cancel,
                        svgPath: 'assets/rejected.svg',
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersListScreen(status: 'rejected'),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'Chats',
                        subtitle: 'All Conversations',
                    count: _chatCount,
                    icon: Icons.chat,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminChatListScreen(),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'Add Event',
                        subtitle: 'Create New Event',
                    count: -1, // Use -1 to hide count for action cards
                    icon: Icons.event,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddEventScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'Add Blog',
                        subtitle: 'Create New Blog',
                    count: -1, // Use -1 to hide count for action cards
                    icon: Icons.article,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddBlogScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'List Events',
                        subtitle: 'Manage Events',
                    count: _eventsCount,
                    icon: Icons.event_note,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminEventsListScreen(),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'List Blogs',
                        subtitle: 'Manage Blogs',
                    count: _blogsCount,
                    icon: Icons.article,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminBlogsListScreen(),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'View Banner List',
                        subtitle: 'Manage Banners',
                    count: -1, // Use -1 to hide count for action cards
                    icon: Icons.image,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminBannerListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCard(
                    context,
                        title: 'Gallery',
                        subtitle: 'Add / Manage Photos',
                    count: -1,
                    icon: Icons.photo_library,
                    color: Colors.brown,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GalleryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildCard(
                    context,
                    title: 'Temples',
                    subtitle: 'Manage Temples',
                    count: _templesCount,
                    icon: Icons.temple_hindu,
                    color: Colors.deepOrange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TempleListScreen(),
                        ),
                      ).then((_) => _loadCounts());
                    },
                  ),
                ],
                  ),
                ),
              ),
            ),
        );
      },
    );
  }

}

// Admin Add User Tab
class AdminAddUserTab extends StatefulWidget {
  const AdminAddUserTab({super.key});

  @override
  State<AdminAddUserTab> createState() => _AdminAddUserTabState();
}

class _AdminAddUserTabState extends State<AdminAddUserTab> {
  // This will navigate to signup screen with admin flag
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'Add New User',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Click the button below to add a new user. Users created by admin will be automatically approved.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SignupScreen(adminCreated: true),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: Text(
                'Add User',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Admin User Allow Login Tab
class AdminUserAllowLoginTab extends StatefulWidget {
  const AdminUserAllowLoginTab({super.key});

  @override
  State<AdminUserAllowLoginTab> createState() => _AdminUserAllowLoginTabState();
}

class _AdminUserAllowLoginTabState extends State<AdminUserAllowLoginTab> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/pending${_searchController.text.isNotEmpty ? '?search=${_searchController.text}' : ''}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveUser(String id) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/admin/approve/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User approved', style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(String id) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/admin/reject/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User rejected', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

    final uri = Uri.parse('tel:$cleanedNumber');
    try {
      // Use externalNonBrowserApplication for dialer - this is the best mode for phone dialer on Android
      await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (e) {
      // If externalNonBrowserApplication fails, try platformDefault as fallback
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (e2) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _loadUsers();
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => _loadUsers(),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? Center(
                      child: Text(
                        'No pending users',
                        style: GoogleFonts.poppins(),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['profilePhoto'] != null && user['profilePhoto'].isNotEmpty
                                  ? NetworkImage(user['profilePhoto'])
                                  : null,
                              child: user['profilePhoto'] == null || user['profilePhoto'].isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              user['username'] ?? '',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _makeCall(user['mobileNumber']),
                                  child: Text(
                                    user['mobileNumber'] ?? '',
                                    style: GoogleFonts.poppins(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                if (user['fatherName'] != null && user['fatherName'].toString().isNotEmpty)
                                  Text(
                                    user['fatherName'] ?? '',
                                    style: GoogleFonts.poppins(),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _approveUser(user['_id']),
                                  tooltip: 'Approve',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _rejectUser(user['_id']),
                                  tooltip: 'Reject',
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}


  Widget _buildCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required int count,
    required IconData icon,
    String? svgPath,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
              icon,
                      size: 36,
              color: color,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Only show count if it's not -1 (action cards don't show count)
            if (count >= 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

// Admin Users List Screen (using home screen UI)
class AdminUsersListScreen extends StatefulWidget {
  final String status;
  const AdminUsersListScreen({super.key, required this.status});

  @override
  State<AdminUsersListScreen> createState() => _AdminUsersListScreenState();
}

class _AdminUsersListScreenState extends State<AdminUsersListScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _users = [];
  bool _isLoading = true;
  final Set<String> _tickedUsers = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      String endpoint;
      
      if (widget.status == 'cannot-login') {
        endpoint = '${AppConfig.baseUrl}/admin/cannot-login';
      } else {
        endpoint = '${AppConfig.baseUrl}/admin/${widget.status}';
      }
      
      if (_searchController.text.isNotEmpty) {
        endpoint += '?search=${_searchController.text}';
      }
      
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
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

    final uri = Uri.parse('tel:$cleanedNumber');
    try {
      // Use externalNonBrowserApplication for dialer - this is the best mode for phone dialer on Android
      await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (e) {
      // If externalNonBrowserApplication fails, try platformDefault as fallback
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (e2) {
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

  Future<void> _approveUser(String id) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/admin/approve/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User approved',
                  style: GoogleFonts.poppins(),
                ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(String id) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/admin/reject/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User rejected',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _allowUserLogin(String id) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/admin/allow-login/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User can now login',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeUserStatus(String userId, String newStatus) async {
    try {
      final token = await _getToken();
      String endpoint = '';
      String successMessage = '';
      
      switch (newStatus) {
        case 'approved':
          endpoint = '${AppConfig.baseUrl}/admin/approve/$userId';
          successMessage = 'User approved';
          break;
        case 'rejected':
          endpoint = '${AppConfig.baseUrl}/admin/reject/$userId';
          successMessage = 'User rejected';
          break;
        case 'pending':
          endpoint = '${AppConfig.baseUrl}/admin/pending/$userId';
          successMessage = 'User set to pending';
          break;
      }

      final response = await http.put(
        Uri.parse(endpoint),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      Map<String, dynamic>? responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        responseBody = null;
      }
      
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          Navigator.pop(context); // Close modal
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                successMessage,
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: newStatus == 'approved' 
                  ? Colors.green 
                  : newStatus == 'rejected' 
                      ? Colors.red 
                      : Colors.orange,
            ),
          );
        }
      } else {
        // Handle non-200 status codes
        if (mounted) {
          Navigator.pop(context); // Close modal even on error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                responseBody?['message'] ?? 'Failed to update status. Status code: ${response.statusCode}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close modal on exception
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusChangeModal(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Change Status',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              user['username'] ?? 'User',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.pending_actions, color: Colors.orange),
              title: Text(
                'Set to Pending',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              onTap: () => _changeUserStatus(user['_id'], 'pending'),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                'Approve',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              onTap: () => _changeUserStatus(user['_id'], 'approved'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: Text(
                'Reject',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              onTap: () => _changeUserStatus(user['_id'], 'rejected'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusTitle = widget.status == 'pending'
        ? 'Pending Family Members'
        : widget.status == 'approved'
            ? 'Approved Family Members'
            : widget.status == 'cannot-login'
                ? 'Users Cannot Login'
                : 'Rejected Family Members';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          statusTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download as Excel',
            onPressed: _downloadUsersExcel,
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
                hintText: 'Search...',
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? Center(
                child: Text(
                          'No users found',
                  style: GoogleFonts.poppins(),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => VideoDetailsScreen(userId: user['_id']),
                                ),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  padding: const EdgeInsets.only(right: 16, bottom: 16, left: 10),
                                  decoration: AppTheme.glassyDecoration(),
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
                                                decorationColor: AppTheme.primaryColor,
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
            ],
          ),
        ),
                                      Column(
          children: [
                                          const SizedBox(height: 25),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // IconButton(
                                              //   icon: Icon(Icons.info_outline, color: AppTheme.primaryColor),
                                              //   onPressed: () {
                                              //     Navigator.push(
                                              //       context,
                                              //       MaterialPageRoute(
                                              //         builder: (_) => VideoDetailsScreen(userId: user['_id']),
                                              //       ),
                                              //     );
                                              //   },
                                              //   tooltip: 'Details',
                                              // ),
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
                                              if (widget.status == 'approved')
                                                IconButton(
                                                  icon: Icon(Icons.chat, color: AppTheme.primaryColor),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => AdminUserChatsScreen(userId: user['_id'], userName: user['username'] ?? 'User'),
                                                      ),
                                                    );
                                                  },
                                                  tooltip: 'View Chats',
                                                ),
                                              if (widget.status == 'cannot-login')
                                                IconButton(
                                                  icon: Icon(Icons.check_circle, color: Colors.green),
                                                  onPressed: () => _allowUserLogin(user['_id']),
                                                  tooltip: 'Allow Login',
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Tick badge (Top-right) - Opens status change modal
                                Positioned(
                                  top: 10,
                                  right: 30,
                                  child: GestureDetector(
                                    onTap: () {
                                      _showStatusChangeModal(user);
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (_tickedUsers.contains(user['_id'].toString())
                                                ? AppTheme.primaryColor
                                                : Colors.white)
                                            .withValues(alpha: 0.95),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(50),
                                          bottomRight: Radius.circular(50),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
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
                                // Approve/Reject badges for pending users
                                if (widget.status == 'pending')
                                  Positioned(
                                    top: 10,
                                    right: 75,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _approveUser(user['_id']),
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.95),
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(50),
                                                bottomRight: Radius.circular(50),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        GestureDetector(
                                          onTap: () => _rejectUser(user['_id']),
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.95),
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(50),
                                                bottomRight: Radius.circular(50),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUsersExcel() async {
    if (_users.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No users to export',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final token = await _getToken();
      final statusParam = widget.status != 'all' ? '?status=${widget.status}' : '';
      
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/export/users$statusParam'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Get download directory
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'myconnect_users_${widget.status}_$timestamp.xlsx';
        final filePath = '${directory.path}/$filename';
        
        // Save file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        // Open file
        await OpenFilex.open(filePath);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Excel file downloaded successfully\nSaved at: $filePath',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        // Open file (optional - user can access it from file manager)
        try {
          await OpenFilex.open(filePath);
        } catch (e) {
          // If opening fails, file is still saved locally
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to download Excel file',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error downloading file: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Old Admin Users List (kept for backward compatibility if needed)
class AdminUsersList extends StatefulWidget {
  final String status;
  const AdminUsersList({super.key, required this.status});

  @override
  State<AdminUsersList> createState() => _AdminUsersListState();
}

class _AdminUsersListState extends State<AdminUsersList> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/${widget.status}'),
        headers: {
          'Authorization': 'Bearer ${await _getToken()}',
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
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

    final uri = Uri.parse('tel:$cleanedNumber');
    try {
      // Use externalNonBrowserApplication for dialer - this is the best mode for phone dialer on Android
      await launchUrl(
        uri,
        mode: LaunchMode.externalNonBrowserApplication,
      );
    } catch (e) {
      // If externalNonBrowserApplication fails, try platformDefault as fallback
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } catch (e2) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassyDecoration(),
          child: ListTile(
            leading: Container(
              decoration: AppTheme.circularBorderDecoration(),
              child: CircleAvatar(
                backgroundImage: user['profilePhoto'] != null && user['profilePhoto'].isNotEmpty
                    ? NetworkImage(user['profilePhoto'])
                    : null,
                child: user['profilePhoto'] == null || user['profilePhoto'].isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
            ),
            title: Text(
              user['username'] ?? '',
              style: GoogleFonts.poppins(),
            ),
            subtitle: Text(
              '${user['mobileNumber'] ?? ''}\n${user['fatherName'] ?? ''}',
              style: GoogleFonts.poppins(),
            ),
            trailing: widget.status == 'pending'
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approveUser(user['_id']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _rejectUser(user['_id']),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }

  Future<void> _approveUser(String id) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/admin/approve/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User approved',
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
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _rejectUser(String id) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse('${AppConfig.baseUrl}/admin/reject/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        _loadUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User rejected',
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
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }
}

// Admin User Chats Screen - View-only chat list for a specific user
class AdminUserChatsScreen extends StatefulWidget {
  final String userId;
  final String userName;
  
  const AdminUserChatsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<AdminUserChatsScreen> createState() => _AdminUserChatsScreenState();
}

class _AdminUserChatsScreenState extends State<AdminUserChatsScreen> {
  List<dynamic> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserChats();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadUserChats() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/user/${widget.userId}/chats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _chats = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getOtherParticipantName(List participants, String currentUserId) {
    if (participants.isEmpty) {
      return 'Unknown';
    }
    try {
      final other = participants.firstWhere(
        (p) => p['_id'].toString() != currentUserId,
        orElse: () => participants.first,
      );
      return other['username'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getOtherParticipantPhoto(List participants, String currentUserId) {
    if (participants.isEmpty) {
      return '';
    }
    try {
      final other = participants.firstWhere(
        (p) => p['_id'].toString() != currentUserId,
        orElse: () => participants.first,
      );
      return other['profilePhoto'] ?? '';
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.userName}\'s Chats',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Text(
                    'No chats found',
                    style: GoogleFonts.poppins(),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final participants = chat['participants'] as List;
                    final otherName = _getOtherParticipantName(participants, widget.userId);
                    final otherPhoto = _getOtherParticipantPhoto(participants, widget.userId);
                    final accentColor = _getAccentColor(index);

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminViewChatScreen(
                              chatId: chat['_id'],
                              chatName: '$otherName & ${widget.userName}',
                              accentColor: accentColor,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundImage: otherPhoto.isNotEmpty
                                  ? NetworkImage(otherPhoto)
                                  : null,
                              child: otherPhoto.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$otherName & ${widget.userName}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1A1D29),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.1),
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
                  },
                ),
    );
  }
}

// Admin View Chat Screen - View-only chat messages
class AdminViewChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final Color accentColor;

  const AdminViewChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.accentColor,
  });

  @override
  State<AdminViewChatScreen> createState() => _AdminViewChatScreenState();
}

class _AdminViewChatScreenState extends State<AdminViewChatScreen> {
  Map<String, dynamic>? _chat;
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedMessages = {};

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadChat() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      // Use admin route to get chat messages (no participant check required)
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/chat/${widget.chatId}/messages'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final chatData = jsonDecode(response.body);
        debugPrint('🔵 [ADMIN CHAT] Loaded chat data: ${chatData['_id']}');
        debugPrint('🔵 [ADMIN CHAT] Messages count: ${chatData['messages']?.length ?? 0}');
        debugPrint('🔵 [ADMIN CHAT] Messages type: ${chatData['messages'].runtimeType}');
        setState(() {
          _chat = chatData;
          _isLoading = false;
        });
      } else {
        debugPrint('❌ [ADMIN CHAT] Failed to load: ${response.statusCode} - ${response.body}');
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load chat: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [ADMIN CHAT] Error: ${e.toString()}');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteChat() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Chat',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this chat?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.chatName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone. All messages will be permanently deleted.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/admin/chat/${widget.chatId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Chat deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to previous screen
          Navigator.pop(context);
        }
      } else {
        final errorBody = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorBody['message'] ?? 'Failed to delete chat',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting chat: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMessages.clear();
      }
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
      } else {
        _selectedMessages.add(messageId);
      }
      if (_selectedMessages.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _selectAllMessages() {
    if (_chat == null) return;
    setState(() {
      final messages = _chat!['messages'] as List;
      if (_selectedMessages.length == messages.length) {
        _selectedMessages.clear();
        _isSelectionMode = false;
      } else {
        _selectedMessages.clear();
        for (var message in messages) {
          final messageId = message['_id']?.toString() ?? '';
          if (messageId.isNotEmpty) {
            _selectedMessages.add(messageId);
          }
        }
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;

    final count = _selectedMessages.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Messages',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete $count selected message(s)?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      final token = await _getToken();
      
      // Try to delete messages using the chat messages endpoint
      // If backend doesn't support this, you'll need to add an endpoint like:
      // DELETE /admin/chat/:chatId/messages with body: { messageIds: [...] }
      final messageIds = _selectedMessages.toList();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/admin/chat/${widget.chatId}/messages'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'messageIds': messageIds}),
      );

      if (response.statusCode == 200 || response.statusCode == 404) {
        // If endpoint doesn't exist (404), we'll still update UI
        // In production, you should create the backend endpoint
        setState(() {
          _selectedMessages.clear();
          _isSelectionMode = false;
        });
        _loadChat(); // Reload to refresh the view
        
        if (mounted) {
          if (response.statusCode == 404) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Message delete endpoint not available. Please implement backend endpoint.',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$count message(s) deleted successfully',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        final errorBody = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorBody['message'] ?? 'Failed to delete messages',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // If endpoint doesn't exist, show helpful message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message delete endpoint not implemented. Please add DELETE /admin/chat/:chatId/messages endpoint.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatMessageTime(dynamic time) {
    if (time == null) return '';
    try {
      final dateTime = DateTime.parse(time.toString());
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
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
              widget.accentColor,
              widget.accentColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isSelectionMode ? Icons.close : Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          if (_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = false;
                              _selectedMessages.clear();
                            });
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSelectionMode
                                ? '${_selectedMessages.length} selected'
                                : widget.chatName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (!_isSelectionMode)
                            Text(
                              'View Only - Admin',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (_isSelectionMode)
                            Text(
                              'Long press messages to select',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isSelectionMode) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _selectedMessages.length == (_chat?['messages'] as List?)?.length
                                ? Icons.deselect
                                : Icons.select_all,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _selectAllMessages,
                          tooltip: 'Select All',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _selectedMessages.isEmpty ? null : _deleteSelectedMessages,
                          tooltip: 'Delete Selected',
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.checklist,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _toggleSelectionMode,
                          tooltip: 'Select Messages',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _deleteChat(),
                          tooltip: 'Delete Chat',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Messages
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FE),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _chat == null
                          ? const Center(child: Text('No chat found'))
                          : _chat!['messages'] == null || (_chat!['messages'] as List).isEmpty
                              ? Center(
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
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  reverse: false,
                                  itemCount: (_chat!['messages'] as List? ?? []).length,
                                  itemBuilder: (context, index) {
                                    final messagesList = _chat!['messages'] as List? ?? [];
                                    if (index >= messagesList.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final message = messagesList[index];
                                    final sender = message is Map ? (message['sender'] ?? message['senderId']) : null;
                                    final senderName = sender != null 
                                        ? (sender is Map ? (sender['username'] ?? 'Unknown') : sender.toString())
                                        : 'Unknown';
                                    final messageText = message is Map ? (message['message'] ?? message['text'] ?? '') : '';
                                    final timestamp = message is Map ? (message['timestamp'] ?? message['createdAt']) : null;
                                    final messageId = message is Map ? (message['_id']?.toString() ?? '') : '';
                                    final isSelected = _selectedMessages.contains(messageId);

                                return GestureDetector(
                                  onLongPress: () {
                                    if (!_isSelectionMode) {
                                      setState(() {
                                        _isSelectionMode = true;
                                        _selectedMessages.add(messageId);
                                      });
                                    } else {
                                      _toggleMessageSelection(messageId);
                                    }
                                  },
                                  onTap: () {
                                    if (_isSelectionMode) {
                                      _toggleMessageSelection(messageId);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Checkbox in selection mode
                                        if (_isSelectionMode) ...[
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8, right: 8),
                                            child: Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? widget.accentColor : Colors.white,
                                                border: Border.all(
                                                  color: isSelected ? widget.accentColor : Colors.grey,
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 16,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        ],
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Sender name (always show since admin is viewing)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8, bottom: 4),
                                                child: Text(
                                                  senderName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: widget.accentColor,
                                                  ),
                                                ),
                                              ),
                                              // Message bubble
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                                                    ),
                                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? widget.accentColor.withValues(alpha: 0.1)
                                                          : Colors.white,
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(22),
                                                        topRight: Radius.circular(22),
                                                        bottomLeft: Radius.circular(4),
                                                        bottomRight: Radius.circular(22),
                                                      ),
                                                      border: isSelected
                                                          ? Border.all(
                                                              color: widget.accentColor,
                                                              width: 2,
                                                            )
                                                          : null,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.grey.withValues(alpha: 0.1),
                                                          blurRadius: 12,
                                                          offset: const Offset(0, 4),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          messageText,
                                                          style: GoogleFonts.poppins(
                                                            color: const Color(0xFF1A1D29),
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w500,
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          _formatMessageTime(timestamp),
                                                          style: TextStyle(
                                                            color: Colors.grey.shade500,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Admin Chat List Screen (using home screen UI)
class AdminChatListScreen extends StatefulWidget {
  const AdminChatListScreen({super.key});

  @override
  State<AdminChatListScreen> createState() => _AdminChatListScreenState();
}

class _AdminChatListScreenState extends State<AdminChatListScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _chats = [];
  bool _isLoading = true;
  final Set<String> _tickedChats = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/chats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _chats = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChat(String chatId, String chatName) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Chat',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this chat?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chatName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/admin/chat/$chatId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Reload chats after successful deletion
        _loadChats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Chat deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorBody = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorBody['message'] ?? 'Failed to delete chat',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting chat: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadChats();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (_) => _loadChats(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chats.isEmpty
                    ? Center(
                        child: Text(
                          'No chats found',
                          style: GoogleFonts.poppins(),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          final participants = chat['participants'] as List;
                          final isPublicChat = chat['isPublic'] == true || chat['name'] == 'My Connect';
                          final displayName = isPublicChat
                              ? 'My Connect'
                              : (participants.isNotEmpty
                                  ? (participants.length > 1
                                      ? participants[1]['username'] ?? 'Unknown'
                                      : participants[0]['username'] ?? 'Unknown')
                                  : 'Unknown');
                          final displayPhoto = isPublicChat
                              ? null
                              : (participants.isNotEmpty
                                  ? (participants.length > 1 ? participants[1] : participants[0])
                                  : null);
                          final accentColor = _getAccentColor(index, isPublicChat);

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    chatId: chat['_id'],
                                    chatName: displayName,
                                    isPublicChat: isPublicChat,
                                    accentColor: accentColor,
                                    isReadOnly: true, // Admin view - read only
                                  ),
                                ),
                              );
                            },
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  padding: const EdgeInsets.only(right: 16, bottom: 16, left: 10),
                                  decoration: AppTheme.glassyDecoration(),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: !isPublicChat &&
                                                displayPhoto != null &&
                                                displayPhoto['profilePhoto'] != null &&
                                                displayPhoto['profilePhoto'].isNotEmpty
                                            ? NetworkImage(displayPhoto['profilePhoto'])
                                            : null,
                                        child: isPublicChat
                                            ? const Icon(Icons.people, size: 14)
                                            : (displayPhoto == null ||
                                                    displayPhoto['profilePhoto'] == null ||
                                                    displayPhoto['profilePhoto'].isEmpty
                                                ? const Icon(Icons.person, size: 14)
                                                : null),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 16),
                                            Text(
                                              displayName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                decoration: _tickedChats.contains(chat['_id'].toString())
                                                    ? TextDecoration.lineThrough
                                                    : TextDecoration.none,
                                                decorationColor: AppTheme.primaryColor,
                                                decorationThickness: 2,
                                              ),
                                            ),
                                            Text(
                                              chat['lastMessage'] ?? 'No messages yet',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        children: [
                                          const SizedBox(height: 25),
                                          Text(
                                            _formatTime(chat['lastMessageTime']),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Delete button (Top-right)
                                Positioned(
                                  top: 10,
                                  right: 30,
                                  child: GestureDetector(
                                    onTap: () => _deleteChat(chat['_id'], displayName),
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.95),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(50),
                                          bottomRight: Radius.circular(50),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                // Tick badge (Top-right, next to delete) - Toggles strikethrough
                             
                                // Admin action badge for My Connect chat
                         
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Old Admin Chats List (kept for backward compatibility if needed)
class AdminChatsList extends StatefulWidget {
  const AdminChatsList({super.key});

  @override
  State<AdminChatsList> createState() => _AdminChatsListState();
}

class _AdminChatsListState extends State<AdminChatsList> {
  List<dynamic> _chats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/admin/chats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _chats = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChat(String chatId, String chatName) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red[400], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Chat',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this chat?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                chatName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.red[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/admin/chat/$chatId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Reload chats after successful deletion
        _loadChats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Chat deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorBody = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorBody['message'] ?? 'Failed to delete chat',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error deleting chat: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_chats.isEmpty) {
      return Center(
        child: Text(
          'No chats found',
          style: GoogleFonts.poppins(),
        ),
      );
    }

    return ListView.builder(
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        final participants = chat['participants'] as List? ?? [];
        final chatName = participants.isEmpty
            ? 'Unknown Chat'
            : participants.map((p) => p['username'] ?? 'Unknown').join(' & ');
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassyDecoration(),
          child: ListTile(
            title: Text(
              chatName,
              style: GoogleFonts.poppins(),
            ),
            subtitle: Text(
              chat['lastMessage'] ?? 'No messages',
              style: GoogleFonts.poppins(),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(chat['lastMessageTime']),
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteChat(chat['_id'], chatName),
                  tooltip: 'Delete chat',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    try {
      final dateTime = DateTime.parse(time.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return '';
    }
  }
}

// Admin Events List Screen
class AdminEventsListScreen extends StatefulWidget {
  const AdminEventsListScreen({super.key});

  @override
  State<AdminEventsListScreen> createState() => _AdminEventsListScreenState();
}

class _AdminEventsListScreenState extends State<AdminEventsListScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/events'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _events = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent(String id, String title) async {
    // Show bottom modal sheet for confirmation
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              Icons.warning_amber_rounded,
              size: 60,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Event',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to delete this event?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

    if (confirm != true) return;

    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/events/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Event deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete event',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Events',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadEvents();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (_) => _loadEvents(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _events.isEmpty
                    ? Center(
                        child: Text(
                          'No events found',
                          style: GoogleFonts.poppins(),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final title = event['title'] ?? 'Untitled Event';
                          final description = event['description'] ?? '';
                          final startDate = event['start'] != null
                              ? DateTime.parse(event['start'])
                              : null;
                          final endDate = event['end'] != null
                              ? DateTime.parse(event['end'])
                              : null;
                          final color = event['color'] != null
                              ? Color(int.parse(event['color'].toString().replaceFirst('#', '0xFF')))
                              : Colors.purple;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.glassyDecoration(),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          description.length > 50
                                              ? '${description.substring(0, 50)}...'
                                              : description,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                      if (startDate != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat('MMM dd, yyyy').format(startDate),
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteEvent(event['_id'], title),
                                  tooltip: 'Delete Event',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Admin Blogs List Screen
class AdminBlogsListScreen extends StatefulWidget {
  const AdminBlogsListScreen({super.key});

  @override
  State<AdminBlogsListScreen> createState() => _AdminBlogsListScreenState();
}

class _AdminBlogsListScreenState extends State<AdminBlogsListScreen> {
  List<dynamic> _blogs = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBlogs();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadBlogs() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/blogs'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _blogs = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBlog(String id, String title) async {
    // Show bottom modal sheet for confirmation
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              Icons.warning_amber_rounded,
              size: 60,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Blog',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to delete this blog?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[400]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

    if (confirm != true) return;

    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('${AppConfig.baseUrl}/blogs/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _loadBlogs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Blog deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete blog',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Blogs',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search blogs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadBlogs();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (_) => _loadBlogs(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _blogs.isEmpty
                    ? Center(
                        child: Text(
                          'No blogs found',
                          style: GoogleFonts.poppins(),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _blogs.length,
                        itemBuilder: (context, index) {
                          final blog = _blogs[index];
                          final title = blog['title'] ?? 'Untitled Blog';
                          final description = blog['description'] ?? '';
                          final location = blog['location'] ?? '';
                          final imageUrl = blog['image'] ?? '';

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.glassyDecoration(),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image display (thumbnail)
                                if (imageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image),
                                        );
                                      },
                                    ),
                                  ),
                                if (imageUrl.isNotEmpty) const SizedBox(width: 16),
                                // Title, description, and location
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title
                                      Text(
                                        title,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // Description
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          description,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      // Location
                                      if (location.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                location,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Delete button on the right end
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteBlog(blog['_id'], title),
                                  tooltip: 'Delete Blog',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

