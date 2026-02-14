import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/api_service.dart';
import '../utils/theme.dart';
import '../config/app_config.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _currentStep = 0; // 0: Email, 1: OTP, 2: New Password
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _storedOTP;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestOTP() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter email address';
      });
      return;
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() {
        _errorMessage = 'Please enter a valid email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.requestPasswordResetOTP(_emailController.text.trim().toLowerCase());
      
      if (mounted) {
        if (response['error'] == null && response['message'] != null) {
          // OTP sent successfully
          setState(() {
            _currentStep = 1;
            _isLoading = false;
            _errorMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'OTP sent to your email',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = response['message'] ?? response['error'] ?? 'Failed to send OTP';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error. Please check your connection.';
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.verifyPasswordResetOTP(
        _emailController.text.trim().toLowerCase(),
        _otpController.text.trim(),
      );
      
      if (mounted) {
        if (response['verified'] == true) {
          // OTP verified successfully
          setState(() {
            _storedOTP = _otpController.text.trim();
            _currentStep = 2;
            _isLoading = false;
            _errorMessage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'OTP verified successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = response['message'] ?? 'Invalid OTP';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error. Please check your connection.';
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter new password and confirm password';
      });
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Password must be at least 6 characters long';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.resetPassword(
        _emailController.text.trim().toLowerCase(),
        _storedOTP ?? _otpController.text.trim(),
        _newPasswordController.text,
      );
      
      if (mounted) {
        if (response['error'] == null && response['message'] != null) {
          // Password reset successful
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Password reset successfully! Please login with your new password.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          
          // Navigate to login page
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = response['message'] ?? response['error'] ?? 'Failed to reset password';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Network error. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/myconnect.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Forgot Password',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AppTheme.glassyDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Step indicator
                        Row(
                          children: [
                            _buildStepIndicator(0, 'Email'),
                            Expanded(child: Container(height: 2, color: _currentStep > 0 ? AppTheme.primaryColor : Colors.grey)),
                            _buildStepIndicator(1, 'OTP'),
                            Expanded(child: Container(height: 2, color: _currentStep > 1 ? AppTheme.primaryColor : Colors.grey)),
                            _buildStepIndicator(2, 'Password'),
                          ],
                        ),
                        const SizedBox(height: 30),
                        
                        // Step 0: Enter Email
                        if (_currentStep == 0) ...[
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: Icon(Icons.email),
                              hintText: 'Enter your registered email address',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _requestOTP,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                  ),
                                  child: Text(
                                    'Send OTP',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ],
                        
                        // Step 1: Enter OTP
                        if (_currentStep == 1) ...[
                          Text(
                            'OTP sent to email: ${_emailController.text}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _otpController,
                            decoration: const InputDecoration(
                              labelText: 'Enter OTP',
                              prefixIcon: Icon(Icons.lock_outline),
                              hintText: 'Enter 6-digit OTP',
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: _isLoading ? null : () {
                                    setState(() {
                                      _currentStep = 0;
                                      _otpController.clear();
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Text(
                                    'Back',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton(
                                        onPressed: _verifyOTP,
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 50),
                                        ),
                                        child: Text(
                                          'Verify OTP',
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
                          TextButton(
                            onPressed: _isLoading ? null : () {
                              setState(() {
                                _otpController.clear();
                                _errorMessage = null;
                              });
                              _requestOTP();
                            },
                            child: Text(
                              'Resend OTP',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                        
                        // Step 2: Enter New Password
                        if (_currentStep == 2) ...[
                          TextFormField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(
                              labelText: 'New Password',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureNewPassword = !_obscureNewPassword;
                                  });
                                },
                              ),
                              hintText: 'Enter new password (min 6 characters)',
                            ),
                            obscureText: _obscureNewPassword,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              hintText: 'Confirm new password',
                            ),
                            obscureText: _obscureConfirmPassword,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 20),
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: _isLoading ? null : () {
                                    setState(() {
                                      _currentStep = 1;
                                      _newPasswordController.clear();
                                      _confirmPasswordController.clear();
                                      _errorMessage = null;
                                    });
                                  },
                                  child: Text(
                                    'Back',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : ElevatedButton(
                                        onPressed: _resetPassword,
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(double.infinity, 50),
                                        ),
                                        child: Text(
                                          'Reset Password',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Text(
                      'Back to Login',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;
    
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? AppTheme.primaryColor
                : Colors.grey,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: isActive || isCompleted
                ? AppTheme.primaryColor
                : Colors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

