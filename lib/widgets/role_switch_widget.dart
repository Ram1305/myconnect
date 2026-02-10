import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../screens/dashboard.dart';
import '../screens/splash_screen.dart';

/// Compact User / Admin role switch for dashboard headers.
/// Shown only when the current user has admin rights (same mobile = user + admin).
/// [isAdminView] true when currently on AdminPanel, false when on user Dashboard.
class RoleSwitchWidget extends StatelessWidget {
  const RoleSwitchWidget({
    super.key,
    required this.isAdminView,
  });

  final bool isAdminView;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAdmin() && !authProvider.isSuperAdmin()) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        height: 36,
        width: 130,
        child: AnimatedToggleSwitch<bool>.dual(
          current: isAdminView,
          first: false,
          second: true,
          spacing: 8,
          style: ToggleStyle(
            backgroundColor: AppTheme.lightGold,
            borderColor: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 2,
              ),
            ],
          ),
          styleBuilder: (isSelected) => ToggleStyle(
            indicatorColor:
                isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.6),
            borderColor: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          onChanged: (value) {
            if (!context.mounted) return;
            if (value) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AdminPanel()),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const Dashboard()),
              );
            }
          },
          iconBuilder: (value) => value
              ? const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 18)
              : const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          textBuilder: (value) => Center(
            child: Text(
              value ? 'Admin' : 'User',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
