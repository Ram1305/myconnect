import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/api_service.dart';
import '../utils/theme.dart';
import 'signup_screen.dart';
import 'add_event_screen.dart';
import 'add_blog_screen.dart';
import 'admin_banner_list_screen.dart';
import 'gallery_screen.dart';
import 'temple_list_screen.dart';

/// Super-admin: list of admins with grid/list view toggle.
class AdminListViewScreen extends StatefulWidget {
  const AdminListViewScreen({super.key});

  @override
  State<AdminListViewScreen> createState() => _AdminListViewScreenState();
}

class _AdminListViewScreenState extends State<AdminListViewScreen> {
  List<dynamic> _admins = [];
  bool _isLoading = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    final admins = await ApiService.getAdmins();
    if (mounted) {
      setState(() {
        _admins = admins;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin View',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'List view' : 'Grid view',
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _admins.isEmpty
              ? Center(
                  child: Text(
                    'No admins found',
                    style: GoogleFonts.poppins(),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAdmins,
                  child: _isGridView ? _buildGrid() : _buildList(),
                ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.0,
      ),
      itemCount: _admins.length,
      itemBuilder: (context, index) => _buildAdminCard(_admins[index]),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _admins.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildAdminCard(_admins[index]),
      ),
    );
  }

  Future<void> _blockOrUnblockAdmin(Map<String, dynamic> admin, bool block) async {
    final id = admin['_id']?.toString();
    if (id == null) return;
    final result = block
        ? await ApiService.blockAdmin(id)
        : await ApiService.unblockAdmin(id);
    if (!mounted) return;
    if (result['error'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? result['error']?.toString() ?? 'Failed',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          block ? 'Admin blocked' : 'Admin unblocked',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
      ),
    );
    _loadAdmins();
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final role = admin['role']?.toString() ?? 'admin';
    final relatedCount = admin['relatedCount'] as int? ?? 0;
    final isBlocked = admin['isBlocked'] == true;
    final isAdminRole = role == 'admin';
    final profilePhoto = admin['profilePhoto']?.toString();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdminDetailScreen(admin: admin),
            ),
          ).then((_) => _loadAdmins());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    backgroundImage: (profilePhoto != null && profilePhoto.isNotEmpty)
                        ? NetworkImage(profilePhoto)
                        : null,
                    child: (profilePhoto == null || profilePhoto.isEmpty)
                        ? Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      admin['username']?.toString() ?? 'Admin',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                admin['mobileNumber']?.toString() ?? '',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600]),
              ),
              if (admin['referralId'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  'ID: ${admin['referralId']}',
                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (isBlocked) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Blocked',
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.red),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    '$relatedCount related',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              if (isAdminRole) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      _blockOrUnblockAdmin(admin, !isBlocked);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      isBlocked ? 'Unblock' : 'Block',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isBlocked ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Super-admin: detail of one admin with grid of sections (Add User, Pending, Approved, etc.)
class AdminDetailScreen extends StatelessWidget {
  final Map<String, dynamic> admin;

  const AdminDetailScreen({super.key, required this.admin});

  String get _adminId => admin['_id']?.toString() ?? '';
  String? get _referralId => admin['referralId']?.toString();

  Widget _gridTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          admin['username']?.toString() ?? 'Admin',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mobile: ${admin['mobileNumber'] ?? ''}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                if (_referralId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Referral ID: $_referralId',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
                children: [
                  _gridTile(
                    context,
                    title: 'Add User',
                    icon: Icons.person_add,
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SignupScreen(
                            adminCreated: true,
                            initialReferralId: _referralId,
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'User cannot login',
                    icon: Icons.block,
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminScopedUserListScreen(
                            adminId: _adminId,
                            status: 'cannot-login',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Pending',
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminScopedUserListScreen(
                            adminId: _adminId,
                            status: 'pending',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Approved',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminScopedUserListScreen(
                            adminId: _adminId,
                            status: 'approved',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Rejected',
                    icon: Icons.cancel,
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminScopedUserListScreen(
                            adminId: _adminId,
                            status: 'rejected',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Related people',
                    icon: Icons.people,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminRelatedPeopleScreen(adminId: _adminId),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Chats',
                    icon: Icons.chat,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminChatsListScreen(adminId: _adminId),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Add Event',
                    icon: Icons.event,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEventScreen()),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Add Blog',
                    icon: Icons.article,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddBlogScreen()),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'List Events',
                    icon: Icons.event_note,
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminContentListScreen(
                            type: 'events',
                            referralId: _referralId,
                            title: 'Events',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'List Blogs',
                    icon: Icons.list_alt,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminContentListScreen(
                            type: 'blogs',
                            referralId: _referralId,
                            title: 'Blogs',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'View Banners',
                    icon: Icons.view_carousel,
                    color: Colors.amber,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminContentListScreen(
                            type: 'banners',
                            referralId: _referralId,
                            title: 'Banners',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Gallery',
                    icon: Icons.photo_library,
                    color: Colors.cyan,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminContentListScreen(
                            type: 'gallery',
                            referralId: _referralId,
                            title: 'Gallery',
                          ),
                        ),
                      );
                    },
                  ),
                  _gridTile(
                    context,
                    title: 'Temples',
                    icon: Icons.temple_buddhist,
                    color: Colors.brown,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminContentListScreen(
                            type: 'temples',
                            referralId: _referralId,
                            title: 'Temples',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple list of users for one admin (pending/approved/rejected/cannot-login) with actions.
class AdminScopedUserListScreen extends StatefulWidget {
  final String adminId;
  final String status;

  const AdminScopedUserListScreen({
    super.key,
    required this.adminId,
    required this.status,
  });

  @override
  State<AdminScopedUserListScreen> createState() => _AdminScopedUserListScreenState();
}

class _AdminScopedUserListScreenState extends State<AdminScopedUserListScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getAdminScopedUsers(widget.adminId, widget.status);
    if (mounted) setState(() { _users = list; _isLoading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.status == 'cannot-login'
        ? 'Cannot login'
        : widget.status[0].toUpperCase() + widget.status.substring(1);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(
                    'No users',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final id = user['_id']?.toString() ?? '';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['profilePhoto'] != null &&
                                    (user['profilePhoto'] as String).isNotEmpty
                                ? NetworkImage(user['profilePhoto'] as String)
                                : null,
                            child: user['profilePhoto'] == null ||
                                    (user['profilePhoto'] as String).isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            user['username']?.toString() ?? 'User',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            user['mobileNumber']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          trailing: widget.status == 'pending'
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () async {
                                        await ApiService.approveUser(id);
                                        _load();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () async {
                                        await ApiService.rejectUser(id);
                                        _load();
                                      },
                                    ),
                                  ],
                                )
                              : widget.status == 'cannot-login'
                                  ? IconButton(
                                      icon: const Icon(Icons.lock_open, color: Colors.green),
                                      onPressed: () async {
                                        await ApiService.allowUserLogin(id);
                                        _load();
                                      },
                                    )
                                  : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Related people list (createdByAdmin = adminId) with FAB to add people.
class AdminRelatedPeopleScreen extends StatefulWidget {
  final String adminId;

  const AdminRelatedPeopleScreen({super.key, required this.adminId});

  @override
  State<AdminRelatedPeopleScreen> createState() => _AdminRelatedPeopleScreenState();
}

class _AdminRelatedPeopleScreenState extends State<AdminRelatedPeopleScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getAdminRelatedUsers(widget.adminId);
    if (mounted) setState(() { _users = list; _isLoading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Related people', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Text(
                    'No related people. Tap + to add.',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['profilePhoto'] != null &&
                                    (user['profilePhoto'] as String).isNotEmpty
                                ? NetworkImage(user['profilePhoto'] as String)
                                : null,
                            child: user['profilePhoto'] == null ||
                                    (user['profilePhoto'] as String).isEmpty
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            user['username']?.toString() ?? 'User',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            user['mobileNumber']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddRelatedPeopleScreen(adminId: widget.adminId),
            ),
          );
          if (added == true) _load();
        },
        icon: const Icon(Icons.person_add),
        label: Text('Add people', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}

/// Generic list screen for events, blogs, banners, gallery, temples filtered by referralId.
class AdminContentListScreen extends StatefulWidget {
  final String type;
  final String? referralId;
  final String title;

  const AdminContentListScreen({
    super.key,
    required this.type,
    this.referralId,
    required this.title,
  });

  @override
  State<AdminContentListScreen> createState() => _AdminContentListScreenState();
}

class _AdminContentListScreenState extends State<AdminContentListScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    List<dynamic> list = [];
    switch (widget.type) {
      case 'events':
        list = await ApiService.getEventsWithReferralId(widget.referralId);
        break;
      case 'blogs':
        list = await ApiService.getBlogsWithReferralId(widget.referralId);
        break;
      case 'banners':
        list = await ApiService.getBannersWithReferralId(widget.referralId);
        break;
      case 'gallery':
        list = await ApiService.getGalleryWithReferralId(widget.referralId);
        break;
      case 'temples':
        list = await ApiService.getTemplesWithReferralId(widget.referralId);
        break;
    }
    if (mounted) setState(() { _items = list; _isLoading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No ${widget.title.toLowerCase()}',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index] as Map<String, dynamic>;
                    if (widget.type == 'events') {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            item['title']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            item['description']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }
                    if (widget.type == 'blogs') {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: item['image'] != null
                              ? Image.network(
                                  item['image'] as String,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                )
                              : null,
                          title: Text(
                            item['title']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }
                    if (widget.type == 'banners' || widget.type == 'gallery') {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: item['image'] != null
                              ? Image.network(
                                  item['image'] as String,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                )
                              : null,
                          title: Text(
                            item['title']?.toString() ?? 'Image',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }
                    if (widget.type == 'temples') {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: item['frontImage'] != null
                              ? Image.network(
                                  item['frontImage'] as String,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                )
                              : null,
                          title: Text(
                            item['name']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            item['address']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
    );
  }
}

/// Chats for an admin's users (super-admin only).
class AdminChatsListScreen extends StatefulWidget {
  final String adminId;

  const AdminChatsListScreen({super.key, required this.adminId});

  @override
  State<AdminChatsListScreen> createState() => _AdminChatsListScreenState();
}

class _AdminChatsListScreenState extends State<AdminChatsListScreen> {
  List<dynamic> _chats = [];
  bool _isLoading = true;

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getAdminChats(widget.adminId);
    if (mounted) setState(() { _chats = list; _isLoading = false; });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? Center(
                  child: Text(
                    'No chats',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _chats.length,
                    itemBuilder: (context, index) {
                      final chat = _chats[index] as Map<String, dynamic>;
                      final participants = chat['participants'] as List<dynamic>? ?? [];
                      final names = participants
                          .map((p) => p is Map ? (p['username'] ?? p['mobileNumber'] ?? '') : '')
                          .where((s) => s.isNotEmpty)
                          .join(', ');
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.chat),
                          ),
                          title: Text(
                            names.isEmpty ? 'Chat' : names,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            chat['lastMessage']?.toString() ?? '',
                            style: GoogleFonts.poppins(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Super-admin: select approved users to assign to an admin.
class AddRelatedPeopleScreen extends StatefulWidget {
  final String adminId;

  const AddRelatedPeopleScreen({super.key, required this.adminId});

  @override
  State<AddRelatedPeopleScreen> createState() => _AddRelatedPeopleScreenState();
}

class _AddRelatedPeopleScreenState extends State<AddRelatedPeopleScreen> {
  List<dynamic> _approvedUsers = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isAssigning = false;

  @override
  void initState() {
    super.initState();
    _loadApproved();
  }

  Future<void> _loadApproved() async {
    setState(() => _isLoading = true);
    final users = await ApiService.getApprovedUsersAdmin();
    if (mounted) {
      setState(() {
        _approvedUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _assignSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select at least one user', style: GoogleFonts.poppins()),
        ),
      );
      return;
    }
    setState(() => _isAssigning = true);
    int success = 0;
    for (final userId in _selectedIds) {
      final res = await ApiService.assignUserToAdmin(userId, widget.adminId);
      if (res['error'] == null) success++;
    }
    if (mounted) {
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$success user(s) assigned',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add people to related',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_selectedIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedIds.length} selected',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: _isAssigning ? null : _assignSelected,
                    child: _isAssigning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Assign to admin', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _approvedUsers.isEmpty
                    ? Center(
                        child: Text(
                          'No approved users',
                          style: GoogleFonts.poppins(),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _approvedUsers.length,
                        itemBuilder: (context, index) {
                          final user = _approvedUsers[index];
                          final id = user['_id']?.toString() ?? '';
                          final selected = _selectedIds.contains(id);
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              });
                            },
                            title: Text(
                              user['username']?.toString() ?? 'User',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              user['mobileNumber']?.toString() ?? '',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
