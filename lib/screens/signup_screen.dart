import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../utils/permission_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';
import 'map_picker_screen.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  final bool adminCreated;
  final String? initialReferralId;
  const SignupScreen({super.key, this.adminCreated = false, this.initialReferralId});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Controllers
  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralIdController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _grandfatherNameController = TextEditingController();
  String? _selectedQualification;
  final _companyNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();

  File? _profilePhoto;
  double? _latitude;
  double? _longitude;
  Map<String, dynamic>? _currentAddress;
  Map<String, dynamic>? _nativeAddress;
  bool _useSameAddress = false;
  bool _isWorking = false;
  bool _isBusiness = false;
  String? _professionType = 'business'; // Default to 'business' // 'business', 'job', 'student'
  String? _workingMeans;
  int? _yearsExperience;
  // Business fields
  final _organizationNameController = TextEditingController();
  final _designationController = TextEditingController();
  final _organizationNumberController = TextEditingController();
  List<TextEditingController> _businessAddressControllers = [TextEditingController()];
  // Student fields
  final _collegeNameController = TextEditingController();
  final _studentYearController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _isAdmin = false;

  // Check if all required fields on first page are filled
  bool _isFirstPageValid() {
    // Profile photo, qualification, father name, and grandfather name are optional
    return _usernameController.text.trim().isNotEmpty &&
        _mobileController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialReferralId != null && widget.initialReferralId!.isNotEmpty) {
      _referralIdController.text = widget.initialReferralId!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text('Sign Up'),
      ),
      body: Container(
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
        child: Stack(
          children: [
            Column(
              children: [
                _buildEnergyProgressBar(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    children: [
                      _buildPersonalInfoPage(),
                      _buildAddressPage(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        ElevatedButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.grey[800],
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                            minimumSize: const Size(80, 5),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10),
                              ),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            'Previous',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 80),
                      ElevatedButton(
                        onPressed: _currentPage < 1
                            ? (_currentPage == 0 && !_isFirstPageValid())
                                ? null // Disable if first page and not valid
                                : () {
                                    if (_currentPage == 0) {
                                      // Validate form before proceeding
                                      if (_formKey.currentState?.validate() ?? false) {
                                        if (_isFirstPageValid()) {
                                          _pageController.nextPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Please fill all required fields: Username, Mobile Number, and Password',
                                                style: GoogleFonts.poppins(),
                                              ),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    } else {
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  }
                            : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_currentPage == 0 && !_isFirstPageValid())
                              ? Colors.grey
                              : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                          minimumSize: const Size(80, 5),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          elevation: 4,
                          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                        ),
                        child: Text(
                          _currentPage < 1 ? 'Next' : 'Register',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Loading overlay
            if (_isRegistering)
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
                        'Registering...',
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
      ),
    );
  }

  Widget _buildEnergyProgressBar() {
    final totalPages = 2;
    final progress = (_currentPage + 1) / totalPages;
    final steps = ['Personal', 'Address'];
    final screenWidth = MediaQuery.of(context).size.width;
    final progressBarWidth = screenWidth - 40; // Account for padding (20 on each side)
    const iconSize = 36.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // Progress bar with energy icon
          SizedBox(
            height: iconSize,
            child: Stack(
              children: [
                // Background track
                Positioned(
                  top: (iconSize - 10) / 2,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // Progress fill with gradient
                Positioned(
                  top: (iconSize - 10) / 2,
                  left: 0,
                  child: SizedBox(
                    width: progressBarWidth * progress,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.secondaryColor,
                            AppTheme.lightGold,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Animated energy icon at progress position
                Positioned(
                  left: ((progressBarWidth * progress) - (iconSize / 2)).clamp(0.0, progressBarWidth - iconSize),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Step indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(2, (index) {
              final isActive = index <= _currentPage;
              final isCurrent = index == _currentPage;
              
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryColor
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                        border: isCurrent
                            ? Border.all(
                                color: AppTheme.secondaryColor,
                                width: 2.5,
                              )
                            : null,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isActive ? Icons.check_circle : Icons.circle_outlined,
                        color: isActive ? Colors.white : Colors.grey[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[index],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isActive
                            ? AppTheme.primaryColor
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickProfilePhoto,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: AppTheme.circularBorderDecoration().copyWith(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    child: _profilePhoto != null
                        ? ClipOval(
                      child: Image.file(_profilePhoto!, fit: BoxFit.cover),
                    )
                        : Icon(
                      Icons.person,
                      size: 50,
                      color: AppTheme.primaryColor,
                    ),
                  ),

                  // Show text only when image is NOT selected
                  if (_profilePhoto == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Add Profile Photo (Optional)",
                      style: GoogleFonts.poppins(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mobileController,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _referralIdController,
              decoration: InputDecoration(
                labelText: 'Referral ID (Optional)',
                hintText: 'e.g. MYCNCT1234567890',
                hintStyle: TextStyle(color: widget.initialReferralId != null ? Theme.of(context).hintColor : null),
              ),
              readOnly: false,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fatherNameController,
              decoration: const InputDecoration(labelText: 'Father Name (Optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _grandfatherNameController,
              decoration: const InputDecoration(labelText: 'Grandfather Name (Optional)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Address',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _selectAddress(true),
                // icon: Icon(Icons.map, size: 18, color: Colors.white),
                label: Text(
                  'Select from Map',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  minimumSize: const Size(0, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 3,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_currentAddress != null) ...[
            const SizedBox(height: 16),
            Text(
              'Address: ${_currentAddress!['address']}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            Text(
              'State: ${_currentAddress!['state']}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            Text(
              'Pincode: ${_currentAddress!['pincode']}',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ],
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Use Same Address for Native',
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
          ),
          if (!_useSameAddress) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Native Address',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectAddress(false),
                  // icon: Icon(Icons.map, size: 18, color: Colors.white),
                  label: Text(
                    'Select from Map',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 3,
                    shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_nativeAddress != null) ...[
              const SizedBox(height: 16),
              Text(
                'Address: ${_nativeAddress!['address']}',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              Text(
                'State: ${_nativeAddress!['state']}',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              Text(
                'Pincode: ${_nativeAddress!['pincode']}',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ],
        ],
      ),
    );
  }


  Future<void> _pickProfilePhoto() async {
    // Show bottom modal sheet to choose between camera and gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
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

    // On iOS, let image_picker handle permissions directly - it triggers system dialogs properly
    // On Android, we pre-check permissions for better UX
    if (Platform.isAndroid) {
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        hasPermission = await PermissionService.requestCameraPermission(context);
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Camera permission is required to take photos',
                  style: GoogleFonts.poppins(),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      } else {
        // Request storage permission for gallery - request it explicitly
        hasPermission = await PermissionService.requestStoragePermission(context);
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Storage permission is required to select photos. Please grant permission and try again.',
                  style: GoogleFonts.poppins(),
                ),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () => _pickProfilePhoto(),
                ),
              ),
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null && mounted) {
        setState(() => _profilePhoto = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        // Handle permission denied errors gracefully
        String errorMessage = 'Error picking image';
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission') || 
            errorString.contains('denied') ||
            errorString.contains('access')) {
          if (source == ImageSource.camera) {
            errorMessage = 'Camera permission was denied. Please allow camera access in Settings.';
          } else {
            errorMessage = 'Photo library access was denied. Please allow access in Settings.';
          }
        } else {
          errorMessage = 'Error picking image: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectAddress(bool isCurrent) async {
    // Open map picker screen
    LatLng? initialPos;
    if (isCurrent && _latitude != null && _longitude != null) {
      initialPos = LatLng(_latitude!, _longitude!);
    } else if (!isCurrent && _nativeAddress != null && 
               _nativeAddress!['latitude'] != null && 
               _nativeAddress!['longitude'] != null) {
      initialPos = LatLng(
        _nativeAddress!['latitude'] as double,
        _nativeAddress!['longitude'] as double,
      );
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
        if (isCurrent) {
          _currentAddress = {
            'address': (result['address'] ?? result['street'] ?? '').toString().trim(),
            'state': (result['state'] ?? '').toString().trim(),
            'pincode': (result['pincode'] ?? '').toString().trim(),
            'latitude': double.tryParse(result['latitude']?.toString() ?? '0') ?? 0.0,
            'longitude': double.tryParse(result['longitude']?.toString() ?? '0') ?? 0.0,
          };
          // Update location if provided
          if (result['latitude'] != null && result['longitude'] != null) {
            _latitude = double.tryParse(result['latitude']!.toString());
            _longitude = double.tryParse(result['longitude']!.toString());
          }
        } else {
          _nativeAddress = {
            'address': (result['address'] ?? result['street'] ?? '').toString().trim(),
            'state': (result['state'] ?? '').toString().trim(),
            'pincode': (result['pincode'] ?? '').toString().trim(),
            'latitude': double.tryParse(result['latitude']?.toString() ?? '0') ?? 0.0,
            'longitude': double.tryParse(result['longitude']?.toString() ?? '0') ?? 0.0,
          };
        }
      });
    }
  }

  Future<void> _handleSignup() async {
    debugPrint('🔵 [SIGNUP] Starting registration process...');
    debugPrint('🔵 [SIGNUP] Current page: $_currentPage');
    debugPrint('🔵 [SIGNUP] Form key currentState: ${_formKey.currentState}');
    debugPrint('🔵 [SIGNUP] Latitude: $_latitude');
    debugPrint('🔵 [SIGNUP] Longitude: $_longitude');
    debugPrint('🔵 [SIGNUP] Current Address: $_currentAddress');
    debugPrint('🔵 [SIGNUP] Native Address: $_nativeAddress');
    debugPrint('🔵 [SIGNUP] Use Same Address: $_useSameAddress');
    
    // Validate form if it exists (only on first page when form is in widget tree)
    if (_currentPage == 0 && _formKey.currentState != null) {
      final formValid = _formKey.currentState!.validate();
      if (!formValid) {
        debugPrint('❌ [SIGNUP] Form validation failed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Please fill all required fields',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }
    
    // Validate all required fields (works on all pages)
    if (_usernameController.text.trim().isEmpty) {
      debugPrint('❌ [SIGNUP] Username is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter your username', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (_mobileController.text.trim().isEmpty) {
      debugPrint('❌ [SIGNUP] Mobile number is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter your mobile number', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      debugPrint('❌ [SIGNUP] Password is empty');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter your password', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Father name and grandfather name are now optional - no validation needed
    
    if (_latitude == null || _longitude == null) {
      debugPrint('❌ [SIGNUP] Latitude or Longitude is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select your current address from the map',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    
    debugPrint('✅ [SIGNUP] Validation passed, proceeding with registration...');
    
    // Set loading state
    setState(() {
      _isRegistering = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Prepare current address with latitude and longitude - ensure all fields are filled
      final currentAddr = <String, dynamic>{
        'address': _currentAddress?['address']?.toString().trim() ?? '',
        'state': _currentAddress?['state']?.toString().trim() ?? '',
        'pincode': _currentAddress?['pincode']?.toString().trim() ?? '',
        'latitude': _currentAddress?['latitude'] ?? _latitude ?? 0.0,
        'longitude': _currentAddress?['longitude'] ?? _longitude ?? 0.0,
      };
      
      // If address is empty but we have coordinates, set a default
      if ((currentAddr['address'] == null || currentAddr['address'] == '') && _latitude != null && _longitude != null) {
        currentAddr['address'] = 'Address not specified';
        currentAddr['latitude'] = _latitude!;
        currentAddr['longitude'] = _longitude!;
      }
      
      debugPrint('🔵 [SIGNUP] Prepared currentAddr: $currentAddr');
      
      // Prepare native address with latitude and longitude - ensure all fields are filled
      final nativeAddr = <String, dynamic>{};
      
      if (_useSameAddress && currentAddr.isNotEmpty) {
        // If using same address, copy current address data
        nativeAddr.addAll(currentAddr);
        debugPrint('🔵 [SIGNUP] Using same address for native');
      } else {
        nativeAddr['address'] = _nativeAddress?['address']?.toString().trim() ?? '';
        nativeAddr['state'] = _nativeAddress?['state']?.toString().trim() ?? '';
        nativeAddr['pincode'] = _nativeAddress?['pincode']?.toString().trim() ?? '';
        nativeAddr['latitude'] = _nativeAddress?['latitude'] ?? _latitude ?? 0.0;
        nativeAddr['longitude'] = _nativeAddress?['longitude'] ?? _longitude ?? 0.0;
        
        // If address is empty but we have coordinates, set a default
        if ((nativeAddr['address'] == null || nativeAddr['address'] == '') && _latitude != null && _longitude != null) {
          nativeAddr['address'] = 'Address not specified';
          nativeAddr['latitude'] = _latitude!;
          nativeAddr['longitude'] = _longitude!;
        }
      }
      
      debugPrint('🔵 [SIGNUP] Prepared nativeAddr: $nativeAddr');
      
      // Prepare working details - set empty defaults (work details no longer collected during signup)
      final workingDetails = <String, dynamic>{
        'professionType': 'business',
        'workingMeans': '',
        'companyName': '',
        'position': '',
        'totalYearsExperience': 0,
        'businessType': '',
        'businessName': '',
        // Business fields
        'organizationName': '',
        'designation': '',
        'organizationNumber': '',
        'organizationAddress': '',
        'businessAddresses': [],
        // Student fields
        'collegeName': '',
        'studentYear': '',
        'department': '',
        'isWorking': false,
        'isBusiness': false,
      };
      
      final data = {
        'username': _usernameController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'password': _passwordController.text,
        'latitude': _latitude.toString(),
        'longitude': _longitude.toString(),
        'currentAddress': currentAddr,
        'nativeAddress': nativeAddr,
        'useSameAddress': _useSameAddress,
        'fatherName': _fatherNameController.text.trim(),
        'grandfatherName': _grandfatherNameController.text.trim(),
        'highestQualification': '',
        'workingDetails': workingDetails,
        'isAdmin': _isAdmin,
        'createdByAdmin': widget.adminCreated, // Pass admin created flag
      };
      final referralIdTrimmed = _referralIdController.text.trim();
      if (referralIdTrimmed.isNotEmpty) {
        data['referralId'] = referralIdTrimmed;
      }
      
      debugPrint('🔵 [SIGNUP] Registration data:');
      debugPrint('   Username: ${data['username']}');
      debugPrint('   Mobile: ${data['mobileNumber']}');
      final password = data['password'] as String?;
      debugPrint('   Password: ${password != null && password.isNotEmpty ? '***' : 'EMPTY'}');
      debugPrint('   Latitude: ${data['latitude']}');
      debugPrint('   Longitude: ${data['longitude']}');
      debugPrint('   Profile Photo: ${_profilePhoto?.path ?? 'None'}');
      debugPrint('   Working Details: $workingDetails');

      debugPrint('🟡 [SIGNUP] Calling authProvider.signup...');
      final success = await authProvider.signup(
        data,
        _profilePhoto?.path,
      );
      debugPrint('🟡 [SIGNUP] Signup result: $success');

      // Reset loading state
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });

        if (success) {
          debugPrint('✅ [SIGNUP] Registration successful!');
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Register successfully',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Navigate based on who created the user
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (mounted) {
            if (widget.adminCreated) {
              // If created by admin, navigate back to admin panel
              Navigator.of(context).pop(); // Go back to admin panel
            } else {
              // If regular signup, navigate to login page
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false, // Remove all previous routes
            );
            }
          }
        } else {
          debugPrint('❌ [SIGNUP] Registration failed');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Registration failed. Please try again.',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        debugPrint('❌ [SIGNUP] Validation failed - missing required data');
      }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _referralIdController.dispose();
    _fatherNameController.dispose();
    _grandfatherNameController.dispose();
    _companyNameController.dispose();
    _positionController.dispose();
    _businessTypeController.dispose();
    _businessNameController.dispose();
    _businessAddressControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }
}

// Simple address picker dialog (in real app, use map)
class AddressPickerDialog extends StatefulWidget {
  const AddressPickerDialog({super.key});

  @override
  State<AddressPickerDialog> createState() => _AddressPickerDialogState();
}

class _AddressPickerDialogState extends State<AddressPickerDialog> {
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter Address',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: 16),
            TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'State')),
            const SizedBox(height: 16),
            TextField(controller: _pincodeController, decoration: const InputDecoration(labelText: 'Pincode')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'address': _addressController.text,
                  'state': _stateController.text,
                  'pincode': _pincodeController.text,
                  'latitude': 0.0,
                  'longitude': 0.0,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                minimumSize: const Size(120, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 3,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
              child: Text(
                'Save',
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

  @override
  void dispose() {
    _addressController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }
}

