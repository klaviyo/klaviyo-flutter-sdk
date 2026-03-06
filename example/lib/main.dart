import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

import 'tabs/profile_tab.dart';
import 'tabs/events_tab.dart';
import 'tabs/forms_tab.dart';
import 'tabs/push_tab.dart';
import 'tabs/geofencing_tab.dart';

final _logger = Logger('KlaviyoExample');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

  // Initialize Firebase for FCM (Android only)
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
      _setupFCM();
    } catch (e) {
      _logger.warning('Firebase initialization failed: $e');
    }
  }

  runApp(const MyApp());
}

/// Set up Firebase Cloud Messaging for Android
Future<void> _setupFCM() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission();

    // Listen for token refresh
    // Note: Initial token registration happens in ProfileTab after SDK initialization
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) {
        _logger.info('FCM Token refreshed: $newToken');
        final klaviyo = KlaviyoSDK();
        if (klaviyo.isInitialized) {
          klaviyo.setPushToken(newToken).catchError((error) {
            _logger.warning(
              'Failed to register refreshed FCM token: $error',
            );
          });
        }
      },
      onError: (error) {
        _logger.warning('Error listening for token refresh: $error');
      },
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.info(
        'Foreground message received: ${message.notification?.title}',
      );
    });
  } catch (e) {
    _logger.warning('FCM setup failed: $e');
  }
}

/// Subscription for silent push notifications.
/// Tracked to prevent duplicate subscriptions on SDK re-initialization.
StreamSubscription<Map<String, dynamic>>? _silentPushSubscription;

/// Set up listener for silent push notifications.
/// Called from ProfileTab after SDK initialization.
void setupSilentPushListener() {
  final klaviyo = KlaviyoSDK();
  if (!klaviyo.isInitialized) {
    _logger.warning(
      'Cannot set up silent push listener: SDK not initialized',
    );
    return;
  }

  // Cancel any existing subscription to prevent duplicates
  _silentPushSubscription?.cancel();

  _silentPushSubscription = klaviyo.onPushNotification.listen((eventData) {
    final eventType = eventData['type'] as String? ?? '';

    if (eventType == 'silent_push_received') {
      final data = eventData['data'];
      final userInfo =
          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

      _logger.info('Silent push received: $userInfo');
      _showSilentPushAlert(userInfo);
    }
  });
}

void _showSilentPushAlert(Map<String, dynamic> userInfo) {
  final context = _router.routerDelegate.navigatorKey.currentContext;
  if (context == null) {
    _logger.warning('Cannot show alert: context not available');
    return;
  }

  showAdaptiveDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog.adaptive(
        title: const Text('Silent Push Received'),
        content: SingleChildScrollView(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _formatUserInfo(userInfo),
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 12,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

String _formatUserInfo(Map<String, dynamic> userInfo) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(userInfo);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Klaviyo Flutter SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

// GoRouter configuration with bottom navigation
final GoRouter _router = GoRouter(
  initialLocation: '/profile',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileTab(),
          ),
        ),
        GoRoute(
          path: '/events',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: EventsTab(),
          ),
        ),
        GoRoute(
          path: '/forms',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: FormsTab(),
          ),
        ),
        GoRoute(
          path: '/push',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PushTab(),
          ),
        ),
        GoRoute(
          path: '/geofencing',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GeofencingTab(),
          ),
        ),
      ],
    ),
  ],
  redirect: (context, state) async {
    final url = state.uri.toString();
    _logger.info('Redirect called with URL: $url');
    _logger.fine(
      'URI scheme: ${state.uri.scheme}, path: ${state.uri.path}',
    );

    // Handle Klaviyo universal tracking links
    final klaviyo = KlaviyoSDK();
    if (klaviyo.isInitialized) {
      _logger.fine('Checking if tracking link...');
      final isTrackingLink = klaviyo.handleUniversalTrackingLink(url);
      _logger.info('Is tracking link: $isTrackingLink');

      // If this is a tracking link, stay on current page (no navigation)
      // The SDK will resolve and broadcast the destination, triggering another redirect
      if (isTrackingLink) {
        _logger.fine(
          'Tracking link - staying on current location: ${state.matchedLocation}',
        );
        return state.matchedLocation;
      }
    }

    // Parse the path from custom scheme or universal link
    _logger.fine('URI authority: ${state.uri.authority}');
    final path = _parseDeepLinkPath(state.uri);
    _logger.fine('Parsed path: $path');

    // Redirect root to profile
    if (path == '/' || path.isEmpty) {
      _logger.fine(
        'Root path detected, redirecting to /profile',
      );
      return '/profile';
    }

    // Navigate to valid paths
    if (path != state.uri.path) {
      _logger.fine(
        'Path differs from state.uri.path, returning: $path',
      );
      return path;
    }

    _logger.fine('No redirect needed, returning null');
    return null;
  },
);

/// Parse deep link path from custom scheme or universal link URL
String _parseDeepLinkPath(Uri uri) {
  // For custom scheme URLs (e.g., com.klaviyo.flutterexample://product/123),
  // the URI parser treats the first segment as authority/host, not path
  if (uri.scheme.isNotEmpty && uri.scheme != 'http' && uri.scheme != 'https') {
    // Custom scheme: combine authority and path
    // For com.klaviyo.flutterexample://product/123:
    //   uri.authority = "product"
    //   uri.path = "/123"
    String path = uri.authority;

    // Append the path component if it exists and is not just "/"
    if (uri.path.isNotEmpty && uri.path != '/') {
      path = '$path${uri.path}';
    }

    // Remove trailing slash if present
    if (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }

    // Ensure path starts with /
    if (path.isNotEmpty && !path.startsWith('/')) {
      path = '/$path';
    }

    return path.isEmpty ? '/' : path;
  }

  // For universal links (http/https) or internal navigation (empty scheme),
  // go_router already parsed the path correctly
  return uri.path;
}

/// Scaffold with bottom navigation bar
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.send),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Forms',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Push',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Geofencing',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/profile')) {
      return 0;
    }
    if (location.startsWith('/events')) {
      return 1;
    }
    if (location.startsWith('/forms')) {
      return 2;
    }
    if (location.startsWith('/push')) {
      return 3;
    }
    if (location.startsWith('/geofencing')) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/profile');
        break;
      case 1:
        context.go('/events');
        break;
      case 2:
        context.go('/forms');
        break;
      case 3:
        context.go('/push');
        break;
      case 4:
        context.go('/geofencing');
        break;
    }
  }
}
