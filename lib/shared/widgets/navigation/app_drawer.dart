import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/themes/app_colors.dart';
import '../../../shared/services/contact_support_service.dart';

/// Side drawer menu for user home screen with profile and app features
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Drawer(
      child: Container(
        color: AppColors.lightGray,
        child: SafeArea(
          child: Column(
            children: [
              _buildProfileHeader(context, user),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.person,
                        title: 'My Profile',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/profile');
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.book_online,
                        title: 'My Bookings',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/bookings');
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.volunteer_activism,
                        title: 'Donations',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/donations');
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.favorite,
                        title: 'Favorites',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/favorites');
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.notifications,
                        title: 'Notifications',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/notifications');
                        },
                      ),
                      
                      const Divider(height: 32),
                      
                      _buildSectionHeader('App Settings'),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.language,
                        title: 'Language',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/preferences');
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.settings,
                        title: 'Settings',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/preferences');
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {
                          Navigator.pop(context);
                          ContactSupportService.showSupportOptions(context);
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {
                          Navigator.pop(context);
                          _showAboutDialog(context);
                        },
                      ),
                      
                      _buildMenuItem(
                        context,
                        icon: Icons.share,
                        title: 'Share App',
                        onTap: () {
                          Navigator.pop(context);
                          // Implement share functionality
                        },
                      ),
                      
                      if (user != null)
                        _buildMenuItem(
                          context,
                          icon: Icons.logout,
                          title: 'Logout',
                          onTap: () async {
                            Navigator.pop(context);
                            await FirebaseAuth.instance.signOut();
                          },
                        ),
                      
                      const SizedBox(height: 24),
                      
                      if (_appVersion.isNotEmpty)
                        Center(
                          child: Text(
                            'Version $_appVersion',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User? user) {
    final isLoggedIn = user != null;
    final displayName = user?.displayName ?? 'Guest';
    final email = user?.email ?? '';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryOrange, AppColors.lightOrange],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                child: ClipOval(
                  child: user?.photoURL != null
                      ? Image.network(
                          user!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 32,
                              color: Colors.white,
                            );
                          },
                        )
                      : const Icon(
                          Icons.person,
                          size: 32,
                          color: Colors.white,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (!isLoggedIn) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryText,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryOrange,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.disabledText,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 4,
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Temple Darshan App',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Version: $_appVersion',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            const Text(
              'Discover temples, watch live darshan, and connect with your spiritual journey.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
