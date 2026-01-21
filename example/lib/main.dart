import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for FCM (Android only)
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print('Firebase initialization failed: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  bool _isInitialized = false;
  String _status = 'Enter your Klaviyo API key to initialize';

  static const String _apiKeyPrefsKey = 'klaviyo_api_key';

  @override
  void initState() {
    super.initState();

    // Load saved API key
    _loadSavedApiKey();

    // Set up FCM token listeners and foreground notification listener (Android only)
    if (Platform.isAndroid) {
      _setupFCM();
      _setupForegroundNotificationListener();
    }
  }

  /// Load API key from local storage
  Future<void> _loadSavedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedApiKey = prefs.getString(_apiKeyPrefsKey);

      if (savedApiKey != null && savedApiKey.isNotEmpty) {
        setState(() {
          _apiKeyController.text = savedApiKey;
        });
      }
    } catch (e) {
      print('Failed to load saved API key: $e');
    }
  }

  /// Set up Firebase Cloud Messaging (FCM) token collection and listeners
  /// NOTE: The native KlaviyoFirebaseMessagingService also registers tokens via onNewToken()
  /// This Dart-side registration provides visibility and acts as a backup
  Future<void> _setupFCM() async {
    try {
      // Get current FCM token
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print('Current FCM token retrieved');
        print('Token: $token');
        await _handleFCMToken(token);
      } else {
        print('No FCM token available yet');
      }

      // Listen for token refreshes
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('FCM token refresh: $newToken');
        _handleFCMToken(newToken);
      }, onError: (error) {
        print('Error listening for token refresh: $error');
      });
    } catch (e) {
      print('FCM setup failed: $e');
    }
  }

  /// Set up listener for foreground notifications
  /// This is for logging and updating UI when notifications arrive while app is in foreground
  void _setupForegroundNotificationListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('FOREGROUND NOTIFICATION RECEIVED');
      print('Message ID: ${message.messageId}');
      print('From: ${message.from}');
      print('Notification payload: ${message.notification?.title}');
      print('Data payload: ${message.data}');
      setState(() {
        _status =
            'Received push: ${message.notification?.title ?? message.data['title'] ?? "No title"}';
      });
    });
  }

  /// Handle FCM token by forwarding to Klaviyo SDK
  Future<void> _handleFCMToken(String token) async {
    try {
      if (_isInitialized) {
        await _klaviyo.setPushToken(token);
        print('Token registered with Klaviyo successfully');
        setState(() {
          _status = 'FCM token registered with Klaviyo';
        });
      } else {
        print(
            'Klaviyo SDK not initialized yet, token will be registered after initialization');
      }
    } catch (e) {
      print('Failed to register token with Klaviyo: $e');
      setState(() {
        _status = 'Failed to register FCM token: $e';
      });
    }
  }

  Future<void> _initializeKlaviyo() async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      setState(() {
        _status = 'Please enter a valid API key';
      });
      return;
    }

    try {
      print('Starting Klaviyo initialization with API key: $apiKey');
      await _klaviyo.initialize(
        apiKey: apiKey,
        logLevel: KlaviyoLogLevel.debug,
        environment: PushEnvironment.development,
      );

      // Save API key to local storage for next time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefsKey, apiKey);

      // Set up push notification listeners
      _setupPushNotificationListeners();

      setState(() {
        _isInitialized = true;
        _status = 'Initialized successfully with API key: $apiKey';
      });

      // Register FCM token with Klaviyo now that SDK is initialized (Android only)
      if (Platform.isAndroid) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _handleFCMToken(token);
        } else {
          print('No FCM token available to register');
        }
      }
    } catch (e) {
      print('Klaviyo initialization failed: $e');
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  void _setupPushNotificationListeners() {
    // Listen for push notification opens
    _klaviyo.onPushNotification.listen((eventData) {
      final eventType = eventData['type'] as String? ?? '';
      print('Received push notification event: $eventType');

      if (eventType == 'push_notification_opened') {
        final userInfo = eventData['data'] as Map<String, dynamic>? ?? {};
        print('Push notification opened: $userInfo');

        setState(() {
          _status = 'Push notification opened! Data: ${userInfo.toString()}';
        });
      }
    });
  }

  Future<void> _resetSdk() async {
    // Clear saved API key from local storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyPrefsKey);
      _apiKeyController.clear();
    } catch (e) {
      print('Failed to clear saved API key: $e');
    }

    setState(() {
      _isInitialized = false;
      _status = 'SDK reset. Enter a new API key to reinitialize.';
    });
  }

  Future<void> _setProfile() async {
    try {
      final profile = KlaviyoProfile(
        email: 'michael@michaelsons.com',
        firstName: 'Michael',
        lastName: 'Michaelson',
        phoneNumber: '+1234567899',
        properties: {
          'plan': 'premium',
          'signup_date': DateTime.now().toIso8601String(),
        },
      );

      await _klaviyo.setProfile(profile);
      setState(() {
        _status = 'Profile set successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set profile: $e';
      });
    }
  }

  Future<void> _setEmail() async {
    try {
      final randomEmail =
          'user_${DateTime.now().millisecondsSinceEpoch}@klaviyo.com';
      print('📧 Setting email: $randomEmail');
      await _klaviyo.setEmail(randomEmail);
      print('✅ Email set successfully');
      setState(() {
        _status = 'Email set successfully: $randomEmail';
      });
    } catch (e) {
      print('❌ Failed to set email: $e');
      setState(() {
        _status = 'Failed to set email: $e';
      });
    }
  }

  Future<void> _setPhoneNumber() async {
    try {
      const phoneNumber = '+12015557210';
      print('📱 Setting phone number: $phoneNumber');
      await _klaviyo.setPhoneNumber(phoneNumber);
      print('✅ Phone number set successfully');
      setState(() {
        _status = 'Phone number set successfully: $phoneNumber';
      });
    } catch (e) {
      print('❌ Failed to set phone number: $e');
      setState(() {
        _status = 'Failed to set phone number: $e';
      });
    }
  }

  Future<void> _setExternalId() async {
    try {
      const externalId = 'user_12345';
      print('🆔 Setting external ID: $externalId');
      await _klaviyo.setExternalId(externalId);
      print('✅ External ID set successfully');
      setState(() {
        _status = 'External ID set successfully: $externalId';
      });
    } catch (e) {
      print('❌ Failed to set external ID: $e');
      setState(() {
        _status = 'Failed to set external ID: $e';
      });
    }
  }

  Future<void> _setProfileProperties() async {
    try {
      final properties = {
        'preferences': {'notifications': true, 'marketing': false},
        'last_activity': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
      };
      print('⚙️ Setting profile properties: $properties');
      await _klaviyo.setProfileProperties(properties);
      print('✅ Profile properties set successfully');
      setState(() {
        _status = 'Profile properties set successfully';
      });
    } catch (e) {
      print('❌ Failed to set profile properties: $e');
      setState(() {
        _status = 'Failed to set profile properties: $e';
      });
    }
  }

  Future<void> _trackEvent() async {
    try {
      await _klaviyo.track('App Opened', {
        'source': 'flutter_sdk_example',
        'timestamp': DateTime.now().toIso8601String(),
      });

      setState(() {
        _status = 'Event tracked successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to track event: $e';
      });
    }
  }

  Future<void> _trackComplexEvent() async {
    try {
      final event = KlaviyoEvent(
        name: 'Purchase Completed',
        properties: {
          'value': 99.99,
          'currency': 'USD',
          'product_id': 'prod_123',
          'quantity': 1,
        },
        timestamp: DateTime.now(),
      );

      await _klaviyo.trackEvent(event);
      setState(() {
        _status = 'Complex event tracked successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to track complex event: $e';
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      setState(() {
        _status = 'Notification permission denied';
      });
      throw Exception('Notification permission denied');
    }
  }

  Future<void> _registerForPush() async {
    try {
      await _requestNotificationPermission();

      // Register for push notifications
      // The SDK handles platform differences internally:
      // - iOS: triggers APNs registration
      // - Android: no-op (FCM handles this automatically)
      await _klaviyo.registerForPushNotifications();
      print('Push registration triggered');

      setState(() {
        _status = 'Registered for push notifications';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register for push: $e';
      });
    }
  }

  Future<void> _getPushToken() async {
    try {
      final token = await _klaviyo.getPushToken();
      if (token != null) {
        setState(() {
          _status = 'Push token:\n$token';
        });
        print('Full push token: $token');
      } else {
        setState(() {
          _status = 'No push token available';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Failed to get push token: $e';
      });
    }
  }

  Future<void> _registerForForms() async {
    try {
      final text = _durationController.text.trim();

      final InAppFormConfig? config = switch (text) {
        '' => null, // default 1hr
        '-1' => const InAppFormConfig.infinite(),
        _ => _parseFiniteConfig(text),
      };

      if (config == null && text.isNotEmpty) {
        setState(() {
          _status = 'Invalid duration value. Please enter a number.';
        });
        return;
      }

      await _klaviyo.registerForInAppForms(configuration: config);

      setState(() {
        _status = config == null
            ? 'Registered for in-app forms (1 hour)'
            : config.isInfinite
                ? 'Registered for in-app forms (infinite timeout)'
                : 'Registered for in-app forms (${config.sessionTimeoutDuration!.inSeconds}s)';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register for forms: $e';
      });
    }
  }

  InAppFormConfig? _parseFiniteConfig(String text) {
    final seconds = int.tryParse(text);
    if (seconds == null || seconds < 0) return null;

    return InAppFormConfig(
      sessionTimeoutDuration: Duration(seconds: seconds),
    );
  }

  Future<void> _unregisterFromInAppForms() async {
    try {
      await _klaviyo.unregisterFromInAppForms();
      setState(() {
        _status = 'Unregistered from in-app forms.';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to unregister from in-app forms: $e';
      });
    }
  }

  Future<void> _setLogLevel() async {
    try {
      _klaviyo.setLogLevel(KlaviyoLogLevel.info);
      setState(() {
        _status = 'Log level set to INFO';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set log level: $e';
      });
    }
  }

  Future<void> _resetProfile() async {
    try {
      await _klaviyo.resetProfile();
      setState(() {
        _status = 'Profile reset successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to reset profile: $e';
      });
    }
  }

  /// Set badge count to a specific value
  void _setBadgeCount(int count) {
    try {
      _klaviyo.setBadgeCount(count);
      setState(() {
        _status = 'Badge count set to $count';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set badge count: $e';
      });
    }
  }

  /// Clear the badge (set to 0)
  void _clearBadge() {
    _setBadgeCount(0);
  }

  /// Show badge count dialog to set a custom value
  void _showBadgeCountDialog() {
    final TextEditingController badgeController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Badge Count'),
          content: TextField(
            controller: badgeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter badge count (e.g., 5)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final count = int.tryParse(badgeController.text) ?? 0;
                _setBadgeCount(count);
                Navigator.of(context).pop();
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Klaviyo Flutter SDK Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Klaviyo Flutter SDK Example'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // API Key Input Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Klaviyo API Key',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          hintText: 'Enter your Klaviyo API key (e.g., Xr5bFG)',
                          border: OutlineInputBorder(),
                          helperText:
                              'You can find this in your Klaviyo account settings',
                        ),
                        enabled: !_isInitialized,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isInitialized ? null : _initializeKlaviyo,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(_isInitialized
                                  ? 'Initialized'
                                  : 'Initialize SDK'),
                            ),
                          ),
                          if (_isInitialized) ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _resetSdk,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Reset'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: $_status',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Initialized: $_isInitialized',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Profile Management Section
              _buildSectionHeader('Profile Management'),
              _buildButton('Set Profile', _setProfile),
              _buildButton('Set Email', _setEmail),
              _buildButton('Set Phone Number', _setPhoneNumber),
              _buildButton('Set External ID', _setExternalId),
              _buildButton('Set Profile Properties', _setProfileProperties),
              _buildButton('Reset Profile', _resetProfile, isDestructive: true),

              const SizedBox(height: 16),

              // Event Tracking Section
              _buildSectionHeader('Event Tracking'),
              _buildButton('Track Simple Event', _trackEvent),
              _buildButton('Track Complex Event', _trackComplexEvent),

              const SizedBox(height: 16),

              // Push Notifications Section
              _buildSectionHeader('Push Notifications'),
              _buildButton('Register for Push', _registerForPush),
              _buildButton('Get Push Token', _getPushToken),

              const SizedBox(height: 16),

              // Badge Count Section (iOS only)
              _buildSectionHeader('Badge Count (iOS)'),
              _buildBadgeCountSection(),

              const SizedBox(height: 16),

              // In-App Forms Section
              _buildSectionHeader('In-App Forms'),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Session Timeout Duration (seconds)',
                    hintText: 'Enter seconds (default: 3600)',
                    border: OutlineInputBorder(),
                    helperText: 'Enter -1 for infinite timeout, 0 for timeout '
                        'on background',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true),
                  enabled: _isInitialized,
                ),
              ),
              _buildButton('Register for Forms', _registerForForms),
              _buildButton('Unregister from Forms', _unregisterFromInAppForms),
              const SizedBox(height: 16),

              // Configuration Section
              _buildSectionHeader('Configuration'),
              _buildButton('Set Log Level', _setLogLevel),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback? onPressed,
      {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: ElevatedButton(
        onPressed: _isInitialized ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? Colors.red : null,
          foregroundColor: isDestructive ? Colors.white : null,
        ),
        child: Text(text),
      ),
    );
  }

  Widget _buildBadgeCountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set badge count on the app icon',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized ? _showBadgeCountDialog : null,
                    icon: const Icon(Icons.edit),
                    label: const Text('Custom'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isInitialized ? _clearBadge : null,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _durationController.dispose();
    _klaviyo.dispose();
    super.dispose();
  }
}
