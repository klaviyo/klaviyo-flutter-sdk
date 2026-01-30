import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

class PushTab extends StatefulWidget {
  const PushTab({super.key});

  @override
  State<PushTab> createState() => _PushTabState();
}

class _PushTabState extends State<PushTab> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  final TextEditingController _badgeCountController = TextEditingController();
  String _status = 'Push notification settings';
  String? _pushToken;
  bool _notificationsEnabled = false;
  StreamSubscription<Map<String, dynamic>>? _pushNotificationSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _getPushToken();
    _setupPushNotificationListener();
  }

  void _setupPushNotificationListener() {
    if (!_klaviyo.isInitialized) return;

    // Listen for push notification open events
    _pushNotificationSubscription = _klaviyo.onPushNotification.listen((event) {
      final eventType = event['type'] as String?;
      if (eventType == 'push_notification_opened') {
        final data = event['data'] as Map<String, dynamic>?;
        setState(() {
          _status = 'Push notification opened: ${data?['title'] ?? 'Unknown'}';
        });
      }
    });
  }

  Future<void> _checkPermissions() async {
    // Check notification permission
    final notificationStatus = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = notificationStatus.isGranted;
    });
  }

  Future<void> _getPushToken() async {
    if (!_klaviyo.isInitialized) return;

    try {
      final token = await _klaviyo.getPushToken();
      setState(() {
        _pushToken = token;
      });
    } catch (e) {
      print('Failed to get push token: $e');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

    try {
      await _klaviyo.registerForPushNotifications();

      // Check if permission was actually granted
      await _checkPermissions();

      // Get the token after registration
      await _getPushToken();

      setState(() {
        if (_notificationsEnabled) {
          _status = 'Push notifications registered';
        } else {
          _status = 'Push notification permission denied';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register for push: $e';
      });
    }
  }

  Future<void> _setBadgeCount() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status = 'SDK not initialized.';
      });
      return;
    }

    final count = int.tryParse(_badgeCountController.text);
    if (count == null) {
      setState(() {
        _status = 'Please enter a valid number';
      });
      return;
    }

    try {
      _klaviyo.setBadgeCount(count);
      setState(() {
        _status = 'Badge count set to $count (iOS only)';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set badge count: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: TextStyle(color: Colors.purple.shade900),
              ),
            ),
            const SizedBox(height: 20),

            // Push Notifications Section
            const Text(
              'Push Notifications',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Text('Status: ${_notificationsEnabled ? "Enabled" : "Disabled"}'),
            const SizedBox(height: 10),

            if (_pushToken != null) ...[
              const Text(
                'Push Token:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                _pushToken!,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(height: 10),
            ],

            ElevatedButton(
              onPressed:
                  _notificationsEnabled ? null : _requestNotificationPermission,
              child: Text(
                _notificationsEnabled
                    ? 'Notifications Enabled'
                    : 'Enable Push Notifications',
              ),
            ),
            const SizedBox(height: 20),

            // Badge Count (iOS only)
            if (Platform.isIOS) ...[
              const Text(
                'Badge Count (iOS only)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _badgeCountController,
                      decoration: const InputDecoration(
                        labelText: 'Badge Count',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _setBadgeCount,
                    child: const Text('Set'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pushNotificationSubscription?.cancel();
    _badgeCountController.dispose();
    super.dispose();
  }
}
