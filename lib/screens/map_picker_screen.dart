import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../utils/permission_service.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late TextEditingController _addressController;
  late TextEditingController _landmarkController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _doorNumberController;

  LatLng _selectedLocation = const LatLng(28.6139, 77.2090); // Default location
  GoogleMapController? _mapController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Marker? _marker;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeLocation();
  }

  void _initializeControllers() {
    _addressController = TextEditingController();
    _landmarkController = TextEditingController();
    _latitudeController = TextEditingController(text: _selectedLocation.latitude.toStringAsFixed(6));
    _longitudeController = TextEditingController(text: _selectedLocation.longitude.toStringAsFixed(6));
    _doorNumberController = TextEditingController();
  }

  // Helper method to update location and sync controllers
  void _updateLocation(LatLng newLocation) {
    _selectedLocation = newLocation;
    _latitudeController.text = newLocation.latitude.toStringAsFixed(6);
    _longitudeController.text = newLocation.longitude.toStringAsFixed(6);
  }

  Future<void> _initializeLocation() async {
    if (widget.initialPosition != null) {
      setState(() {
        _updateLocation(widget.initialPosition!);
        _marker = Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onDragEnd: _onMarkerDragEnd,
        );
        _isLoading = false;
      });
      _getAddressFromCoordinates(_selectedLocation);
    } else {
      await _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Skip geolocator on Windows - use fallback UI instead
      if (_isWindows) {
        if (mounted) {
          setState(() {
            _marker = Marker(
              markerId: const MarkerId('selected_location'),
              position: _selectedLocation,
              draggable: true,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              onDragEnd: _onMarkerDragEnd,
            );
            _isLoading = false;
          });
          _getAddressFromCoordinates(_selectedLocation);
        }
        return;
      }

      if (!mounted) return;
      final hasPermission = await PermissionService.requestLocationPermission(context);
      if (!hasPermission) {
        // If permission denied, still show map with default location
        if (mounted) {
          setState(() {
            _marker = Marker(
              markerId: const MarkerId('selected_location'),
              position: _selectedLocation,
              draggable: true,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              onDragEnd: _onMarkerDragEnd,
            );
            _isLoading = false;
          });
          _getAddressFromCoordinates(_selectedLocation);
        }
        return;
      }

      // Skip geolocator on Windows
      if (_isWindows) {
        if (mounted) {
          setState(() {
            _marker = Marker(
              markerId: const MarkerId('selected_location'),
              position: _selectedLocation,
              draggable: true,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              onDragEnd: _onMarkerDragEnd,
            );
            _isLoading = false;
          });
          _getAddressFromCoordinates(_selectedLocation);
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _updateLocation(LatLng(position.latitude, position.longitude));
          _marker = Marker(
            markerId: const MarkerId('selected_location'),
            position: _selectedLocation,
            draggable: true,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onDragEnd: _onMarkerDragEnd,
          );
          _isLoading = false;
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(_selectedLocation, 15.0),
          );
        }

        _getAddressFromCoordinates(_selectedLocation);
      }
    } catch (e) {
      // On error, still show map with default location
      if (mounted) {
        setState(() {
          _marker = Marker(
            markerId: const MarkerId('selected_location'),
            position: _selectedLocation,
            draggable: true,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            onDragEnd: _onMarkerDragEnd,
          );
          _isLoading = false;
        });
        _getAddressFromCoordinates(_selectedLocation);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not get current location. You can still select a location on the map.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onMapTap(LatLng location) {
    if (!mounted) return;
    setState(() {
      _updateLocation(location);
      _marker = Marker(
        markerId: const MarkerId('selected_location'),
        position: location,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onDragEnd: _onMarkerDragEnd,
      );
    });
    // Animate camera to tapped location
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15.0),
      );
    }
    _getAddressFromCoordinates(location);
  }

  void _onMarkerDragEnd(LatLng newPosition) {
    setState(() {
      _updateLocation(newPosition);
      _marker = Marker(
        markerId: const MarkerId('selected_location'),
        position: newPosition,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onDragEnd: _onMarkerDragEnd,
      );
    });
    _getAddressFromCoordinates(newPosition);
  }

  Future<void> _getAddressFromCoordinates(LatLng location) async {
    if (!mounted) return;

    // Cancel any previous debounce timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start a new debounce timer
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      setState(() {
        // Loading address
      });

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          location.latitude,
          location.longitude,
        );

        if (mounted && placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          // Build full address string
          List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty) {
            addressParts.add(place.street!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          } else if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
            addressParts.add(place.subAdministrativeArea!);
          }
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }

          final fullAddress = addressParts.isNotEmpty 
              ? addressParts.join(', ')
              : 'Address not available';

          setState(() {
            _addressController.text = fullAddress;
            _latitudeController.text = location.latitude.toString();
            _longitudeController.text = location.longitude.toString();
          });
        } else if (mounted) {
          setState(() {
            _addressController.text = '';
          });
        }
      } catch (e) {
        // Error handled silently, address field remains editable
      }
    });
  }

  // Check if running on Windows
  bool get _isWindows => !kIsWeb && Platform.isWindows;

  // Windows fallback UI - manual location input
  Widget _buildWindowsFallback() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Select Location',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Google Maps is not available on Windows. Please enter your location manually or use the coordinates.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Address search
            Text(
              'Search Address',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _addressController,
                    'Enter address to search',
                    hintText: 'e.g., 123 Main St, City, Country',
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _searchAddress,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Coordinates input
            Text(
              'Or Enter Coordinates',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _latitudeController,
                    'Latitude',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    hintText: 'e.g., 40.7128',
                    onChanged: (value) {
                      final lat = double.tryParse(value);
                      if (lat != null && lat >= -90 && lat <= 90) {
                        setState(() {
                          _updateLocation(LatLng(lat, _selectedLocation.longitude));
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    _longitudeController,
                    'Longitude',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    hintText: 'e.g., -74.0060',
                    onChanged: (value) {
                      final lng = double.tryParse(value);
                      if (lng != null && lng >= -180 && lng <= 180) {
                        setState(() {
                          _updateLocation(LatLng(_selectedLocation.latitude, lng));
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                // Get address from coordinates
                await _getAddressFromCoordinates(_selectedLocation);
              },
              icon: const Icon(Icons.location_searching),
              label: const Text('Get Address from Coordinates'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            
            // Door number/street
            _buildTextField(
              _doorNumberController,
              'Door No, Street',
              maxLines: 2,
              hintText: 'e.g., 123 Main Street',
            ),
            const SizedBox(height: 16),
            
            // Current address display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Address:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _addressController.text.isEmpty 
                        ? 'No address selected' 
                        : _addressController.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Coordinates: ${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Open in browser button
            OutlinedButton.icon(
              onPressed: () async {
                final url = Uri.parse(
                  'https://www.google.com/maps?q=${_selectedLocation.latitude},${_selectedLocation.longitude}',
                );
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in Google Maps (Browser)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 24),
            
            // Confirm button
            ElevatedButton(
              onPressed: _confirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Confirm Location',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to create text field with onChanged
  // Search address function
  Future<void> _searchAddress() async {
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an address to search')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final locations = await locationFromAddress(_addressController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _updateLocation(LatLng(location.latitude, location.longitude));
          _isLoading = false;
        });
        await _getAddressFromCoordinates(_selectedLocation);
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'Address not found. Please try a different address.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error searching address: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Windows fallback - show manual input form
    if (_isWindows) {
      return _buildWindowsFallback();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          'Select Location on Map',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Get Current Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Map Error',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Unable to load map. Please check your Google Maps API key configuration.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Go Back',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation,
                zoom: 15.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                if (mounted) {
                  // Ensure marker is set when map is created
                  if (_marker == null) {
                    setState(() {
                      _marker = Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedLocation,
                        draggable: true,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        onDragEnd: _onMarkerDragEnd,
                      );
                      _isLoading = false;
                    });
                  }
                  
                  // Animate to selected location
                  try {
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(_selectedLocation, 15.0),
                    );
                  } catch (e) {
                    debugPrint('Error animating camera: $e');
                    // Don't set error state, just log it
                  }
                }
              },
              onTap: _onMapTap,
              markers: _marker != null ? {_marker!} : <Marker>{},
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              zoomControlsEnabled: true,
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),
          if (!_isLoading && !_hasError)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        _addressController,
                        'Door No, Street',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Address:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildText(
                              _addressController,
                              'Enter Address',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        _landmarkController,
                        'Landmark',
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                          GestureDetector(
                            onTap: _saveAddress,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 5),
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.primaryColor,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String labelText, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String hintText = '',
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14),
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        labelText: labelText,
        hintText: hintText,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppTheme.primaryColor,
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey[600],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildText(
    TextEditingController controller,
    String hintText, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.poppins(fontSize: 14),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  // Confirm selection for Windows fallback
  Future<void> _confirmSelection() async {
    await _saveAddress();
  }

  Future<void> _saveAddress() async {
    // Get full address details before confirming

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );

      Map<String, dynamic> selectedData;
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Combine door number with address if provided
        String fullAddress = _addressController.text.trim();
        if (_doorNumberController.text.trim().isNotEmpty) {
          fullAddress = '${_doorNumberController.text.trim()}, $fullAddress';
        }
        
        selectedData = {
          'latitude': _selectedLocation.latitude.toString(),
          'longitude': _selectedLocation.longitude.toString(),
          'address': fullAddress.isNotEmpty 
              ? fullAddress
              : (place.street ?? ''),
          'street': place.street ?? '',
          'city': place.locality ?? place.subAdministrativeArea ?? '',
          'state': place.administrativeArea ?? '',
          'pincode': place.postalCode ?? '',
          'landmark': _landmarkController.text.trim(),
        };
      } else {
        // Combine door number with address if provided
        String fullAddress = _addressController.text.trim();
        if (_doorNumberController.text.trim().isNotEmpty) {
          fullAddress = '${_doorNumberController.text.trim()}, $fullAddress';
        }
        
        selectedData = {
          'latitude': _selectedLocation.latitude.toString(),
          'longitude': _selectedLocation.longitude.toString(),
          'address': fullAddress,
          'street': '',
          'city': '',
          'state': '',
          'pincode': '',
          'landmark': _landmarkController.text.trim(),
        };
      }

      if (mounted) {
        Navigator.pop(context, selectedData);
      }
    } catch (e) {
      // If geocoding fails, still return coordinates
      // Combine door number with address if provided
      String fullAddress = _addressController.text.trim();
      if (_doorNumberController.text.trim().isNotEmpty) {
        fullAddress = '${_doorNumberController.text.trim()}, $fullAddress';
      }
      
      if (mounted) {
        Navigator.pop(context, {
          'latitude': _selectedLocation.latitude.toString(),
          'longitude': _selectedLocation.longitude.toString(),
          'address': fullAddress,
          'street': '',
          'city': '',
          'state': '',
          'pincode': '',
          'landmark': _landmarkController.text.trim(),
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    _landmarkController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _doorNumberController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

