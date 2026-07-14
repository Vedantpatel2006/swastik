import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/firebase_options.dart';
import 'core/config/supabase_config.dart';
import 'core/services/accessibility_service.dart';
import 'core/themes/accessibility_theme.dart';
import 'providers/auth_provider.dart';
import 'shared/services/service_container.dart';
import 'features/auth/screens/welcome_screen_1.dart';
import 'features/auth/screens/auth_intro.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/admin/screens/admin_home_screen.dart';
import 'features/user/screens/notification_preferences_screen.dart';
import 'features/user/screens/notifications_screen.dart';
import 'features/user/screens/user_preferences_screen.dart';
import 'features/user/screens/user_profile_screen.dart';
import 'features/user/screens/donation_screen.dart';
import 'features/user/screens/recent_donations_screen.dart';
import 'features/user/screens/booking_screen.dart';
import 'features/temple/screens/favorites_screen.dart';
import 'features/temple/screens/temple_search_screen.dart';
import 'features/temple/screens/nearby_screen.dart';
import 'features/temple/screens/temple_detail_screen.dart';
import 'features/temple/screens/best_partners_screen.dart';
import 'features/temple/screens/temple_events_screen.dart';
import 'features/temple/screens/all_events_screen.dart';
import 'features/user/screens/my_bookings_screen.dart';
import 'shared/screens/community_screen.dart';
import 'shared/screens/user_home_screen.dart';
import 'shared/models/temple.dart';
import 'shared/widgets/error/fallback_ui.dart';
import 'features/temple/services/hybrid_live_detector.dart';
import 'features/temple/services/stripe_payment_service.dart';
import 'shared/services/youtube_api_manager.dart';
import 'shared/services/supabase_notification_service.dart';
import 'shared/services/supabase_device_token_service.dart';
import 'shared/services/fcm_service.dart';
import 'shared/services/booking_reminder_service.dart';
import 'shared/services/storage/hybrid_storage_service.dart';

/// Centralized system UI configuration - survives hot reload
void configureSystemUI() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Apply system UI configuration
  configureSystemUI();

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  // Handle platform errors
  PlatformDispatcher.instance.onError = (error, stack) {
    final errorStr = error.toString();
    // Suppress known benign platform errors:
    // - "Cannot modify unmodifiable map": occurs in firebase_messaging background
    //   isolate when the platform channel returns an unmodifiable headers map.
    //   This is a known issue in firebase_messaging <15.x and does not affect
    //   app functionality.
    if (errorStr.contains('Cannot modify unmodifiable map')) {
      return true; // suppress silently
    }
    if (kDebugMode) {
      debugPrint('Platform Error: $error');
    }
    return true;
  };

  try {
    // Initialize Firebase - handle case where it might already be initialized by plugins
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        if (kDebugMode) {
          debugPrint('✅ Firebase initialized successfully');
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '✅ Firebase already initialized (${Firebase.apps.length} apps)',
          );
        }
      }
    } catch (e) {
      // Handle duplicate app error gracefully
      if (e.toString().contains('duplicate-app')) {
        if (kDebugMode) {
          debugPrint('✅ Firebase already initialized by plugins');
        }
      } else {
        throw e; // Re-throw other errors
      }
    }

    // Initialize Supabase (for image storage)
    unawaited(
      Future(() async {
        try {
          if (SupabaseConfig.isConfigured()) {
            await Supabase.initialize(
              url: SupabaseConfig.supabaseUrl,
              anonKey: SupabaseConfig.supabaseAnonKey,
            );

            // Initialize hybrid storage service
            await HybridStorageService().initialize();

            if (kDebugMode) {
              debugPrint('✅ Supabase initialized for image storage');
            }
          } else {
            if (kDebugMode) {
              debugPrint(
                '⚠️  Supabase not configured - using Firebase Storage',
              );
              debugPrint(
                '   Add your Supabase API key to lib/core/config/supabase_config.dart',
              );
            }
          }
        } catch (supabaseError) {
          if (kDebugMode) {
            debugPrint('Supabase initialization failed: $supabaseError');
            debugPrint('Falling back to Firebase Storage');
          }
        }
      }),
    );

    // Initialize Supabase Notification Services (non-blocking)
    // Replaced Firebase Messaging with Supabase for push notifications
    unawaited(
      Future(() async {
        try {
          // Initialize notification services only if a user is already signed in.
          // For fresh installs / logged-out state, initializeNotificationServicesForUser()
          // is called from AuthProvider after a successful sign-in.
          final userId = FirebaseAuth.instance.currentUser?.uid;
          if (userId != null) {
            await initializeNotificationServicesForUser(userId);
          }

          // Initialize YouTube API (non-blocking)
          unawaited(_initializeYouTubeApi());

          if (kDebugMode) {
            debugPrint('✅ Notification services initialized successfully');
          }
        } catch (notificationError) {
          if (kDebugMode) {
            debugPrint(
              'Notification service initialization error: $notificationError',
            );
            debugPrint('App will continue without push notifications');
          }
        }
      }),
    );

    // Initialize Firebase App Check (non-blocking)
    unawaited(
      Future(() async {
        try {
          if (!kDebugMode) {
            // Production: Use Play Integrity for security
            await FirebaseAppCheck.instance.activate(
              androidProvider: AndroidProvider.playIntegrity,
              appleProvider: AppleProvider.deviceCheck,
            );
            await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
            debugPrint('App Check enabled for production');
          } else {
            // Debug mode: Skip App Check for easier testing on any device
            debugPrint(
              'App Check disabled in debug mode - all users can access',
            );
          }
        } catch (appCheckError) {
          // Handle App Check errors gracefully (e.g., after clearing data)
          if (kDebugMode) {
            debugPrint('App Check initialization failed: $appCheckError');
            debugPrint('Continuing without App Check - app will still work');
          }
          // App continues to work even if App Check fails
          // This handles cases like:
          // - Cleared app data
          // - First install
          // - Network issues during token fetch
        }
      }),
    );

    // Initialize ServiceContainer for centralized service management
    // Run non-blocking so it doesn't delay the first frame
    unawaited(
      services
          .initializeAll()
          .then((_) {
            if (kDebugMode) {
              debugPrint('✅ ServiceContainer initialized successfully');
            }
          })
          .catchError((e) {
            if (kDebugMode) {
              debugPrint('⚠️  ServiceContainer initialization warning: $e');
            }
          }),
    );

    runApp(const SwastikApp());
  } catch (e) {
    if (kDebugMode) {
      debugPrint('App Initialization Error: $e');
    }
    runApp(ErrorApp(error: e.toString()));
  }
}

