import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../utils/theme.dart';
import '../providers/auth_provider.dart';
import 'add_blog_screen.dart';
import 'events_screen.dart';

class BlogsScreen extends StatefulWidget {
  const BlogsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<BlogsScreen> createState() => _BlogsScreenState();
}

class _BlogsScreenState extends State<BlogsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _blogs = [];
  bool _isLoading = false;
  final Map<String, bool> _likedPosts = {};
  final Map<String, TextEditingController> _commentControllers = {};
  final Map<String, bool> _showComments = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
    });
    _fetchBlogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _fetchBlogs() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/blogs'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = authProvider.user?['_id']?.toString() ?? '';
        
        setState(() {
          _blogs = List<Map<String, dynamic>>.from(data);
          // Initialize liked posts
          for (var blog in _blogs) {
            final blogId = blog['_id']?.toString() ?? '';
            final likes = blog['likes'] as List? ?? [];
            _likedPosts[blogId] = likes.any((like) => like['_id']?.toString() == currentUserId);
            _showComments[blogId] = false;
            if (!_commentControllers.containsKey(blogId)) {
              _commentControllers[blogId] = TextEditingController();
            }
          }
        });
      } else {
        if (mounted) {
          _showErrorSnackBar('Failed to fetch blogs');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error fetching blogs: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleLike(String blogId) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/blogs/$blogId/like'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final updatedBlog = jsonDecode(response.body);
        setState(() {
          final index = _blogs.indexWhere((b) => b['_id']?.toString() == blogId);
          if (index != -1) {
            _blogs[index] = updatedBlog;
            final likes = updatedBlog['likes'] as List? ?? [];
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final currentUserId = authProvider.user?['_id']?.toString() ?? '';
            _likedPosts[blogId] = likes.any((like) => like['_id']?.toString() == currentUserId);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error liking blog: $e');
      }
    }
  }

  Future<void> _addComment(String blogId) async {
    final controller = _commentControllers[blogId];
    if (controller == null || controller.text.trim().isEmpty) return;

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/blogs/$blogId/comment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'text': controller.text.trim()}),
      );

      if (response.statusCode == 200) {
        final updatedBlog = jsonDecode(response.body);
        setState(() {
          final index = _blogs.indexWhere((b) => b['_id']?.toString() == blogId);
          if (index != -1) {
            _blogs[index] = updatedBlog;
          }
          controller.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error adding comment: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = authProvider.isAdmin();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: widget.showAppBar
            ? Text(
                _tabController.index == 0 ? 'Blogs' : 'Events',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  color: Colors.black,
                ),
              )
            : const SizedBox.shrink(),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Blogs'),
            Tab(text: 'Events'),
          ],
        ),
        actions: [
          if (isAdmin && _tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.black),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddBlogScreen()),
                );
                if (result == true) {
                  _fetchBlogs();
                }
              },
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Blogs Tab
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                )
              : _blogs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No blogs available',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchBlogs,
                      color: AppTheme.primaryColor,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _blogs.length,
                        itemBuilder: (context, index) {
                          final blog = _blogs[index];
                          final blogId = blog['_id']?.toString() ?? '';
                          final isLiked = _likedPosts[blogId] ?? false;
                          final likes = blog['likes'] as List? ?? [];
                          final comments = blog['comments'] as List? ?? [];
                          final createdBy = blog['createdBy'] as Map<String, dynamic>? ?? {};
                          final createdAt = blog['createdAt'] != null
                              ? DateTime.parse(blog['createdAt'])
                              : DateTime.now();
                          final showComments = _showComments[blogId] ?? false;

                          return _buildPostCard(
                            blog: blog,
                            blogId: blogId,
                            isLiked: isLiked,
                            likes: likes,
                            comments: comments,
                            createdBy: createdBy,
                            createdAt: createdAt,
                            showComments: showComments,
                            isAdmin: isAdmin,
                          );
                        },
                      ),
                    ),
          // Events Tab
          const EventsScreen(),
        ],
      ),
    );
  }

  Widget _buildPostCard({
    required Map<String, dynamic> blog,
    required String blogId,
    required bool isLiked,
    required List likes,
    required List comments,
    required Map<String, dynamic> createdBy,
    required DateTime createdAt,
    required bool showComments,
    required bool isAdmin,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: createdBy['profilePhoto'] != null &&
                          createdBy['profilePhoto'].toString().isNotEmpty
                      ? NetworkImage(createdBy['profilePhoto'])
                      : null,
                  child: createdBy['profilePhoto'] == null ||
                          createdBy['profilePhoto'].toString().isEmpty
                      ? Text(
                          (createdBy['username'] ?? 'U')[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        createdBy['username'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (blog['location'] != null && blog['location'].toString().isNotEmpty)
                        Text(
                          blog['location'],
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 24),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          // Post Image
          AspectRatio(
            aspectRatio: 2.0, // Reduced height - wider aspect ratio
            child: Image.network(
              blog['image'] ?? '',
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                  ),
                );
              },
            ),
          ),
          // Post Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.black,
                        size: 28,
                      ),
                      onPressed: () => _toggleLike(blogId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.comment_outlined, size: 28),
                      onPressed: () {
                        setState(() {
                          _showComments[blogId] = !(_showComments[blogId] ?? false);
                        });
                      },
                    ),
                  ],
                ),
                // Likes count
                Text(
                  '${likes.length} ${likes.length == 1 ? 'like' : 'likes'}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Caption
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                    children: [
                      TextSpan(
                        text: '${createdBy['username'] ?? 'Unknown'} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: blog['title'] ?? ''),
                    ],
                  ),
                ),
                if (blog['description'] != null && blog['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    blog['description'],
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  ),
                ],
                // View all comments
                if (comments.isNotEmpty && !showComments)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showComments[blogId] = true;
                      });
                    },
                    child: Text(
                      'View all ${comments.length} ${comments.length == 1 ? 'comment' : 'comments'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                // Comments
                if (showComments && comments.isNotEmpty)
                  ...comments.map<Widget>((comment) {
                    final commentUser = comment['user'] as Map<String, dynamic>? ?? {};
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                                children: [
                                  TextSpan(
                                    text: '${commentUser['username'] ?? 'Unknown'} ',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  TextSpan(text: comment['text'] ?? ''),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                // Time
                Text(
                  _getTimeAgo(createdAt).toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
                // View count (admin only)
                if (isAdmin && blog['views'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${blog['views']} ${blog['views'] == 1 ? 'view' : 'views'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                // Add comment input
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentControllers[blogId],
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onSubmitted: (_) => _addComment(blogId),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _addComment(blogId),
        child: Text(
                        'Post',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
