import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

class FormsTab extends StatefulWidget {
  const FormsTab({super.key});

  /// Reset the registration state (called when SDK is reset)
  static void resetState() {
    _FormsTabState.resetState();
  }

  @override
  State<FormsTab> createState() => _FormsTabState();
}

class _FormsTabState extends State<FormsTab> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  final TextEditingController _durationController = TextEditingController();
  String _status = 'Manage in-app forms here';

  // Use a static variable to persist state across widget rebuilds
  static bool _isRegistered = false;

  /// Reset the static state (called when SDK is reset)
  static void resetState() {
    _isRegistered = false;
  }

  //#region Lifecycle

  @override
  void initState() {
    super.initState();
    // Update status based on current registration state
    if (_isRegistered) {
      _status = 'In-app forms are registered';
    }
  }

  //#endregion

  //#region Business Logic

  Future<void> _registerForForms() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

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
        _isRegistered = true;
        _status = config == null
            ? 'Registered for in-app forms (1 hour timeout)'
            : config.isInfinite
                ? 'Registered for in-app forms (infinite timeout)'
                : 'Registered for in-app forms (${config.sessionTimeoutDuration!.inSeconds}s timeout)';
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

  //#endregion

  //#region View

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
              TextField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Session Timeout (seconds)',
                  hintText: 'Leave empty for default (3600s)',
                  border: OutlineInputBorder(),
                  helperText:
                      'Enter -1 for infinite timeout, or number of seconds',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
              ),
              const SizedBox(height: 10),
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

  //#endregion

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }
}