/// Initialize notification services for a signed-in user.
/// Called both at app start (if already logged in) and after each sign-in.
Future<void> initializeNotificationServicesForUser(String userId) async {
  try {
    await SupabaseNotificationService().initialize(userId: userId);
    // Register the user ID in FCMService so token refreshes are auto-saved.
    FCMService().setCurrentUserId(userId);
    await SupabaseDeviceTokenService().saveDeviceToken(userId);
    await BookingReminderService().initialize();
    if (kDebugMode) {
      debugPrint('✅ Notification services initialized for user $userId');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ Notification service init error: $e');
    }
  }
}

/// Initialize YouTube API with validation
Future<void> _initializeYouTubeApi() async {
  try {
    if (kDebugMode) {
      debugPrint('🎥 Initializing YouTube API...');
    }

    final youtubeApi = YouTubeApiManager();
    await youtubeApi.initialize();

    if (kDebugMode) {
      debugPrint('✅ YouTube API initialized successfully');
      // Note: API key validation is skipped in debug to avoid wasting quota.
      // The key fails with 403 in debug because the debug SHA-1 is not
      // registered in Google Cloud Console for Android app restrictions.
      // Register your debug SHA-1 fingerprint there to enable YouTube in debug.
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('⚠️ YouTube API initialization failed: $e');
      debugPrint('Live darshan features may not work properly');
    }
    // Don't throw error - app should continue to work without YouTube features
  }
}

class SwastikApp extends StatefulWidget {
  const SwastikApp({super.key});

  @override
  State<SwastikApp> createState() => _SwastikAppState();
}

class _SwastikAppState extends State<SwastikApp> with WidgetsBindingObserver {
  final AccessibilityService _accessibilityService = AccessibilityService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer to re-apply system UI on app resume
    WidgetsBinding.instance.addObserver(this);

    // Wire navigator key into FCM for deep-link navigation
    FCMService().setNavigatorKey(_navigatorKey);

    // Apply system UI configuration on app start
    configureSystemUI();

