import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import '../providers/user_provider.dart';
import '../utils/theme.dart';
import '../utils/permission_service.dart';
import 'video_details_screen.dart';

class FamilyLocationsScreen extends StatefulWidget {
  final List<dynamic>? usersToShow; // Optional: if provided, only show these users
  
  const FamilyLocationsScreen({super.key, this.usersToShow});

  @override
  State<FamilyLocationsScreen> createState() => _FamilyLocationsScreenState();
}

class _FamilyLocationsScreenState extends State<FamilyLocationsScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = true;
  bool _showRoute = false; // Toggle for showing route (only for My List)
  Set<String> _excludedUserIds = {}; // Users excluded from route
  double? _userLatitude;
  double? _userLongitude;
  List<Map<String, dynamic>> _sortedUsers = []; // Users sorted by distance
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _allUsers = []; // All users (for filtering)

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _filterAndUpdateMarkers();
    });
  }

  void _filterAndUpdateMarkers() {
    if (_searchQuery.isEmpty) {
      // Show all users
      _sortedUsers = List.from(_allUsers);
    } else {
      // Filter by username
      _sortedUsers = _allUsers.where((item) {
        final user = item['user'] as Map<String, dynamic>;
        final username = user['username']?.toString().toLowerCase() ?? '';
        return username.contains(_searchQuery);
      }).toList();
    }
    
    // Rebuild markers with filtered users
    final filteredUsers = _sortedUsers.map((item) => item['user'] as Map<String, dynamic>).toList();
    _buildMarkers(filteredUsers);
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await PermissionService.requestLocationPermission(context);
    if (!hasPermission) {
      _loadUsersAndMarkers();
      return;
    }

    // Skip geolocator on Windows
    if (!kIsWeb && Platform.isWindows) {
      _loadUsersAndMarkers();
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
      _loadUsersAndMarkers();
    } catch (e) {
      _loadUsersAndMarkers();
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Use haversine formula as fallback for Windows
    if (!kIsWeb && Platform.isWindows) {
      return _haversineDistance(lat1, lon1, lat2, lon2) / 1000; // Convert to km
    }
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  // Haversine formula for calculating distance between two coordinates
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth radius in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  Future<void> _loadUsersAndMarkers() async {
    List<dynamic> users;
    
    if (widget.usersToShow != null) {
      // Use provided users (e.g., from My List)
      users = widget.usersToShow!;
    } else {
      // Fetch all approved users
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.fetchApprovedUsers();
      users = userProvider.approvedUsers;
    }
    
      if (mounted) {
      // Calculate distances and sort users
      if (_userLatitude != null && _userLongitude != null) {
        _allUsers = users.map((user) {
          double? lat;
          double? lon;
          
          // Get coordinates from currentAddress
          final currentAddress = user['currentAddress'] as Map<String, dynamic>?;
          if (currentAddress != null) {
            if (currentAddress['latitude'] != null && currentAddress['longitude'] != null) {
              lat = (currentAddress['latitude'] as num).toDouble();
              lon = (currentAddress['longitude'] as num).toDouble();
            }
          }
          
          // Fallback to main user coordinates
          if (lat == null || lon == null) {
            if (user['latitude'] != null && user['longitude'] != null) {
              lat = (user['latitude'] as num).toDouble();
              lon = (user['longitude'] as num).toDouble();
            }
          }
          
          double distance = 0;
          if (lat != null && lon != null) {
            distance = _calculateDistance(_userLatitude!, _userLongitude!, lat, lon);
          }
          
          return {
            'user': user,
            'distance': distance,
            'latitude': lat,
            'longitude': lon,
          };
        }).toList();
        
        // Sort by distance (nearest first)
        _allUsers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      } else {
        // No location, just use users as is
        _allUsers = users.map((user) => {
          'user': user,
          'distance': null,
          'latitude': null,
          'longitude': null,
        }).toList();
      }
      
      // Apply search filter if any
      if (_searchQuery.isNotEmpty) {
        _sortedUsers = _allUsers.where((item) {
          final user = item['user'] as Map<String, dynamic>;
          final username = user['username']?.toString().toLowerCase() ?? '';
          return username.contains(_searchQuery);
        }).toList();
      } else {
        _sortedUsers = List.from(_allUsers);
      }
      
      // Build markers with filtered users
      final usersToShow = _searchQuery.isEmpty 
          ? users 
          : _sortedUsers.map((item) => item['user'] as Map<String, dynamic>).toList();
      _buildMarkers(usersToShow);
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _buildMarkers(List<dynamic> users) {
    final Set<Marker> markers = {};
    final Set<Polyline> polylines = {};
    final List<LatLng> routePoints = [];
    final bool isMyList = widget.usersToShow != null; // Only show route for My List
    
    // Add user's current location marker if available
    if (_userLatitude != null && _userLongitude != null) {
      final myLocation = LatLng(_userLatitude!, _userLongitude!);
      if (isMyList && _showRoute) {
        routePoints.add(myLocation); // Start of route
      }
      
      markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: myLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(
            title: 'My Location',
            snippet: 'You are here',
          ),
        ),
      );
    }
    
    // Build markers with proximity ranking using filtered _sortedUsers
    for (int i = 0; i < _sortedUsers.length; i++) {
      final item = _sortedUsers[i];
      final user = item['user'] as Map<String, dynamic>;
      final lat = item['latitude'] as double?;
      final lon = item['longitude'] as double?;
      final rank = i + 1;
      final userId = user['_id']?.toString();
      
      // Skip excluded users when route planning is active (My List only)
      if (isMyList && _showRoute && userId != null && _excludedUserIds.contains(userId)) {
        continue;
      }
      
      if (lat != null && lon != null) {
        final position = LatLng(lat, lon);
        if (isMyList && _showRoute) {
          routePoints.add(position); // Add to route
        }
        
        // Get address
        String? address;
        final currentAddress = user['currentAddress'] as Map<String, dynamic>?;
        if (currentAddress != null) {
          address = currentAddress['address']?.toString();
        }
        
        final markerId = MarkerId(user['_id']?.toString() ?? '${markers.length}');
        markers.add(
          Marker(
            markerId: markerId,
            position: position,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              rank == 1 ? BitmapDescriptor.hueRed : 
              rank == 2 ? BitmapDescriptor.hueOrange :
              rank == 3 ? BitmapDescriptor.hueYellow :
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(
              title: '#$rank - ${user['username']?.toString() ?? 'User'}',
              snippet: address ?? 'Location',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoDetailsScreen(userId: user['_id']),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    
    // Create circular route only if showRoute is enabled and it's My List
    if (isMyList && _showRoute && routePoints.length > 1 && _userLatitude != null && _userLongitude != null) {
      // Filter out excluded users from route
      final List<LatLng> filteredRoute = [routePoints[0]]; // Start with user's location
      
      for (int i = 0; i < _sortedUsers.length; i++) {
        final item = _sortedUsers[i];
        final user = item['user'] as Map<String, dynamic>;
        final userId = user['_id']?.toString();
        
        // Only add to route if not excluded
        if (userId != null && !_excludedUserIds.contains(userId)) {
          final lat = item['latitude'] as double?;
          final lon = item['longitude'] as double?;
          if (lat != null && lon != null) {
            filteredRoute.add(LatLng(lat, lon));
          }
        }
      }
      
      // Add return to starting point to complete the circle
      if (filteredRoute.length > 1) {
        filteredRoute.add(LatLng(_userLatitude!, _userLongitude!));
        
        // Create one polyline for the entire route
        polylines.add(
          Polyline(
            polylineId: const PolylineId('circular_route'),
            points: filteredRoute,
            color: AppTheme.primaryColor,
            width: 3,
            patterns: [PatternItem.dash(10), PatternItem.gap(5)],
          ),
        );
      }
    }
    
    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
    
    // Fit bounds to show all markers
    if (_mapController != null && markers.isNotEmpty) {
      _fitBounds(markers);
    }
  }

  void _fitBounds(Set<Marker> markers) {
    if (markers.isEmpty) return;
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;
    
    for (var marker in markers) {
      final lat = marker.position.latitude;
      final lon = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        100.0, // padding in pixels
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.usersToShow != null ? 'My List Locations' : 'Family Locations',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<UserProvider>(
              builder: (context, userProvider, _) {
                if (_markers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No locations available',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(20.5937, 78.9629), // Default to India center
                        zoom: 5,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      mapType: MapType.normal,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        if (_markers.isNotEmpty) {
                          _fitBounds(_markers);
                        }
                      },
                    ),
                    // Search bar at the top
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search bar
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search by username...',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: AppTheme.primaryColor,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              style: GoogleFonts.poppins(),
                            ),
                            // Plan Route Button (only for My List)
                            if (widget.usersToShow != null) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showRoute = !_showRoute;
                                      if (!_showRoute) {
                                        _excludedUserIds.clear(); // Clear exclusions when hiding route
                                      }
                                    });
                                    _buildMarkers(widget.usersToShow ?? 
                                      Provider.of<UserProvider>(context, listen: false).approvedUsers);
                                  },
                                  icon: Icon(
                                    _showRoute ? Icons.route : Icons.add_road,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _showRoute ? 'Hide Route' : 'Plan Route',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _showRoute 
                                        ? Colors.grey[300] 
                                        : AppTheme.primaryColor,
                                    foregroundColor: _showRoute 
                                        ? Colors.grey[700] 
                                        : Colors.white,
                                    minimumSize: const Size(double.infinity, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Bottom sheet with nearby users
                    _buildNearbyUsersSheet(),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildNearbyUsersSheet() {
    if (_sortedUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.15,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Header (fixed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.near_me, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Nearby Users',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_sortedUsers.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Scrollable list
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _sortedUsers.length,
                      itemBuilder: (context, index) {
                        final item = _sortedUsers[index];
                        final user = item['user'] as Map<String, dynamic>;
                        final distance = item['distance'] as double?;
                        final rank = index + 1;
                        
                        return _buildNearbyUserItem(user, distance, rank);
                      },
                    ),
                  ),
                ],
              ),
        );
      },
    );
  }

  Widget _buildNearbyUserItem(Map<String, dynamic> user, double? distance, int rank) {
    final username = user['username']?.toString() ?? 'Unknown';
    final userId = user['_id']?.toString();
    final bool isMyList = widget.usersToShow != null;
    final isExcluded = isMyList && userId != null && _excludedUserIds.contains(userId);
    
    // Determine address display based on distance
    String address;
    if (distance != null && distance > 100) {
      // Show only state and pincode if > 100km
      final currentAddress = user['currentAddress'] as Map<String, dynamic>?;
      if (currentAddress != null) {
        final state = currentAddress['state']?.toString().trim() ?? '';
        final pincode = currentAddress['pincode']?.toString().trim() ?? '';
        
        // Combine state and pincode
        if (state.isNotEmpty && pincode.isNotEmpty) {
          address = '$state, $pincode';
        } else if (state.isNotEmpty) {
          address = state;
        } else if (pincode.isNotEmpty) {
          address = pincode;
        } else {
          address = currentAddress['address']?.toString().trim() ?? 'Location not available';
        }
      } else {
        address = 'Location not available';
      }
    } else {
      // Show full address if <= 100km
      address = user['currentAddress']?['address']?.toString().trim() ?? 
                user['currentAddress']?['state']?.toString().trim() ?? 
                'Location not available';
    }
    
    return InkWell(
      onTap: () {
        if (isMyList && _showRoute && userId != null) {
          // Toggle exclusion when route planning is active (My List only)
          setState(() {
            if (isExcluded) {
              _excludedUserIds.remove(userId);
            } else {
              _excludedUserIds.add(userId);
            }
          });
          // Rebuild markers to update route
          _buildMarkers(widget.usersToShow ?? 
            Provider.of<UserProvider>(context, listen: false).approvedUsers);
        } else {
          // Navigate to user profile
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoDetailsScreen(userId: user['_id']),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isExcluded ? Colors.grey[200] : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isExcluded 
                ? Colors.grey[400]!
                : rank == 1 
                    ? AppTheme.primaryColor 
                    : Colors.grey[300]!,
            width: rank == 1 && !isExcluded ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Rank indicator with line
            Container(
              width: 50,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Line above number (for rank 2, 3, 4, etc.)
                  if (rank > 1)
                    Container(
                      width: 2,
                      height: 20,
                      color: rank == 2 
                          ? AppTheme.primaryColor 
                          : Colors.grey[400],
                    ),
                  // Number badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isExcluded
                          ? Colors.grey[400]
                          : rank == 1 
                              ? AppTheme.primaryColor 
                              : Colors.grey[400],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: isExcluded ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ),
                  // Line below number (for rank 1, 2, 3, etc. - connects to next)
                  if (rank < _sortedUsers.length)
                    Container(
                      width: 2,
                      height: 20,
                      color: rank == 1 
                          ? AppTheme.primaryColor 
                          : Colors.grey[400],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isExcluded ? Colors.grey[500] : Colors.grey[900],
                      decoration: isExcluded ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isExcluded ? Colors.grey[400] : Colors.grey[600],
                      decoration: isExcluded ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (distance != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: isExcluded ? Colors.grey[400] : AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${distance.toStringAsFixed(2)} km',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isExcluded ? Colors.grey[400] : AppTheme.primaryColor,
                            decoration: isExcluded ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Icon
            Icon(
              isMyList && _showRoute 
                  ? (isExcluded ? Icons.add_circle_outline : Icons.remove_circle_outline)
                  : Icons.chevron_right,
              color: isExcluded ? Colors.grey[400] : (isMyList && _showRoute ? AppTheme.primaryColor : Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

