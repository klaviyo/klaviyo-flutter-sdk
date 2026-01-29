import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

class FormsTab extends StatefulWidget {
  const FormsTab({super.key});

  @override
  State<FormsTab> createState() => _FormsTabState();
}

class _FormsTabState extends State<FormsTab> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  String _status = 'Manage in-app forms here';
  bool _isRegistered = false;

  Future<void> _registerForForms() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

    try {
      await _klaviyo.registerForInAppForms();
      setState(() {
        _isRegistered = true;
        _status = 'Registered for in-app forms successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to register for forms: $e';
      });
    }
  }

  Future<void> _unregisterFromForms() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status = 'SDK not initialized.';
      });
      return;
    }

    try {
      await _klaviyo.unregisterFromInAppForms();
      setState(() {
        _isRegistered = false;
        _status = 'Unregistered from in-app forms';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to unregister from forms: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forms'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isRegistered
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _isRegistered
                      ? Colors.green.shade900
                      : Colors.grey.shade800,
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (!_isRegistered) ...[
              ElevatedButton(
                onPressed: _registerForForms,
                child: const Text('Register for In-App Forms'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _unregisterFromForms,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Unregister from In-App Forms'),
              ),
            ],

            const SizedBox(height: 20),
            const Text(
              'Note: In-app forms will be displayed automatically based on your Klaviyo account configuration.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
