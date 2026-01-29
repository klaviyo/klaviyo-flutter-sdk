import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  final TextEditingController _eventNameController = TextEditingController();
  final TextEditingController _propertyKeyController = TextEditingController();
  final TextEditingController _propertyValueController =
      TextEditingController();

  String _status = 'Track events here';

  Future<void> _trackEvent() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

    final eventName = _eventNameController.text.trim();
    if (eventName.isEmpty) {
      setState(() {
        _status = 'Please enter an event name';
      });
      return;
    }

    try {
      final properties = <String, dynamic>{};
      if (_propertyKeyController.text.isNotEmpty &&
          _propertyValueController.text.isNotEmpty) {
        properties[_propertyKeyController.text] = _propertyValueController.text;
      }

      await _klaviyo.trackEvent(
        KlaviyoEvent(
          name: eventName,
          properties: properties,
          timestamp: DateTime.now(),
        ),
      );

      setState(() {
        _status = 'Event "$eventName" tracked successfully!';
        _eventNameController.clear();
        _propertyKeyController.clear();
        _propertyValueController.clear();
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to track event: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
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
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: TextStyle(color: Colors.blue.shade900),
              ),
            ),
            const SizedBox(height: 20),

            // Event Name
            TextField(
              controller: _eventNameController,
              decoration: const InputDecoration(
                labelText: 'Event Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., Product Viewed',
              ),
            ),
            const SizedBox(height: 16),

            // Property Key
            TextField(
              controller: _propertyKeyController,
              decoration: const InputDecoration(
                labelText: 'Property Key (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., product_id',
              ),
            ),
            const SizedBox(height: 10),

            // Property Value
            TextField(
              controller: _propertyValueController,
              decoration: const InputDecoration(
                labelText: 'Property Value (optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g., 12345',
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _trackEvent,
              child: const Text('Track Event'),
            ),
            const SizedBox(height: 20),

            // Quick Event Buttons
            const Text(
              'Quick Events:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () {
                _eventNameController.text = 'App Opened';
                _trackEvent();
              },
              child: const Text('Track "App Opened"'),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: () {
                _eventNameController.text = 'Button Clicked';
                _propertyKeyController.text = 'button_name';
                _propertyValueController.text = 'quick_event_button';
                _trackEvent();
              },
              child: const Text('Track "Button Clicked"'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _propertyKeyController.dispose();
    _propertyValueController.dispose();
    super.dispose();
  }
}
