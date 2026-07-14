import 'package:flutter/material.dart';
import '../../../shared/widgets/animations/transition_manager.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/services/interfaces/location_service_interface.dart';
import '../../../core/themes/app_colors.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../../../shared/widgets/app_3d_icon.dart';

class AuthIntroScreen extends StatefulWidget {
  const AuthIntroScreen({super.key});

  @override
  State<AuthIntroScreen> createState() => _AuthIntroScreenState();
}

class _AuthIntroScreenState extends State<AuthIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();

    // Request location permission after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestLocationPermission();
    });
  }

  Future<void> _requestLocationPermission() async {
    try {
      final locationService = LocationService();
      // Check current status first — avoid prompting if already granted/denied
      final current = await locationService.getLocationPermissionStatus();
      if (current == LocationPermissionStatus.granted) {
        if (mounted) debugPrint('Location permission already granted');
        return;
      }
      // Only request if not permanently denied (would open settings instead)
      if (current == LocationPermissionStatus.deniedForever) {
        if (mounted) debugPrint('Location permission permanently denied');
        return;
      }
      final status = await locationService.requestLocationPermission();
      if (mounted) {
        debugPrint('Location permission status: $status');
      }
    } catch (e) {
      debugPrint('Failed to request location permission: $e');
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
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
              AppColors.creamBackground,
              Color(0xFFFFE4CC),
              Colors.white,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_slideController, _fadeController]),
            builder: (context, child) {
              return Column(
                children: [
                  // Header with logo
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'SWASTIK',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),

                  // Main illustration area
                  Expanded(
                    flex: 3,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // App logo
                            ClipOval(
                              child: Image.asset(
                                'assets/images/logos/app_launcher_icon.png',
                                width: 140,
                                height: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 140,
                                    height: 140,
                                    color: AppColors.primaryOrange,
                                    child: const Icon(
                                      Icons.temple_hindu,
                                      color: Colors.white,
                                      size: 80,
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Welcome text
                            const Text(
                              'Welcome to Your\nSpiritual Journey',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryText,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              'Discover sacred temples, connect with divine energy, and explore the rich spiritual heritage around you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.secondaryText,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom action area
                  Expanded(
                    flex: 2,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 20,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Features row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildFeatureItem(
                                    Icons.location_on,
                                    IconAssets.featureTemples,
                                    'Find Temples',
                                    AppColors.primaryOrange,
                                  ),
                                  _buildFeatureItem(
                                    Icons.event,
                                    IconAssets.featureEvents,
                                    'Events',
                                    const Color(0xFF00B3AC),
                                  ),
                                  _buildFeatureItem(
                                    Icons.people,
                                    IconAssets.featureCommunity,
                                    'Community',
                                    const Color(0xFF8B5CF6),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Sign up button
                              Hero(
                                tag: 'auth_cta',
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pushWithTransition(
                                        const SignUpScreen(),
                                        transitionType: TransitionType.fade,
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryOrange,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Sign in link
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.of(context).pushWithTransition(
                                    const LoginScreen(),
                                    transitionType: TransitionType.fade,
                                    duration: const Duration(milliseconds: 250),
                                  );
                                },
                                child: const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Already have an account? ',
                                        style: TextStyle(
                                          color: AppColors.secondaryText,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Sign In',
                                        style: TextStyle(
                                          color: AppColors.primaryOrange,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String assetPath,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: App3DIcon(
              assetPath: assetPath,
              fallbackIcon: icon,
              fallbackColor: color,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}
