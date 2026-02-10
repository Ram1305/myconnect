import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'blogs_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';
import '../utils/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/role_switch_widget.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  List<Widget> _buildScreens(bool hideChildAppBar) => [
        HomeScreen(showAppBar: !hideChildAppBar),
        BlogsScreen(showAppBar: !hideChildAppBar),
        const ChatListScreen(),
        ProfileScreen(showAppBar: !hideChildAppBar),
      ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final showRoleSwitch = authProvider.isAdmin();
        return Scaffold(
          appBar: showRoleSwitch
              ? AppBar(
                  elevation: 0,
                  backgroundColor: AppTheme.backgroundColor,
                  foregroundColor: AppTheme.primaryColor,
                  title: Text(
                    'My Connect',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  centerTitle: true,
                  actions: const [
                    RoleSwitchWidget(isAdminView: false),
                  ],
                )
              : null,
          body: IndexedStack(
            index: _currentIndex,
            children: _buildScreens(showRoleSwitch),
          ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'Blogs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
        );
      },
    );
  }
}

