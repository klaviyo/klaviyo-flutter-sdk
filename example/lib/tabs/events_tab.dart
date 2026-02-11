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

  //#region Business Logic

  Future<void> _trackEvent({
    EventMetric? eventName,
    Map<String, dynamic>? properties,
    double? value,
    bool clearFields = false,
  }) async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

    // Get event name from parameter or text field
    EventMetric name;
    if (eventName != null) {
      name = eventName;
    } else {
      final textName = _eventNameController.text.trim();
      if (textName.isEmpty) {
        setState(() {
          _status = 'Please enter an event name';
        });
        return;
      }
      name = EventMetric.custom(textName);
    }

    try {
      // Build properties from parameter or text fields
      final eventProperties = properties ?? <String, dynamic>{};
      if (properties == null &&
          _propertyKeyController.text.isNotEmpty &&
          _propertyValueController.text.isNotEmpty) {
        eventProperties[_propertyKeyController.text] =
            _propertyValueController.text;
      }

      await _klaviyo.trackEvent(
        KlaviyoEvent(
          name: name,
          properties: eventProperties,
          value: value,
        ),
      );

      setState(() {
        _status = 'Event "${name.name}" tracked successfully!';
        if (clearFields) {
          _eventNameController.clear();
          _propertyKeyController.clear();
          _propertyValueController.clear();
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to track event: $e';
      });
    }
  }

  //#endregion

  //#region View

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
              onPressed: () => _trackEvent(clearFields: true),
              child: const Text('Track Event'),
            ),
            const SizedBox(height: 20),

            // Quick Event Buttons - Using EventMetric enum
            const Text(
              'Quick Events (Predefined Metrics):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () => _trackEvent(eventName: EventMetric.openedApp),
              icon: const Icon(Icons.rocket_launch),
              label: const Text('Opened App'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _trackEvent(
                eventName: EventMetric.viewedProduct,
                properties: {
                  'product_id': '12345',
                  'product_name': 'Cool Widget',
                  'price': 29.99,
                },
              ),
              icon: const Icon(Icons.remove_red_eye),
              label: const Text('Viewed Product'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _trackEvent(
                eventName: EventMetric.addedToCart,
                properties: {
                  'product_id': '12345',
                  'quantity': 2,
                },
                value: 59.98,
              ),
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Added to Cart'),
            ),
            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: () => _trackEvent(
                eventName: EventMetric.startedCheckout,
                properties: {'cart_items': 3},
                value: 99.99,
              ),
              icon: const Icon(Icons.shopping_cart_checkout),
              label: const Text('Started Checkout'),
            ),
            const SizedBox(height: 8),

            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Custom Events:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () => _trackEvent(
                eventName: const EventMetric.custom('Test Event'),
              ),
              icon: const Icon(Icons.science),
              label: const Text('Test Event'),
            ),
          ],
        ),
      ),
    );
  }

  //#endregion

  @override
  void dispose() {
    _eventNameController.dispose();
    _propertyKeyController.dispose();
    _propertyValueController.dispose();
    super.dispose();
  }
}
