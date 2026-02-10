import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/api_service.dart';
import '../utils/theme.dart';
import 'signup_screen.dart';
import 'add_event_screen.dart';
import 'add_blog_screen.dart';
import 'admin_banner_list_screen.dart';
import 'gallery_screen.dart';
import 'temple_list_screen.dart';

/// Super-admin: list of admins with grid/list view toggle.
/// When [blockedOnly] is true, shows only blocked admins.
class AdminListViewScreen extends StatefulWidget {
  const AdminListViewScreen({super.key, this.blockedOnly = false});

  final bool blockedOnly;

  @override
  State<AdminListViewScreen> createState() => _AdminListViewScreenState();
}

class _AdminListViewScreenState extends State<AdminListViewScreen> {
  List<dynamic> _admins = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAdmins();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredAdmins {
    if (_searchQuery.isEmpty) return _admins;
    final q = _searchQuery.toLowerCase();
    return _admins.where((a) {
      final username = (a['username']?.toString() ?? '').toLowerCase();
      final mobile = (a['mobileNumber']?.toString() ?? '').toLowerCase();
      final email = (a['emailId']?.toString() ?? '').toLowerCase();
      final referral = (a['referralId']?.toString() ?? '').toLowerCase();
      return username.contains(q) ||
          mobile.contains(q) ||
          email.contains(q) ||
          referral.contains(q);
    }).toList();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    final admins = await ApiService.getAdmins();
    if (mounted) {
      setState(() {
        // Exclude super admin from the list so they don't appear in Admin View
        final withoutSuperAdmin = admins
            .where((a) => (a['role']?.toString() ?? '').toLowerCase() != 'super-admin')
            .toList();
        _admins = widget.blockedOnly
            ? withoutSuperAdmin.where((a) => a['isBlocked'] == true).toList()
            : withoutSuperAdmin;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.blockedOnly ? 'Blocked Admins' : 'Admin View',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 8,
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.primaryColor,
        surfaceTintColor: AppTheme.primaryColor.withValues(alpha: 0.08),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, mobile, email...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                style: GoogleFonts.poppins(fontSize: 15),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _admins.isEmpty
                    ? _buildEmptyState(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'No admins yet',
                        subtitle: 'Admins will appear here once they are created.',
                      )
                    : _filteredAdmins.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No results found',
                            subtitle: 'Try a different search for "$_searchQuery".',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAdmins,
                            color: AppTheme.primaryColor,
                            child: _buildList(),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading admins...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final list = _filteredAdmins;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: list.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _buildAdminCard(list[index]),
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

  void _showReferralCodeSheet(BuildContext context, String? referralId, String? adminName) {
    final code = referralId?.trim();
    final hasCode = code != null && code.isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
              'Referral Code',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            if (hasCode) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.lightGold.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SelectableText(
                        code,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: AppTheme.primaryColor),
                      tooltip: 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Copied to clipboard', style: GoogleFonts.poppins()),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Share.share(
                      'Use this referral code for My Connect: $code${adminName != null && adminName.isNotEmpty ? ' (Admin: $adminName)' : ''}',
                    );
                  },
                  icon: const Icon(Icons.share, size: 22),
                  label: Text('Share', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No referral code',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    final role = admin['role']?.toString() ?? 'admin';
    final relatedCount = admin['relatedCount'] as int? ?? 0;
    final isBlocked = admin['isBlocked'] == true;
    final isAdminRole = role == 'admin';
    final profilePhoto = admin['profilePhoto']?.toString();
    final mobile = admin['mobileNumber']?.toString() ?? '—';
    final email = admin['emailId']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminDetailScreen(admin: admin),
              ),
            ).then((_) => _loadAdmins());
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                        backgroundImage: (profilePhoto != null && profilePhoto.isNotEmpty)
                            ? NetworkImage(profilePhoto)
                            : null,
                        child: (profilePhoto == null || profilePhoto.isEmpty)
                            ? Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 28)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin['username']?.toString() ?? 'Admin',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              color: AppTheme.primaryColor,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone_rounded, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  mobile,
                                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (email != null && email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.email_outlined, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
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
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildChip(
                      label: role,
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      textColor: AppTheme.primaryColor,
                    ),
                    if (isBlocked)
                      _buildChip(
                        label: 'Blocked',
                        color: Colors.red.withValues(alpha: 0.15),
                        textColor: Colors.red[700]!,
                      ),
                    _buildChip(
                      label: '$relatedCount related',
                      color: Colors.grey.withValues(alpha: 0.12),
                      textColor: Colors.grey[700]!,
                    ),
                  ],
                ),
                if (admin['referralId'] != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      _showReferralCodeSheet(
                        context,
                        admin['referralId']?.toString(),
                        admin['username']?.toString(),
                      );
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGold.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.card_giftcard_rounded, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'View referral code',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (isAdminRole) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () => _blockOrUnblockAdmin(admin, !isBlocked),
                      style: FilledButton.styleFrom(
                        backgroundColor: isBlocked
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.12),
                        foregroundColor: isBlocked ? Colors.green[700] : Colors.red[700],
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        isBlocked ? 'Unblock' : 'Block',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 26, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profilePhoto = admin['profilePhoto']?.toString();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          admin['username']?.toString() ?? 'Admin',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  backgroundImage: (profilePhoto != null && profilePhoto.isNotEmpty)
                      ? NetworkImage(profilePhoto)
                      : null,
                  child: (profilePhoto == null || profilePhoto.isEmpty)
                      ? Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            admin['mobileNumber']?.toString() ?? '—',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      if (_referralId != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.card_giftcard_rounded, size: 16, color: AppTheme.primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _referralId!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.grey[700],
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
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
