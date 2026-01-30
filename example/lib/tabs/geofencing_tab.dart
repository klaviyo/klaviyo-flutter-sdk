import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

class GeofencingTab extends StatefulWidget {
  const GeofencingTab({super.key});

  @override
  State<GeofencingTab> createState() => _GeofencingTabState();
}

class _GeofencingTabState extends State<GeofencingTab>
    with WidgetsBindingObserver {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  String _status = 'Geofencing management';
  bool _isRegistered = false;
  List<Geofence> _currentGeofences = [];
  String? _locationPermissionState;

  @override
  void initState() {
    super.initState();
    _checkLocationPermissions();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app returns to foreground, refresh permission state
    if (state == AppLifecycleState.resumed) {
      _checkLocationPermissions();
    }
  }

  Future<void> _checkLocationPermissions() async {
    final alwaysStatus = await Permission.locationAlways.status;
    final whenInUseStatus = await Permission.locationWhenInUse.status;

    setState(() {
      if (alwaysStatus.isGranted) {
        _locationPermissionState = 'always';
      } else if (whenInUseStatus.isGranted) {
        _locationPermissionState = 'whenInUse';
      } else {
        _locationPermissionState = null;
      }
    });
  }

  Future<void> _requestLocationPermission(bool always) async {
    try {
      PermissionStatus status;
      if (always) {
        // On iOS, must have "When In Use" before requesting "Always"
        if (Platform.isIOS) {
          final whenInUseStatus = await Permission.locationWhenInUse.status;
          if (!whenInUseStatus.isGranted) {
            setState(() {
              _status =
                  'Please grant "When In Use" permission first (iOS requirement)';
            });
            return;
          }
        }
        status = await Permission.locationAlways.request();

        // On iOS, if "Always" is not granted after request, guide user to Settings
        if (Platform.isIOS && !status.isGranted) {
          setState(() {
            _status =
                'To enable "Always" permission, tap below to open Settings, then tap Location → Always';
          });
          // Open Settings after a brief delay
          await Future.delayed(const Duration(milliseconds: 500));
          await openAppSettings();
          return;
        }
      } else {
        status = await Permission.locationWhenInUse.request();
      }

      await _checkLocationPermissions();

      setState(() {
        if (status.isGranted) {
          _status = 'Location permission granted';
        } else {
          _status = 'Location permission denied';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to request location permission: $e';
      });
    }
  }

  Future<void> _registerGeofencing() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status =
            'SDK not initialized. Please initialize in Profile tab first.';
      });
      return;
    }

    // Check that "Always" location permission is granted before registering
    final alwaysStatus = await Permission.locationAlways.status;
    if (!alwaysStatus.isGranted) {
      setState(() {
        _status =
            'Location "Always" permission required for geofencing. Please grant permission first.';
      });
      return;
    }

    try {
      await _klaviyo.registerGeofencing();
      setState(() {
        _isRegistered = true;
        _status = 'Geofencing registered successfully!';
      });
      // Load geofences after registration
      await _loadGeofences();
    } catch (e) {
      setState(() {
        _status = 'Failed to register geofencing: $e';
      });
    }
  }

  Future<void> _unregisterGeofencing() async {
    if (!_klaviyo.isInitialized) {
      setState(() {
        _status = 'SDK not initialized.';
      });
      return;
    }

    try {
      await _klaviyo.unregisterGeofencing();
      setState(() {
        _isRegistered = false;
        _currentGeofences = [];
        _status = 'Geofencing unregistered';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to unregister geofencing: $e';
      });
    }
  }

  Future<void> _loadGeofences() async {
    if (!_klaviyo.isInitialized) {
      return;
    }

    try {
      // ignore: invalid_use_of_internal_member
      final geofences = await _klaviyo.getCurrentGeofences();
      setState(() {
        _currentGeofences = geofences;
        _status = 'Loaded ${geofences.length} geofence(s)';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to load geofences: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geofencing'),
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

            // Location Permissions Section
            const Text(
              'Location Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Text(
              'Status: ${_locationPermissionState ?? "Not granted"}',
            ),
            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: () => _requestLocationPermission(false),
              child: const Text('Request "When In Use" Permission'),
            ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: () => _requestLocationPermission(true),
              child: const Text('Request "Always" Permission'),
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 20),

            // Geofencing Section
            const Text(
              'Geofencing Registration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (!_isRegistered) ...[
              ElevatedButton(
                onPressed: _registerGeofencing,
                child: const Text('Register Geofencing'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Note: Location permissions must be granted before registering for geofencing.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _unregisterGeofencing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Unregister Geofencing'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadGeofences,
                child: const Text('Refresh Geofences'),
              ),
            ],

            const SizedBox(height: 20),

            // Geofences List
            if (_currentGeofences.isNotEmpty) ...[
              const Text(
                'Current Geofences:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._currentGeofences.map(
                (geofence) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text('ID: ${geofence.identifier}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lat: ${geofence.latitude.toStringAsFixed(6)}'),
                        Text('Lng: ${geofence.longitude.toStringAsFixed(6)}'),
                        Text('Radius: ${geofence.radius.toStringAsFixed(0)}m'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
