import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  bool _isInitialized = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initializeKlaviyo();
  }

  Future<void> _initializeKlaviyo() async {
    try {
      print('🚀 Starting Klaviyo initialization...');
      await _klaviyo.initialize(
        apiKey: 'Xr5bFG',
        logLevel: KlaviyoLogLevel.debug,
        environment: PushEnvironment.development,
      );
      print('✅ Klaviyo initialization completed');

      setState(() {
        _isInitialized = true;
        _status = 'Initialized successfully';
      });
    } catch (e) {
      print('❌ Klaviyo initialization failed: $e');
      setState(() {
        _status = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _setProfile() async {
    try {
      final profile = KlaviyoProfile(
        email: 'ajay.subra@klaviyo.com',
        firstName: 'Ajay',
        lastName: 'Subra',
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
      await _klaviyo.setPhoneNumber('+1987654321');
      setState(() {
        _status = 'Phone number set successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set phone number: $e';
      });
    }
  }

  Future<void> _setExternalId() async {
    try {
      await _klaviyo.setExternalId('user_12345');
      setState(() {
        _status = 'External ID set successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set external ID: $e';
      });
    }
  }

  Future<void> _setProfileProperties() async {
    try {
      await _klaviyo.setProfileProperties({
        'preferences': {'notifications': true, 'marketing': false},
        'last_activity': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
      });
      setState(() {
        _status = 'Profile properties set successfully';
      });
    } catch (e) {
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
      await _klaviyo.registerForPushNotifications();
      setState(() {
        _status = 'Registered for push notifications';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register for push: $e';
      });
    }
  }

  Future<void> _setPushToken() async {
    try {
      // Instead of setting a mock token, let's get the actual token info
      final tokenInfo = await _klaviyo.getPushToken();
      setState(() {
        _status = 'Push Token Info: ${tokenInfo.toString()}';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to get push token info: ${e.toString()}';
      });
    }
  }

  Future<void> _getPushToken() async {
    try {
      final token = await _klaviyo.getPushToken();
      setState(() {
        _status = 'Push token retrieved: ${token ?? 'null'}';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to get push token: $e';
      });
    }
  }

  Future<void> _registerForForms() async {
    try {
      final config = const InAppFormConfig(
        enabled: true,
        autoShow: true,
        position: 'bottom',
        theme: {
          'primary_color': '#007bff',
          'text_color': '#333333',
        },
      );

      await _klaviyo.registerForInAppForms(configuration: config);
      setState(() {
        _status = 'Registered for in-app forms';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register for forms: $e';
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

  Future<void> _registerForPushNative() async {
    try {
      // Use the native Klaviyo SDK push registration
      await _requestNotificationPermission();
      await _klaviyo.registerForPushNotifications();
      setState(() {
        _status = 'Registered for push notifications (native)';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register for push: $e';
      });
    }
  }

  Future<void> _getPushTokenNative() async {
    try {
      // For now, this is a placeholder since getPushToken doesn't return real tokens
      final tokenInfo = await _klaviyo.getPushToken();
      setState(() {
        _status = 'Push token info: $tokenInfo';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to get push token: $e';
      });
    }
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
              _buildButton('Register for Push', _registerForPushNative),
              _buildButton('Get Push Token Info', _setPushToken),
              _buildButton('Get Push Token', _getPushTokenNative),

              const SizedBox(height: 16),

              // In-App Forms Section
              _buildSectionHeader('In-App Forms'),
              _buildButton('Register for Forms', _registerForForms),

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

  @override
  void dispose() {
    _klaviyo.dispose();
    super.dispose();
  }
}
