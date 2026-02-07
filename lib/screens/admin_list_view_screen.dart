import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/api_service.dart';
import '../utils/theme.dart';

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

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final role = admin['role']?.toString() ?? 'admin';
    final relatedCount = admin['relatedCount'] as int? ?? 0;
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
                    child: Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor),
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
                  const SizedBox(width: 8),
                  Text(
                    '$relatedCount related',
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Super-admin: detail of one admin and their related users.
class AdminDetailScreen extends StatefulWidget {
  final Map<String, dynamic> admin;

  const AdminDetailScreen({super.key, required this.admin});

  @override
  State<AdminDetailScreen> createState() => _AdminDetailScreenState();
}

class _AdminDetailScreenState extends State<AdminDetailScreen> {
  List<dynamic> _relatedUsers = [];
  bool _isLoading = true;

  String get _adminId => widget.admin['_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadRelated();
  }

  Future<void> _loadRelated() async {
    setState(() => _isLoading = true);
    final users = await ApiService.getAdminRelatedUsers(_adminId);
    if (mounted) {
      setState(() {
        _relatedUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _addPeopleToRelated() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddRelatedPeopleScreen(adminId: _adminId),
      ),
    );
    if (added == true) _loadRelated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.admin['username']?.toString() ?? 'Admin',
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
                  'Mobile: ${widget.admin['mobileNumber'] ?? ''}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${widget.admin['role'] ?? 'admin'}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Related people (${_relatedUsers.length})',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _relatedUsers.isEmpty
                    ? Center(
                        child: Text(
                          'No related people. Tap + to add.',
                          style: GoogleFonts.poppins(color: Colors.grey[600]),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadRelated,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _relatedUsers.length,
                          itemBuilder: (context, index) {
                            final user = _relatedUsers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPeopleToRelated,
        icon: const Icon(Icons.person_add),
        label: Text('Add people to related', style: GoogleFonts.poppins()),
        backgroundColor: AppTheme.primaryColor,
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
