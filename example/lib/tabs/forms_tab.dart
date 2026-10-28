import 'dart:async';
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
  final TextEditingController _formIdController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _loadTimeoutController = TextEditingController();
  final TextEditingController _replayWindowController =
      TextEditingController(text: '10');
  bool _loadFailed = false;
  int _retryAttempts = 0;
  String _status = 'Manage in-app forms here';

  // Use a static variable to persist state across widget rebuilds
  static bool _isRegistered = false;

  // Lifecycle event tracking
  StreamSubscription<FormLifecycleEvent>? _lifecycleSubscription;
  final List<String> _lifecycleEvents = [];

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

    // Listen to form lifecycle events
    _lifecycleSubscription = _klaviyo.onFormLifecycleEvent.listen((event) {
      setState(() {
        final timestamp = DateTime.now().toIso8601String().substring(11, 19);
        final formIdInfo = event.formId.isNotEmpty ? ' (${event.formId})' : '';
        final formNameInfo =
            event.formName.isNotEmpty ? ' [${event.formName}]' : '';
        final extra = switch (event) {
          FormCtaClicked(:final buttonLabel, :final deepLinkUrl) =>
            ' button=$buttonLabel url=$deepLinkUrl',
          _ => '',
        };
        _lifecycleEvents.add(
          '[$timestamp] ${event.eventName}$formIdInfo$formNameInfo$extra',
        );
      });
    });
  }

  //#endregion

  //#region Business Logic

  Future<void> _registerForForms({bool retry = false}) async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

    try {
      final text = _durationController.text.trim();

      final InAppFormConfig? sessionConfig = switch (text) {
        '' => const InAppFormConfig(),
        '-1' => const InAppFormConfig.infinite(),
        _ => _parseFiniteConfig(text),
      };

      if (sessionConfig == null) {
        setState(() {
          _status = 'Invalid duration value. Please enter a number.';
        });
        return;
      }

      final loadText = _loadTimeoutController.text.trim();
      final replayText = _replayWindowController.text.trim();
      final loadSeconds = double.tryParse(loadText);
      final replaySeconds = double.tryParse(replayText);
      if ((loadText.isNotEmpty &&
              (loadSeconds == null ||
                  !loadSeconds.isFinite ||
                  loadSeconds <= 0)) ||
          replaySeconds == null ||
          !replaySeconds.isFinite ||
          replaySeconds < 0 ||
          replaySeconds > 30) {
        setState(() {
          _status =
              'Use a positive load timeout and a replay window from 0 to 30 seconds.';
        });
        return;
      }
      if (retry) {
        if (_retryAttempts >= 3) return;
        _retryAttempts++;
      } else {
        _retryAttempts = 0;
      }
      _loadFailed = false;
      final config = sessionConfig.copyWith(
        loadTimeout: loadSeconds == null
            ? null
            : Duration(microseconds: (loadSeconds * 1000000).round()),
        eventReplayWindow:
            Duration(microseconds: (replaySeconds * 1000000).round()),
        onFailure: () {
          if (!mounted) return;
          setState(() {
            _loadFailed = true;
            _isRegistered = false;
            _status =
                'Forms loading failed. Retry when ready ($_retryAttempts/3 retries used).';
            _lifecycleEvents.add(
              '[${DateTime.now().toIso8601String().substring(11, 19)}] Forms loading failed',
            );
          });
        },
      );
      await _klaviyo.registerForInAppForms(configuration: config);

      if (!mounted || _loadFailed) return;
      setState(() {
        _isRegistered = true;
        _status =
            'Forms registration command handled; awaiting native loading.';
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

  Future<void> _openForm() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status = 'SDK not initialized.';
      });
      return;
    }
    final formId = _formIdController.text;
    await _klaviyo.openForm(formId);
    if (!mounted) return;
    setState(() {
      _status =
          'Open command handled; presentation is reported by lifecycle events.';
      _lifecycleEvents.add(
        '[${DateTime.now().toIso8601String().substring(11, 19)}] Open requested: $formId',
      );
    });
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
        _loadFailed = false;
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
        child: ListView(
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
              TextField(
                controller: _loadTimeoutController,
                decoration: const InputDecoration(
                  labelText: 'Load timeout (seconds)',
                  hintText: 'Blank uses the native network timeout',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _replayWindowController,
                decoration: const InputDecoration(
                  labelText: 'Event replay window (0–30 seconds)',
                  helperText: '0 keeps live events and disables history',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadFailed
                    ? (_retryAttempts < 3
                        ? () => _registerForForms(retry: true)
                        : null)
                    : _registerForForms,
                child: Text(
                  _loadFailed
                      ? 'Retry Forms ($_retryAttempts/3)'
                      : 'Register for In-App Forms',
                ),
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
            TextField(
              controller: _formIdController,
              decoration: const InputDecoration(
                labelText: 'Form ID',
                border: OutlineInputBorder(),
                helperText: 'Register for forms before requesting a form.',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _openForm,
              child: const Text('Open'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Note: In-app forms will be displayed automatically based on your Klaviyo account configuration.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),

            // Lifecycle Events Section
            if (_lifecycleEvents.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Form Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: () {
                      setState(() {
                        _lifecycleEvents.clear();
                      });
                    },
                    tooltip: 'Clear events',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  itemCount: _lifecycleEvents.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _lifecycleEvents[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  //#endregion

  @override
  void dispose() {
    _lifecycleSubscription?.cancel();
    _formIdController.dispose();
    _durationController.dispose();
    _loadTimeoutController.dispose();
    _replayWindowController.dispose();
    super.dispose();
  }
}