    // Defer heavy initialization to avoid blocking main thread
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAccessibility();
      _initializeServices();
      // NOTE: Live status monitoring is now initialized after user authentication
      // See _initializeLiveStatusMonitoring() - called from authenticated screens
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Re-apply system UI when app resumes (handles hot reload)
    if (state == AppLifecycleState.resumed) {
      configureSystemUI();
    }
  }

  Future<void> _initializeAccessibility() async {
    // Initialize accessibility in background to avoid blocking UI
    unawaited(
      Future(() async {
        try {
          await _accessibilityService.initialize();
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          debugPrint('❌ Failed to initialize accessibility service: $e');
        }
      }),
    );
  }

  /// Initialize core services
  Future<void> _initializeServices() async {
    // Initialize services in background to avoid blocking UI
    unawaited(
      Future(() async {
        try {
          // Initialize Stripe Payment Service
          try {
            await StripePaymentService.instance.initialize();
            debugPrint('✅ Stripe Payment Service initialized');
          } catch (e) {
            debugPrint('⚠️ Stripe initialization failed: $e');
            debugPrint('💡 Donations will use fallback payment methods');
          }
        } catch (e) {
          debugPrint('❌ Failed to initialize core services: $e');
        }
      }),
    );
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Clean up hybrid live detection
    HybridLiveDetector().stopAllMonitoring();

    // Clean up all centralized services
    unawaited(services.disposeAll());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-apply system UI config on every frame in debug mode (survives hot reload)
    assert(() {
      configureSystemUI();
      return true;
    }());

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: _accessibilityService),
      ],
      child: Consumer<AccessibilityService>(
        builder: (context, accessibilityService, child) {
          // Sync system accessibility settings (text scale, screen reader) on every build
          accessibilityService.updateWithContext(context);
          return MaterialApp(
            title: 'Swastik App',
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AccessibilityTheme.getTheme(context),
            home: const WelcomeScreen1(),
            routes: {
              '/auth_intro': (context) => const AuthIntroScreen(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/home': (context) => const MainNavigationScreen(),
              '/main_navigation': (context) => const MainNavigationScreen(),
              '/admin_home': (context) => const AdminHomeScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/notification_preferences': (context) =>
                  const NotificationPreferencesScreen(),
              '/preferences': (context) => const UserPreferencesScreen(),
              '/profile': (context) => const UserProfileScreen(),
              '/favorites': (context) => const FavoritesScreen(),
              '/fav_temples': (context) => const FavoritesScreen(),
              '/donations': (context) => const DonationScreen(),
              '/donate': (context) => const DonationScreen(),
              '/recent_donations': (context) => const RecentDonationsScreen(),
              '/bookings': (context) => const BookingScreen(),
              '/booking': (context) => const BookingScreen(),
              '/temple_search': (context) => const TempleSearchScreen(),
              '/nearby': (context) => const NearbyScreen(),
              '/best_partners': (context) => const BestPartnersScreen(),
              '/community': (context) => const CommunityScreen(),
              '/events': (context) => const AllEventsScreen(),
              '/my_bookings': (context) => const MyBookingsScreen(),
              '/booking_detail': (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                if (args is Map<String, dynamic>) {
                  // When navigated with bookingId, show MyBookingsScreen
                  return const MyBookingsScreen();
                }
                return const MyBookingsScreen();
              },
              '/temple_events': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is Map<String, dynamic>) {
                  return TempleEventsScreen(
                    templeId: args['templeId'] as String? ?? '',
                    templeName:
                        args['templeName'] as String? ?? 'Temple Events',
                  );
                }
                // Fallback: show a generic events screen
                return const TempleSearchScreen();
              },
              '/temple_detail': (context) {
                final args = ModalRoute.of(context)!.settings.arguments;
                if (args is Temple) {
                  return TempleDetailScreen(temple: args);
                }
                // If args is a string (temple ID from FCM), navigate to search
                return const TempleSearchScreen();
              },
            },
            builder: (context, child) {
              ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                return SimpleErrorWidget(errorDetails: errorDetails);
              };

              // Apply text scaling
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: accessibilityService.textScaler),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Error app shown when initialization fails
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swastik App - Error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF8F0),
        body: SafeArea(
          child: FallbackUI(
            title: 'App Initialization Failed',
            message:
                'The app failed to start properly. Please restart the app or contact support if the problem persists.',
            type: FallbackUIType.error,
            onRetry: () {
              SystemNavigator.pop();
            },
          ),
        ),
      ),
    );
  }
}

/// Simple error widget for handling widget build errors
class SimpleErrorWidget extends StatelessWidget {
  final FlutterErrorDetails errorDetails;

  const SimpleErrorWidget({super.key, required this.errorDetails});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: const Color(0xFFF8F9FA),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              kDebugMode
                  ? errorDetails.exception.toString()
                  : 'An unexpected error occurred. Please restart the app.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
              child: const Text('Restart App'),
            ),
          ],
        ),
      ),
    );
  }
}
