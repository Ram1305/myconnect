import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../utils/theme.dart';
import '../utils/permission_service.dart';
import '../utils/api_service.dart';
import '../config/app_config.dart';
import 'login_screen.dart';
import 'map_picker_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // For admin editing other users
  final bool isAdminEdit; // Flag to indicate admin is editing
  final bool showAppBar;
  const ProfileScreen({
    super.key,
    this.userId,
    this.isAdminEdit = false,
    this.showAppBar = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditMode = false;
  bool _isUpdating = false;

  // Controllers
  late TextEditingController _usernameController;
  late TextEditingController _mobileController;
  late TextEditingController _secondaryMobileController;
  late TextEditingController _fatherNameController;
  late TextEditingController _grandfatherNameController;
  late TextEditingController _greatGrandfatherNameController;
  late TextEditingController _motherNameController;
  late TextEditingController _motherNativeController;
  late TextEditingController _grandmotherNameController;
  late TextEditingController _grandmotherNativeController;
  late TextEditingController _emailIdController;
  String? _selectedQualification;
  bool _hasEducation = false;
  // Education fields
  late TextEditingController _collegeController;
  late TextEditingController _yearOfCompletionController;
  late TextEditingController _courseController;
  late TextEditingController _startYearController;
  late TextEditingController _endYearController;
  List<Map<String, dynamic>> _extraDegrees = []; // List of extra degrees
  String? _selectedBloodGroup;
  late TextEditingController _companyNameController;
  late TextEditingController _positionController;
  late TextEditingController _businessNameController;
  late TextEditingController _businessTypeController;
  List<TextEditingController> _businessAddressControllers = [];
  // Student fields
  late TextEditingController _collegeNameController;
  late TextEditingController _studentYearController;
  late TextEditingController _departmentController;

  File? _newProfilePhoto;
  String? _currentProfilePhotoUrl;
  Map<String, dynamic>? _currentAddress;
  Map<String, dynamic>? _nativeAddress;
  bool _useSameAddress = false;
  bool _isWorking = false;
  bool _isBusiness = true; // Default to Business enabled
  String? _professionType = 'business'; // 'business', 'job', 'student'
  String? _workingMeans;
  int? _yearsExperience;

  // New fields
  DateTime? _dateOfBirth;
  String? _maritalStatus;
  late TextEditingController _spouseNameController;
  late TextEditingController _spouseNativeController;
  File? _newSpousePhoto;
  String? _currentSpousePhotoUrl;
  int _totalKids = 0;
  List<Map<String, dynamic>> _kids = []; // Each kid: {name, photo, dateOfBirth, schoolName, standard}
  File? _newFamilyPhoto;
  String? _currentFamilyPhotoUrl;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty values first
    _usernameController = TextEditingController();
    _mobileController = TextEditingController();
    _secondaryMobileController = TextEditingController();
    _fatherNameController = TextEditingController();
    _grandfatherNameController = TextEditingController();
    _greatGrandfatherNameController = TextEditingController();
    _motherNameController = TextEditingController();
    _motherNativeController = TextEditingController();
    _grandmotherNameController = TextEditingController();
    _grandmotherNativeController = TextEditingController();
    _emailIdController = TextEditingController();
    _collegeController = TextEditingController();
    _yearOfCompletionController = TextEditingController();
    _courseController = TextEditingController();
    _startYearController = TextEditingController();
    _endYearController = TextEditingController();
    _companyNameController = TextEditingController();
    _positionController = TextEditingController();
    _businessNameController = TextEditingController();
    _businessTypeController = TextEditingController();
    _businessAddressControllers = [TextEditingController()]; // Start with one address
    _collegeNameController = TextEditingController();
    _studentYearController = TextEditingController();
    _departmentController = TextEditingController();
    _spouseNameController = TextEditingController();
    _spouseNativeController = TextEditingController();
    
    // Fetch fresh data from backend including image
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    // Fetch fresh data from backend including image
    if (widget.userId != null && widget.isAdminEdit) {
      // Admin editing another user
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = await userProvider.getUserById(widget.userId!);
      if (mounted) {
        _updateControllersFromUser(user);
      }
    } else {
      // Regular user editing own profile
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.getCurrentUser();
      
      // Update controllers with fresh data
      if (mounted) {
        _updateControllers();
      }
    }
  }
  
  void _updateControllersFromUser(Map<String, dynamic> user) {
    setState(() {
      _updateControllersWithUserData(user);
    });
  }
  
  void _updateControllersWithUserData(Map<String, dynamic> user) {
    // Update all controllers with user data
    _usernameController.text = user['username'] ?? '';
    _mobileController.text = user['mobileNumber'] ?? '';
    _secondaryMobileController.text = user['secondaryMobileNumber'] ?? '';
    _fatherNameController.text = user['fatherName'] ?? '';
    _grandfatherNameController.text = user['grandfatherName'] ?? '';
    _greatGrandfatherNameController.text = user['greatGrandfatherName'] ?? '';
    _motherNameController.text = user['motherName'] ?? '';
    _motherNativeController.text = user['motherNative'] ?? '';
    _grandmotherNameController.text = user['grandmotherName'] ?? '';
    _grandmotherNativeController.text = user['grandmotherNative'] ?? '';
    _emailIdController.text = user['emailId'] ?? '';
    _selectedBloodGroup = user['bloodGroup'];
    _selectedQualification = user['highestQualification'] ?? '';
    _hasEducation = user['hasEducation'] ?? false;
    _collegeController.text = user['college'] ?? '';
    _yearOfCompletionController.text = user['yearOfCompletion'] ?? '';
    _courseController.text = user['course'] ?? '';
    _startYearController.text = user['startYear'] ?? '';
    _endYearController.text = user['endYear'] ?? '';
    _extraDegrees = user['extraDegrees'] != null && user['extraDegrees'] is List
        ? List<Map<String, dynamic>>.from(user['extraDegrees'])
        : [];
    if (user['dateOfBirth'] != null) {
      try {
        _dateOfBirth = DateTime.parse(user['dateOfBirth']);
      } catch (e) {
        _dateOfBirth = null;
      }
    }
    _maritalStatus = user['maritalStatus'];
    _spouseNameController.text = user['spouseName'] ?? '';
    _spouseNativeController.text = user['spouseNative'] ?? '';
    _currentSpousePhotoUrl = user['spousePhoto'];
    if (user['kids'] != null && user['kids'] is List) {
      _totalKids = (user['kids'] as List).length;
      _kids = List<Map<String, dynamic>>.from(user['kids']);
    }
    _currentFamilyPhotoUrl = user['familyPhoto'];
    _currentAddress = user['currentAddress'];
    _nativeAddress = user['nativeAddress'];
    _useSameAddress = user['useSameAddress'] ?? false;
    _isWorking = user['workingDetails']?['isWorking'] ?? false;
    _isBusiness = user['workingDetails']?['isBusiness'] ?? false;
    _professionType = user['workingDetails']?['professionType']?.toString() ?? (_isBusiness ? 'business' : 'job');
    _workingMeans = user['workingDetails']?['workingMeans'];
    _yearsExperience = user['workingDetails']?['totalYearsExperience'];
    
    // Load student fields
    final workingDetails = user['workingDetails'] as Map<String, dynamic>?;
    if (workingDetails != null) {
      _collegeNameController.text = workingDetails['collegeName'] ?? '';
      _studentYearController.text = workingDetails['studentYear'] ?? '';
      _departmentController.text = workingDetails['department'] ?? '';
    }
    
    _currentProfilePhotoUrl = user['profilePhoto'];
    
    // Set edit mode if admin editing
    if (widget.isAdminEdit) {
      _isEditMode = true;
    }
  }

  void _updateControllers() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user ?? {};

    // Update controller values
    _usernameController.text = user['username'] ?? '';
    _mobileController.text = user['mobileNumber'] ?? '';
    _secondaryMobileController.text = user['secondaryMobileNumber'] ?? '';
    _fatherNameController.text = user['fatherName'] ?? '';
    _grandfatherNameController.text = user['grandfatherName'] ?? '';
    _greatGrandfatherNameController.text = user['greatGrandfatherName'] ?? '';
    _motherNameController.text = user['motherName'] ?? '';
    _motherNativeController.text = user['motherNative'] ?? '';
    _grandmotherNameController.text = user['grandmotherName'] ?? '';
    _grandmotherNativeController.text = user['grandmotherNative'] ?? '';
    _hasEducation = user['hasEducation'] ?? false;
    _collegeController.text = user['college'] ?? '';
    _yearOfCompletionController.text = user['yearOfCompletion'] ?? '';
    _courseController.text = user['course'] ?? '';
    _startYearController.text = user['startYear'] ?? '';
    _endYearController.text = user['endYear'] ?? '';
    _extraDegrees = user['extraDegrees'] != null && user['extraDegrees'] is List
        ? List<Map<String, dynamic>>.from(user['extraDegrees'])
        : [];
    _emailIdController.text = user['emailId'] ?? '';
    _selectedQualification = user['highestQualification'] ?? '';
    _selectedBloodGroup = user['bloodGroup'];

    // Load new fields
    if (user['dateOfBirth'] != null) {
      try {
        _dateOfBirth = user['dateOfBirth'] is DateTime 
            ? user['dateOfBirth'] 
            : DateTime.parse(user['dateOfBirth'].toString());
      } catch (e) {
        _dateOfBirth = null;
      }
    }
    _maritalStatus = user['maritalStatus'];
    _spouseNameController.text = user['spouseName'] ?? '';
    _spouseNativeController.text = user['spouseNative'] ?? '';
    _currentSpousePhotoUrl = user['spousePhoto'];
    
    // Load kids - preserve photo URLs from backend
    if (user['kids'] != null && user['kids'] is List) {
      _kids = (user['kids'] as List).map((kid) {
        return {
          'name': kid['name'] ?? '',
          'photo': kid['photo'] ?? '', // Keep as string URL from backend
          'dateOfBirth': kid['dateOfBirth'] != null 
              ? (kid['dateOfBirth'] is DateTime 
                  ? kid['dateOfBirth'].toIso8601String() 
                  : kid['dateOfBirth'].toString())
              : null,
          'schoolName': kid['schoolName'] ?? '',
          'standard': kid['standard'] ?? '',
        };
      }).toList();
      _totalKids = _kids.length;
    } else {
      _kids = [];
      _totalKids = 0;
    }
    
    _currentFamilyPhotoUrl = user['familyPhoto'];

    _currentProfilePhotoUrl = user['profilePhoto'];
    _currentAddress = user['currentAddress'];
    _nativeAddress = user['nativeAddress'];
    _useSameAddress = user['useSameAddress'] ?? false;

    final workingDetails = user['workingDetails'] as Map<String, dynamic>?;
    if (workingDetails != null) {
      _isWorking = workingDetails['isWorking'] ?? false;
      _isBusiness = workingDetails['isBusiness'] ?? false;
      _professionType = workingDetails['professionType']?.toString() ?? (_isBusiness ? 'business' : 'job');
      _workingMeans = workingDetails['workingMeans'];
      _yearsExperience = workingDetails['totalYearsExperience'];

      _companyNameController.text = workingDetails['companyName'] ?? '';
      _positionController.text = workingDetails['position'] ?? '';
      _businessNameController.text = workingDetails['businessName'] ?? '';
      _businessTypeController.text = workingDetails['businessType'] ?? '';
      
      // Load student fields
      _collegeNameController.text = workingDetails['collegeName'] ?? '';
      _studentYearController.text = workingDetails['studentYear'] ?? '';
      _departmentController.text = workingDetails['department'] ?? '';
      
      // Load multiple business addresses
      _businessAddressControllers.forEach((controller) => controller.dispose());
      _businessAddressControllers.clear();
      
      if (workingDetails['businessAddresses'] != null && workingDetails['businessAddresses'] is List) {
        final addresses = workingDetails['businessAddresses'] as List;
        if (addresses.isNotEmpty) {
          _businessAddressControllers = addresses.map((addr) => TextEditingController(text: addr.toString())).toList();
        } else {
          // Fallback to single businessAddress for backward compatibility
          final singleAddr = workingDetails['businessAddress']?.toString() ?? '';
          if (singleAddr.isNotEmpty) {
            _businessAddressControllers = [TextEditingController(text: singleAddr)];
          } else {
            _businessAddressControllers = [TextEditingController()];
          }
        }
      } else {
        // Fallback to single businessAddress for backward compatibility
        final singleAddr = workingDetails['businessAddress']?.toString() ?? '';
        if (singleAddr.isNotEmpty) {
          _businessAddressControllers = [TextEditingController(text: singleAddr)];
        } else {
          _businessAddressControllers = [TextEditingController()];
        }
      }
    } else {
      _companyNameController.text = '';
      _positionController.text = '';
      _businessNameController.text = '';
      _businessTypeController.text = '';
      _collegeNameController.text = '';
      _studentYearController.text = '';
      _departmentController.text = '';
      _businessAddressControllers.forEach((controller) => controller.dispose());
      _businessAddressControllers = [TextEditingController()];
    }
    
    if (mounted) {
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              titleSpacing: 0,
              centerTitle: true,
              title: Text(
                _isEditMode ? 'Edit Profile' : 'Profile',
                style: GoogleFonts.poppins(),
              ),
              actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditMode = true),
              tooltip: 'Edit Profile',
            ),
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleLogout,
              tooltip: 'Logout',
              color: AppConfig.primaryColor,
            ),
          if (_isEditMode && !widget.isAdminEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _showDeleteAccountConfirmation,
              tooltip: 'Delete Account',
            ),
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditMode = false;
                  _newProfilePhoto = null;
                  _updateControllers();
                });
              },
              tooltip: 'Cancel',
            ),
        ],
            )
          : null,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppConfig.backgroundColor,
                  AppConfig.lightGold,
                ],
              ),
            ),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                final user = authProvider.user;

                if (user == null) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Update controllers when user data changes
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_isEditMode) {
                    _updateControllers();
                  }
                });

                return Stack(
                  children: [
                    // Fully scrollable content
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          // Profile Header
                          _buildProfileHeader(user),

                          // Profile Details
                          _isEditMode
                              ? _buildEditModeList()
                              : _buildViewModeList(user),
                        ],
                      ),
                    ),

                    // Floating Update Button (only in edit mode)
                    if (_isEditMode)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child:FloatingActionButton.extended(
                          onPressed: _showUpdateConfirmation,
                          backgroundColor: AppTheme.primaryColor,
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: Text(
                            'Update',
                            style: GoogleFonts.poppins(
                              fontSize: 14, // reduce text size slightly
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          extendedPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          elevation: 6,
                        )

                      ),
                  ],
                );
              },
            ),
          ),

          // Loading Overlay
          if (_isUpdating)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Updating Profile...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditMode ? _pickProfilePhoto : null,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _newProfilePhoto != null
                        ? Image.file(_newProfilePhoto!, fit: BoxFit.cover)
                        : (_currentProfilePhotoUrl != null && _currentProfilePhotoUrl!.isNotEmpty)
                        ? Image.network(_currentProfilePhotoUrl!, fit: BoxFit.cover)
                        : Container(
                      color: AppTheme.lightGold,
                      child: Icon(
                        Icons.person,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                if (_isEditMode)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user['username'] ?? 'User',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          _buildStatusBadge(user['status']),
        ],
      ),
    );
  }

  Widget _buildViewModeList(Map<String, dynamic> user) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
        _buildSectionHeader('Personal Information'),
        _buildInfoCard([
          _buildInfoTile(Icons.person_outline, 'Username', user['username'] ?? 'N/A'),
          if (user['dateOfBirth'] != null)
            _buildInfoTile(Icons.calendar_today, 'Date of Birth', _formatDate(user['dateOfBirth'])),
          _buildInfoTile(Icons.family_restroom, 'Father Name', user['fatherName'] ?? 'N/A'),
          _buildInfoTile(Icons.people_outline, 'Grandfather Name', user['grandfatherName'] ?? 'N/A'),
          if (user['greatGrandfatherName'] != null && user['greatGrandfatherName'].toString().isNotEmpty)
            _buildInfoTile(Icons.people_outline, 'Great Grandfather Name', user['greatGrandfatherName']),
          _buildInfoTile(Icons.phone_outlined, 'Mobile Number', user['mobileNumber'] ?? 'N/A'),
          if (user['secondaryMobileNumber'] != null && user['secondaryMobileNumber'].toString().isNotEmpty)
            _buildInfoTile(Icons.phone_outlined, 'Secondary Mobile Number', user['secondaryMobileNumber']),
          if (user['emailId'] != null && user['emailId'].toString().isNotEmpty)
            _buildInfoTile(Icons.email_outlined, 'Email ID', user['emailId']),
          if (user['bloodGroup'] != null)
            _buildInfoTile(Icons.bloodtype, 'Blood Group', user['bloodGroup']),
          if (user['motherName'] != null && user['motherName'].toString().isNotEmpty)
            _buildInfoTile(Icons.person_outline, 'Mother Name', user['motherName']),
          if (user['motherNative'] != null && user['motherNative'].toString().isNotEmpty)
            _buildInfoTile(Icons.location_on_outlined, 'Mother Native', user['motherNative']),
          if (user['grandmotherName'] != null && user['grandmotherName'].toString().isNotEmpty)
            _buildInfoTile(Icons.person_outline, 'Grandmother Name', user['grandmotherName']),
          if (user['grandmotherNative'] != null && user['grandmotherNative'].toString().isNotEmpty)
            _buildInfoTile(Icons.location_on_outlined, 'Grandmother Native', user['grandmotherNative']),
          if (user['maritalStatus'] != null)
            _buildInfoTile(Icons.favorite, 'Marital Status', user['maritalStatus']),
          if (user['maritalStatus'] == 'Married') ...[
            if (user['spouseName'] != null)
              _buildInfoTile(Icons.person, 'Spouse Name', user['spouseName']),
            if (user['spouseNative'] != null && user['spouseNative'].toString().isNotEmpty)
              _buildInfoTile(Icons.location_on_outlined, 'Spouse Native', user['spouseNative']),
            if (user['spousePhoto'] != null && user['spousePhoto'].isNotEmpty)
              _buildPhotoTile('Spouse Photo', user['spousePhoto']),
          ],
          if (user['maritalStatus'] == 'Married' && user['kids'] != null && (user['kids'] as List).isNotEmpty)
            _buildKidsInfoTile(user['kids']),
          _buildInfoTile(Icons.school_outlined, 'Qualification', user['highestQualification'] ?? 'N/A'),
          if (user['hasEducation'] == true) ...[
            if (user['college'] != null && user['college'].toString().isNotEmpty)
              _buildInfoTile(Icons.school, 'College', user['college']),
            if (user['yearOfCompletion'] != null && user['yearOfCompletion'].toString().isNotEmpty)
              _buildInfoTile(Icons.calendar_today, 'Year of Completion', user['yearOfCompletion']),
            if (user['course'] != null && user['course'].toString().isNotEmpty)
              _buildInfoTile(Icons.book, 'Course', user['course']),
            if (user['startYear'] != null && user['startYear'].toString().isNotEmpty)
              _buildInfoTile(Icons.calendar_today, 'Start Year', user['startYear']),
            if (user['endYear'] != null && user['endYear'].toString().isNotEmpty)
              _buildInfoTile(Icons.calendar_today, 'End Year', user['endYear']),
            if (user['extraDegrees'] != null && (user['extraDegrees'] as List).isNotEmpty)
              _buildExtraDegreesInfoTile(user['extraDegrees']),
          ],
          if (user['familyPhoto'] != null && user['familyPhoto'].isNotEmpty)
            _buildPhotoTile('Family Photo', user['familyPhoto']),
        ]),

        const SizedBox(height: 24),
        _buildSectionHeader('Address Information'),
        _buildInfoCard([
          _buildAddressTile(Icons.home_outlined, 'Current Address', user['currentAddress']),
          _buildAddressTile(Icons.location_on_outlined, 'Native Address', user['nativeAddress']),
        ]),

        const SizedBox(height: 24),
        _buildSectionHeader('Professional Details'),
        _buildWorkInfoCard(user['workingDetails']),

        const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildEditModeList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
        _buildSectionHeader('Personal Information'),
        _buildEditCard([
          _buildEditField('Username', _usernameController, Icons.person_outline),
          _buildDateOfBirthField(),
          _buildEditField('Father Name', _fatherNameController, Icons.family_restroom),
          _buildEditField('Grandfather Name', _grandfatherNameController, Icons.people_outline),
          _buildEditField('Great Grandfather Name', _greatGrandfatherNameController, Icons.people_outline),
          _buildEditField('Mobile Number', _mobileController, Icons.phone_outlined, keyboardType: TextInputType.phone),
          _buildEditField('Secondary Mobile Number', _secondaryMobileController, Icons.phone_outlined, keyboardType: TextInputType.phone),
          _buildEditField('Email ID', _emailIdController, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
          _buildBloodGroupDropdown(),
          _buildEditField('Mother Name', _motherNameController, Icons.person_outline),
          _buildEditField('Mother Native', _motherNativeController, Icons.location_on_outlined),
          _buildEditField('Grandmother Name', _grandmotherNameController, Icons.person_outline),
          _buildEditField('Grandmother Native', _grandmotherNativeController, Icons.location_on_outlined),
          _buildMaritalStatusDropdown(),
          if (_maritalStatus == 'Married') ...[
            _buildEditField('Spouse Name', _spouseNameController, Icons.person),
            _buildEditField('Spouse Native', _spouseNativeController, Icons.location_on_outlined),
            _buildSpousePhotoField(),
          ],
          if (_maritalStatus == 'Married') _buildKidsSection(),
          _buildQualificationDropdown(),
          _buildEducationToggle(),
          if (_hasEducation) ...[
            _buildEditField('College', _collegeController, Icons.school),
            _buildEditField('Year of Completion', _yearOfCompletionController, Icons.calendar_today),
            _buildEditField('Course', _courseController, Icons.book),
            _buildEditField('Start Year', _startYearController, Icons.calendar_today),
            _buildEditField('End Year', _endYearController, Icons.calendar_today),
            _buildExtraDegreesSection(),
          ],
          _buildFamilyPhotoField(),
        ]),

        const SizedBox(height: 24),
        _buildSectionHeader('Address Information'),
        _buildEditCard([
          _buildAddressEditTile('Current Address', true),
          const SizedBox(height: 16),
          _buildSameAddressToggle(),
          if (!_useSameAddress) ...[
            const SizedBox(height: 16),
            _buildAddressEditTile('Native Address', false),
          ],
        ]),

        const SizedBox(height: 24),
        _buildSectionHeader('Professional Details'),
        _buildWorkEditCard(),

        if (!widget.isAdminEdit) ...[
          const SizedBox(height: 40),
          _buildDeleteAccountSection(),
        ],

        const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildEditCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.lightGold.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = date is DateTime ? date : DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildPhotoTile(String label, String photoUrl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              photoUrl,
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 150,
                  height: 150,
                  color: Colors.grey[200],
                  child: Icon(Icons.image_not_supported, color: Colors.grey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidsInfoTile(List kids) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.lightGold.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.child_care, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                'Kids (${kids.length})',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...kids.asMap().entries.map((entry) {
            final index = entry.key;
            final kid = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  if (kid['photo'] != null && kid['photo'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        kid['photo'].toString(),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: Icon(Icons.person, size: 30),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.person, size: 30),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kid['name']?.toString() ?? 'Kid ${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (kid['dateOfBirth'] != null)
                          Text(
                            'DOB: ${_formatDate(kid['dateOfBirth'])}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (kid['schoolName'] != null && kid['schoolName'].toString().isNotEmpty)
                          Text(
                            'School: ${kid['schoolName']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (kid['standard'] != null && kid['standard'].toString().isNotEmpty)
                          Text(
                            'Standard: ${kid['standard']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAddressTile(IconData icon, String label, Map<String, dynamic>? address) {
    final addressText = address?['address'] ?? 'Not provided';
    final state = address?['state'] ?? '';
    final pincode = address?['pincode'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.lightGold.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  addressText,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                if (state.isNotEmpty || pincode.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [state, pincode].where((s) => s.isNotEmpty).join(', '),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkInfoCard(Map<String, dynamic>? workingDetails) {
    if (workingDetails == null) {
      return const SizedBox.shrink();
    }

    final professionType = workingDetails['professionType']?.toString() ?? '';
    final isBusiness = workingDetails['isBusiness'] ?? false || professionType == 'business';

    List<Widget> workInfoTiles = [];

    if (professionType == 'business' || isBusiness) {
      // Business: Only Business Type, Business Name, and Business Address(es)
      workInfoTiles.addAll([
        _buildInfoTile(Icons.business_center, 'Business Type', workingDetails['businessType'] ?? 'N/A'),
        _buildInfoTile(Icons.store, 'Business Name', workingDetails['businessName'] ?? 'N/A'),
      ]);
      
      // Display multiple business addresses
      List<String> businessAddresses = [];
      if (workingDetails['businessAddresses'] != null && workingDetails['businessAddresses'] is List) {
        businessAddresses = (workingDetails['businessAddresses'] as List)
            .map((addr) => addr.toString())
            .where((addr) => addr.isNotEmpty)
            .toList();
      }
      // Fallback to single address for backward compatibility
      if (businessAddresses.isEmpty) {
        final singleAddr = workingDetails['businessAddress']?.toString() ?? '';
        if (singleAddr.isNotEmpty) {
          businessAddresses = [singleAddr];
        }
      }
      
      if (businessAddresses.isNotEmpty) {
        if (businessAddresses.length == 1) {
          workInfoTiles.add(_buildInfoTile(Icons.location_on_outlined, 'Business Address', businessAddresses[0]));
        } else {
          // Multiple addresses - show as a special tile
          workInfoTiles.add(
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGold.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.location_on_outlined, color: AppTheme.primaryColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Business Addresses',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...businessAddresses.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 50, top: 4),
                      child: Text(
                        '${entry.key + 1}. ${entry.value}',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
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
    } else if (professionType == 'job' || (!isBusiness && professionType != 'student')) {
      // Job: Company Name, Position, Working Means, Years of Experience
      workInfoTiles.addAll([
        _buildInfoTile(Icons.apartment, 'Company Name', workingDetails['companyName'] ?? 'N/A'),
        _buildInfoTile(Icons.badge, 'Position', workingDetails['position'] ?? 'N/A'),
        _buildInfoTile(Icons.timer, 'Working Type', workingDetails['workingMeans'] ?? 'N/A'),
        _buildInfoTile(
          Icons.calendar_today,
          'Years of Experience',
          '${workingDetails['totalYearsExperience'] ?? 0} years',
        ),
      ]);
    } else if (professionType == 'student') {
      // Student: College Name, Year, Department
      workInfoTiles.addAll([
        _buildInfoTile(Icons.school, 'College Name', workingDetails['collegeName'] ?? 'N/A'),
        _buildInfoTile(Icons.calendar_today, 'Year', workingDetails['studentYear'] ?? 'N/A'),
        _buildInfoTile(Icons.class_, 'Department', workingDetails['department'] ?? 'N/A'),
      ]);
    }

    if (workInfoTiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildInfoCard(workInfoTiles);
  }

  Widget _buildEditField(
      String label,
      TextEditingController controller,
      IconData icon, {
        TextInputType? keyboardType,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildQualificationDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedQualification != null && 
              ['SSLC', 'HSC', 'Graduate', 'Undergraduate', 'Post Graduate', 'Doctorate', 'Others', 'NA'].contains(_selectedQualification)
            ? _selectedQualification
            : null,
        decoration: InputDecoration(
          labelText: 'Qualification',
          prefixIcon: Icon(Icons.school_outlined, color: AppTheme.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        items: ['SSLC', 'HSC', 'Graduate', 'Undergraduate', 'Post Graduate', 'Doctorate', 'Others', 'NA']
            .map((qualification) => DropdownMenuItem<String>(
                  value: qualification,
                  child: Text(qualification),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedQualification = value;
          });
        },
      ),
    );
  }

  Widget _buildBloodGroupDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedBloodGroup,
        decoration: InputDecoration(
          labelText: 'Blood Group',
          prefixIcon: Icon(Icons.bloodtype, color: AppTheme.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
            .map((bloodGroup) => DropdownMenuItem<String>(
                  value: bloodGroup,
                  child: Text(bloodGroup),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedBloodGroup = value;
          });
        },
      ),
    );
  }

  Widget _buildEducationToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Have Education Details?',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          SizedBox(
            height: 35,
            child: AnimatedToggleSwitch<bool>.dual(
              current: _hasEducation,
              first: false,
              second: true,
              spacing: 10.0,
              style: ToggleStyle(
                backgroundColor: AppTheme.lightGold,
                borderColor: Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 2,
                  ),
                ],
              ),
              styleBuilder: (isSelected) => ToggleStyle(
                indicatorColor: isSelected
                    ? AppTheme.primaryColor
                    : Colors.red,
                borderColor: Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              onChanged: (value) => setState(() => _hasEducation = value),
              iconBuilder: (value) => value
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : const Icon(Icons.close, color: Colors.white, size: 18),
              textBuilder: (value) => Center(
                child: Text(
                  value ? 'Yes' : 'No',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraDegreesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Extra Degrees',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: AppTheme.primaryColor),
              onPressed: () {
                setState(() {
                  _extraDegrees.add({
                    'degree': '',
                    'college': '',
                    'year': '',
                  });
                });
              },
            ),
          ],
        ),
        ..._extraDegrees.asMap().entries.map((entry) {
          final index = entry.key;
          final degree = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    initialValue: degree['degree'] ?? '',
                    decoration: const InputDecoration(labelText: 'Degree'),
                    onChanged: (value) {
                      _extraDegrees[index]['degree'] = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: degree['college'] ?? '',
                    decoration: const InputDecoration(labelText: 'College'),
                    onChanged: (value) {
                      _extraDegrees[index]['college'] = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: degree['year'] ?? '',
                    decoration: const InputDecoration(labelText: 'Year'),
                    onChanged: (value) {
                      _extraDegrees[index]['year'] = value;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _extraDegrees.removeAt(index);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildExtraDegreesInfoTile(List<dynamic> extraDegrees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: extraDegrees.map((degree) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (degree['degree'] != null && degree['degree'].toString().isNotEmpty)
                _buildInfoTile(Icons.school, 'Degree', degree['degree']),
              if (degree['college'] != null && degree['college'].toString().isNotEmpty)
                _buildInfoTile(Icons.school, 'College', degree['college']),
              if (degree['year'] != null && degree['year'].toString().isNotEmpty)
                _buildInfoTile(Icons.calendar_today, 'Year', degree['year']),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateOfBirthField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            setState(() {
              _dateOfBirth = picked;
            });
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
          child: Text(
            _dateOfBirth != null
                ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                : 'Select Date of Birth',
            style: GoogleFonts.poppins(
              color: _dateOfBirth != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaritalStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _maritalStatus,
        decoration: InputDecoration(
          labelText: 'Marital Status',
          prefixIcon: Icon(Icons.favorite, color: AppTheme.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        items: ['Married', 'Unmarried']
            .map((status) => DropdownMenuItem<String>(
                  value: status,
                  child: Text(status),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _maritalStatus = value;
            if (value == 'Unmarried') {
              _spouseNameController.clear();
              _spouseNativeController.clear();
              _newSpousePhoto = null;
              _currentSpousePhotoUrl = null;
              _totalKids = 0;
              _kids = [];
            }
          });
        },
      ),
    );
  }

  Widget _buildSpousePhotoField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spouse Photo',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickSpousePhoto,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: _newSpousePhoto != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_newSpousePhoto!, fit: BoxFit.cover),
                    )
                  : (_currentSpousePhotoUrl != null && _currentSpousePhotoUrl!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(_currentSpousePhotoUrl!, fit: BoxFit.cover),
                        )
                      : Icon(Icons.add_photo_alternate, color: AppTheme.primaryColor, size: 40),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKidsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<int>(
            value: _totalKids > 0 ? _totalKids : null,
            decoration: InputDecoration(
              labelText: 'Total Kids',
              prefixIcon: Icon(Icons.child_care, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
              ),
            ),
            items: List.generate(10, (i) => i + 1)
                .map((count) => DropdownMenuItem<int>(
                      value: count,
                      child: Text('$count'),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _totalKids = value ?? 0;
                // Adjust kids list to match count
                while (_kids.length < _totalKids) {
                  _kids.add({'name': '', 'photo': '', 'dateOfBirth': null, 'schoolName': '', 'standard': ''});
                }
                while (_kids.length > _totalKids) {
                  _kids.removeLast();
                }
              });
            },
          ),
        ),
        if (_totalKids > 0) ...[
          ...List.generate(_totalKids, (index) => _buildKidFields(index)),
        ],
      ],
    );
  }

  Widget _buildKidFields(int index) {
    if (index >= _kids.length) {
      _kids.add({'name': '', 'photo': '', 'dateOfBirth': null, 'schoolName': '', 'standard': ''});
    }
    final kid = _kids[index];
    final nameController = TextEditingController(text: kid['name'] ?? '');
    final schoolNameController = TextEditingController(text: kid['schoolName'] ?? '');
    final standardController = TextEditingController(text: kid['standard'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kid ${index + 1}',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              _kids[index]['name'] = value;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: kid['dateOfBirth'] != null
                          ? DateTime.parse(kid['dateOfBirth'].toString())
                          : DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _kids[index]['dateOfBirth'] = picked.toIso8601String();
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      kid['dateOfBirth'] != null
                          ? DateFormat('dd/MM/yyyy').format(DateTime.parse(kid['dateOfBirth']))
                          : 'Select DOB',
                      style: GoogleFonts.poppins(
                        color: kid['dateOfBirth'] != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _pickKidPhoto(index),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child: kid['photo'] != null && kid['photo'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kid['photo'] is File
                              ? Image.file(kid['photo'] as File, fit: BoxFit.cover)
                              : (kid['photo'].toString().startsWith('http') || kid['photo'].toString().startsWith('/'))
                                  ? Image.network(kid['photo'].toString(), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.image_not_supported, color: Colors.grey, size: 30);
                                    })
                                  : Icon(Icons.add_photo_alternate, color: AppTheme.primaryColor, size: 30),
                        )
                      : Icon(Icons.add_photo_alternate, color: AppTheme.primaryColor, size: 30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: schoolNameController,
            decoration: InputDecoration(
              labelText: 'School Name',
              prefixIcon: Icon(Icons.school, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              _kids[index]['schoolName'] = value;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: standardController,
            decoration: InputDecoration(
              labelText: 'Standard',
              prefixIcon: Icon(Icons.class_, color: AppTheme.primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              _kids[index]['standard'] = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyPhotoField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Family Photo',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickFamilyPhoto,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: _newFamilyPhoto != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_newFamilyPhoto!, fit: BoxFit.cover),
                    )
                  : (_currentFamilyPhotoUrl != null && _currentFamilyPhotoUrl!.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(_currentFamilyPhotoUrl!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, color: AppTheme.primaryColor, size: 50),
                            const SizedBox(height: 8),
                            Text(
                              'Add Family Photo',
                              style: GoogleFonts.poppins(color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressEditTile(String label, bool isCurrent) {
    final address = isCurrent ? _currentAddress : _nativeAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _selectAddress(isCurrent),
              icon: const Icon(Icons.map, size: 16),
              label: Text(
                'Select',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        if (address != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.lightGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address['address'] ?? 'N/A',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '${address['state']}, ${address['pincode']}',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSameAddressToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Same as Current Address',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
        ),
        SizedBox(
          height: 35,
          child: AnimatedToggleSwitch<bool>.dual(
            current: _useSameAddress,
            first: false,
            second: true,
            spacing: 10.0,
            style: ToggleStyle(
              backgroundColor: AppTheme.lightGold,
              borderColor: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            styleBuilder: (isSelected) => ToggleStyle(
              indicatorColor: isSelected
                  ? AppTheme.primaryColor
                  : Colors.red,
              borderColor: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            onChanged: (value) {
              setState(() {
                _useSameAddress = value;
                if (value) {
                  _nativeAddress = _currentAddress;
                }
              });
            },
            iconBuilder: (value) => value
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : const Icon(Icons.close, color: Colors.white, size: 18),
            textBuilder: (value) => Center(
              child: Text(
                value ? 'Yes' : 'No',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkEditCard() {
    return _buildEditCard([
      Text(
        'Profession',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[800],
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _professionType,
        decoration: InputDecoration(
          labelText: 'Select Profession',
          prefixIcon: Icon(Icons.work, color: AppTheme.primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
        ),
        items: [
          DropdownMenuItem(value: 'business', child: Text('Business')),
          DropdownMenuItem(value: 'job', child: Text('Job')),
          DropdownMenuItem(value: 'student', child: Text('Student')),
        ],
        onChanged: (value) {
          setState(() {
            _professionType = value;
            _isBusiness = value == 'business';
          });
        },
      ),
      const SizedBox(height: 16),
      // Business details - shown when Business is selected
      if (_professionType == 'business') ...[
        _buildEditField('Business Type', _businessTypeController, Icons.business_center),
        _buildEditField('Business Name', _businessNameController, Icons.store),
        const SizedBox(height: 16),
        // Multiple Business Addresses
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Business Addresses',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: AppTheme.primaryColor),
              onPressed: () {
                setState(() {
                  _businessAddressControllers.add(TextEditingController());
                });
              },
              tooltip: 'Add Address',
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_businessAddressControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildEditField(
                    'Business Address ${index + 1}',
                    _businessAddressControllers[index],
                    Icons.location_on_outlined,
                  ),
                ),
                if (_businessAddressControllers.length > 1)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _businessAddressControllers[index].dispose();
                        _businessAddressControllers.removeAt(index);
                      });
                    },
                    tooltip: 'Remove Address',
                  ),
              ],
            ),
          );
        }),
      ],
      // Job details - shown when Job is selected
      if (_professionType == 'job') ...[
        _buildEditField('Company Name', _companyNameController, Icons.apartment),
        _buildEditField('Position', _positionController, Icons.badge),
        DropdownButtonFormField<String>(
          value: _workingMeans != null && ['Full-time', 'Part-time', 'Contract', 'Freelance'].contains(_workingMeans)
              ? _workingMeans
              : null,
          decoration: InputDecoration(
            labelText: 'Working Type',
            prefixIcon: Icon(Icons.timer, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
          items: ['Full-time', 'Part-time', 'Contract', 'Freelance']
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(
                      e,
                      style: GoogleFonts.poppins(),
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _workingMeans = v),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _yearsExperience?.toString() ?? '',
          decoration: InputDecoration(
            labelText: 'Years of Experience',
            prefixIcon: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) => _yearsExperience = int.tryParse(v),
        ),
      ],
      // Student details - shown when Student is selected
      if (_professionType == 'student') ...[
        _buildEditField('College Name', _collegeNameController, Icons.school),
        _buildEditField('Year', _studentYearController, Icons.calendar_today),
        _buildEditField('Department', _departmentController, Icons.class_),
      ],
    ]);
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Photo',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.requestCameraPermission(context);
    } else {
      hasPermission = await PermissionService.requestStoragePermission(context);
    }

    if (!hasPermission || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        setState(() => _newProfilePhoto = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickSpousePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Spouse Photo',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.requestCameraPermission(context);
    } else {
      hasPermission = await PermissionService.requestStoragePermission(context);
    }

    if (!hasPermission || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        setState(() => _newSpousePhoto = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickKidPhoto(int index) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Kid ${index + 1} Photo',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.requestCameraPermission(context);
    } else {
      hasPermission = await PermissionService.requestStoragePermission(context);
    }

    if (!hasPermission || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        setState(() {
          _kids[index]['photo'] = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFamilyPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Family Photo',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: AppTheme.primaryColor),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    bool hasPermission = false;
    if (source == ImageSource.camera) {
      hasPermission = await PermissionService.requestCameraPermission(context);
    } else {
      hasPermission = await PermissionService.requestStoragePermission(context);
    }

    if (!hasPermission || !mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        setState(() => _newFamilyPhoto = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectAddress(bool isCurrent) async {
    LatLng? initialPos;
    final address = isCurrent ? _currentAddress : _nativeAddress;
    if (address != null && address['latitude'] != null && address['longitude'] != null) {
      try {
        initialPos = LatLng(
          (address['latitude'] is double) ? address['latitude'] : double.parse(address['latitude'].toString()),
          (address['longitude'] is double) ? address['longitude'] : double.parse(address['longitude'].toString()),
        );
      } catch (e) {
        // If parsing fails, use null (will use current location or default)
        initialPos = null;
      }
    }
    
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialPosition: initialPos,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final addressData = {
          'address': (result['address'] ?? result['street'] ?? '').toString().trim(),
          'state': (result['state'] ?? '').toString().trim(),
          'pincode': (result['pincode'] ?? '').toString().trim(),
          'latitude': double.tryParse(result['latitude']?.toString() ?? '0') ?? 0.0,
          'longitude': double.tryParse(result['longitude']?.toString() ?? '0') ?? 0.0,
        };

        if (isCurrent) {
          _currentAddress = addressData;
        } else {
          _nativeAddress = addressData;
        }
      });
    }
  }

  void _showUpdateConfirmation() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline,
                size: 50,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Update Profile?',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Are you sure you want to update your profile with these changes?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleUpdate();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4,
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Update',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);

    try {
      // Prepare updated data
      // Set isWorking to true if there are any working details filled
      final hasWorkingDetails = _professionType == 'business'
          ? (_businessTypeController.text.trim().isNotEmpty || _businessNameController.text.trim().isNotEmpty)
          : _professionType == 'job'
              ? (_companyNameController.text.trim().isNotEmpty || _positionController.text.trim().isNotEmpty || _workingMeans != null)
              : _professionType == 'student'
                  ? (_collegeNameController.text.trim().isNotEmpty || _studentYearController.text.trim().isNotEmpty || _departmentController.text.trim().isNotEmpty)
                  : false;
      
      final workingDetails = {
        'isWorking': hasWorkingDetails,
        'isBusiness': _professionType == 'business',
        'professionType': _professionType ?? 'business',
        'workingMeans': _workingMeans ?? '',
        'companyName': _companyNameController.text.trim(),
        'position': _positionController.text.trim(),
        'totalYearsExperience': _yearsExperience ?? 0,
        'businessType': _businessTypeController.text.trim(),
        'businessName': _businessNameController.text.trim(),
        'businessAddresses': _businessAddressControllers.map((controller) => controller.text.trim()).where((addr) => addr.isNotEmpty).toList(),
        // Keep single address for backward compatibility (use first address if available)
        'businessAddress': _businessAddressControllers.isNotEmpty && _businessAddressControllers[0].text.trim().isNotEmpty
            ? _businessAddressControllers[0].text.trim()
            : '',
        // Student fields
        'collegeName': _collegeNameController.text.trim(),
        'studentYear': _studentYearController.text.trim(),
        'department': _departmentController.text.trim(),
      };

      // Prepare kids data (convert File objects to paths for backend)
      final kidsData = _kids.map((kid) {
        final kidData = {
          'name': kid['name'] ?? '',
          'dateOfBirth': kid['dateOfBirth'],
          'schoolName': kid['schoolName'] ?? '',
          'standard': kid['standard'] ?? '',
        };
        // Photo will be handled separately in multipart upload
        return kidData;
      }).toList();

      final updateData = {
        'username': _usernameController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'secondaryMobileNumber': _secondaryMobileController.text.trim().isNotEmpty ? _secondaryMobileController.text.trim() : null,
        'emailId': _emailIdController.text.trim(),
        'bloodGroup': _selectedBloodGroup,
        'fatherName': _fatherNameController.text.trim(),
        'grandfatherName': _grandfatherNameController.text.trim(),
        'greatGrandfatherName': _greatGrandfatherNameController.text.trim().isNotEmpty ? _greatGrandfatherNameController.text.trim() : null,
        'motherName': _motherNameController.text.trim(),
        'motherNative': _motherNativeController.text.trim(),
        'grandmotherName': _grandmotherNameController.text.trim(),
        'grandmotherNative': _grandmotherNativeController.text.trim(),
        'highestQualification': _selectedQualification ?? '',
        'hasEducation': _hasEducation,
        'college': _hasEducation ? _collegeController.text.trim() : null,
        'yearOfCompletion': _hasEducation ? _yearOfCompletionController.text.trim() : null,
        'course': _hasEducation ? _courseController.text.trim() : null,
        'startYear': _hasEducation ? _startYearController.text.trim() : null,
        'endYear': _hasEducation ? _endYearController.text.trim() : null,
        'extraDegrees': _hasEducation && _extraDegrees.isNotEmpty ? _extraDegrees : null,
        'dateOfBirth': _dateOfBirth?.toIso8601String(),
        'maritalStatus': _maritalStatus,
        'spouseName': _maritalStatus == 'Married' ? _spouseNameController.text.trim() : null,
        'spouseNative': _maritalStatus == 'Married' ? _spouseNativeController.text.trim() : null,
        'kids': _maritalStatus == 'Married' ? kidsData : null,
        'currentAddress': _currentAddress,
        'nativeAddress': _nativeAddress,
        'useSameAddress': _useSameAddress,
        'workingDetails': workingDetails,
      };

      // Prepare kid photo paths
      final kidPhotoPaths = _kids
          .where((kid) => kid['photo'] != null && kid['photo'] is File)
          .map((kid) => (kid['photo'] as File).path)
          .toList();

      // Call the update API
      // Call the update API
      bool success;
      if (widget.isAdminEdit && widget.userId != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        success = await userProvider.updateUser(
          widget.userId!,
          updateData,
          _newProfilePhoto?.path,
          spousePhotoPath: _newSpousePhoto?.path,
          familyPhotoPath: _newFamilyPhoto?.path,
          kidPhotoPaths: kidPhotoPaths.isNotEmpty ? kidPhotoPaths : null,
        );
      } else {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        success = await authProvider.updateProfile(
          updateData,
          _newProfilePhoto?.path,
          spousePhotoPath: _newSpousePhoto?.path,
          familyPhotoPath: _newFamilyPhoto?.path,
          kidPhotoPaths: kidPhotoPaths.isNotEmpty ? kidPhotoPaths : null,
        );
      }

      if (mounted) {
        setState(() => _isUpdating = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Profile updated successfully!',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );

          // Refresh user data from backend to show updated information
          // Refresh user data from backend to show updated information
          if (widget.isAdminEdit && widget.userId != null) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            final updatedUser = await userProvider.getUserById(widget.userId!);
            if (mounted) {
              _updateControllersWithUserData(updatedUser);
              setState(() {
                // Keep in edit mode for admin or allow them to exit?
                // For better UX, maybe just reset new photo fields
                _newProfilePhoto = null;
                _newSpousePhoto = null;
                _newFamilyPhoto = null;
                _currentProfilePhotoUrl = updatedUser['profilePhoto'];
                _currentSpousePhotoUrl = updatedUser['spousePhoto'];
                _currentFamilyPhotoUrl = updatedUser['familyPhoto'];
              });
            }
          } else {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            await authProvider.getCurrentUser();
            
            // Update controllers with fresh data immediately
            _updateControllers();
            
            setState(() {
              _isEditMode = false;
              _newProfilePhoto = null;
              _newSpousePhoto = null;
              _newFamilyPhoto = null;
              // Clear the new photo since we've updated from backend
              _currentProfilePhotoUrl = authProvider.user?['profilePhoto'];
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Failed to update profile',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                size: 50,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 0,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4,
                        shadowColor: Colors.red.withValues(alpha: 0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
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

  Widget _buildStatusBadge(String? status) {
    final statusLower = status?.toLowerCase() ?? '';
    final isApproved = statusLower == 'approved';
    
    if (isApproved) {
      // Show verified icon with green color and border for approved status
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.green,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified,
              size: 16,
              color: Colors.green,
            ),
            const SizedBox(width: 6),
            Text(
              'Verified',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else {
      // Show regular status badge for other statuses
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor(status),
            width: 1.5,
          ),
        ),
        child: Text(
          status ?? 'Unknown',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _getStatusColor(status),
          ),
        ),
      );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inactive':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _mobileController.dispose();
    _secondaryMobileController.dispose();
    _fatherNameController.dispose();
    _grandfatherNameController.dispose();
    _greatGrandfatherNameController.dispose();
    _motherNameController.dispose();
    _motherNativeController.dispose();
    _grandmotherNameController.dispose();
    _grandmotherNativeController.dispose();
    _emailIdController.dispose();
    _spouseNameController.dispose();
    _spouseNativeController.dispose();
    _collegeController.dispose();
    _yearOfCompletionController.dispose();
    _courseController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    _companyNameController.dispose();
    _positionController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _businessAddressControllers.forEach((controller) => controller.dispose());
    _collegeNameController.dispose();
    _studentYearController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  void _showDeleteAccountConfirmation() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),

            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 50,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Delete Account',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Are you sure you want to delete your account?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _deleteAccount();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // Show snackbar message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account will be deleted soon',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Call the API in background (don't await or show response)
    ApiService.deleteAccount().catchError((error) {
      // Silently handle errors - no UI feedback needed
      debugPrint('Delete account API error: $error');
    });
  }

  Widget _buildDeleteAccountSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Account',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Permanently delete your account and all associated data. This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showDeleteAccountConfirmation,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: Text(
                'Delete Account',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.red, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}