import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/user_provider.dart';
import '../utils/theme.dart';
import '../config/app_config.dart';
import 'video_details_screen.dart';

class SearchByUsernameScreen extends StatefulWidget {
  const SearchByUsernameScreen({super.key});

  @override
  State<SearchByUsernameScreen> createState() => _SearchByUsernameScreenState();
}

class _SearchByUsernameScreenState extends State<SearchByUsernameScreen> {
  final _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }



  Future<void> _loadUsers() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    // Search only by username - filter on frontend after getting results
    await userProvider.fetchApprovedUsers(
      search: _searchController.text.isEmpty ? null : _searchController.text,
    );
  }

  Widget _buildAddressDisplay(Map<String, dynamic> user) {
    final address = user['currentAddress'];
    if (address == null) return const SizedBox.shrink();

    final addressParts = <String>[];
    if (address['address'] != null && address['address'].toString().isNotEmpty) {
      addressParts.add(address['address'].toString());
    }
    if (address['city'] != null && address['city'].toString().isNotEmpty) {
      addressParts.add(address['city'].toString());
    }
    if (address['state'] != null && address['state'].toString().isNotEmpty) {
      addressParts.add(address['state'].toString());
    }
    if (address['pincode'] != null && address['pincode'].toString().isNotEmpty) {
      addressParts.add(address['pincode'].toString());
    }

    if (addressParts.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            addressParts.join(', '),
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search by Username',
          style: GoogleFonts.poppins(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter username to search...',
                prefixIcon: const Icon(Icons.person_search),
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
            child: Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                if (userProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filter results to only show users matching username
                final filteredUsers = _searchController.text.isEmpty
                    ? []
                    : userProvider.approvedUsers.where((user) {
                        final username = (user['username'] ?? '').toString().toLowerCase();
                        final searchQuery = _searchController.text.toLowerCase();
                        return username.contains(searchQuery);
                      }).toList();

                if (_searchController.text.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Enter a username to search',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different username',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoDetailsScreen(userId: user['_id']),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassyDecoration(),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundImage: user['profilePhoto'] != null &&
                                  user['profilePhoto'].isNotEmpty
                                  ? NetworkImage(user['profilePhoto'])
                                  : null,
                              child: user['profilePhoto'] == null ||
                                  user['profilePhoto'].isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['username'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Father: ${user['fatherName'] ?? ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (user['currentAddress'] != null) ...[
                                    const SizedBox(height: 4),
                                    _buildAddressDisplay(user),
                                  ],
                                ],
                              ),
                            ),

                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

