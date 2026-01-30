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

  Future<void> _trackQuickEvent(String eventName) async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

    try {
      await _klaviyo.trackEvent(
        KlaviyoEvent(
          name: eventName,
          properties: {},
          timestamp: DateTime.now(),
        ),
      );

      setState(() {
        _status = 'Event "$eventName" tracked successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to track event: $e';
      });
    }
  }

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

            ElevatedButton.icon(
              onPressed: () => _trackQuickEvent('Opened App'),
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Opened App'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _trackQuickEvent('Viewed Product'),
              icon: const Icon(Icons.remove_red_eye),
              label: const Text('Viewed Product'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _trackQuickEvent('Added to Cart'),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Added to Cart'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _trackQuickEvent('Started Checkout'),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Started Checkout'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _trackQuickEvent('Test Event'),
              icon: const Icon(Icons.science),
              label: const Text('Test Event'),
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
