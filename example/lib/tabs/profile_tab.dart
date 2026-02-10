import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart' show setupSilentPushListener;
import 'forms_tab.dart';
import 'geofencing_tab.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final KlaviyoSDK _klaviyo = KlaviyoSDK();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _externalIdController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _isInitialized = false;
  String _status = 'Enter your Klaviyo API key to initialize';
  String? _currentEmail;
  String? _currentPhoneNumber;
  String? _currentExternalId;

  static const String _apiKeyPrefsKey = 'klaviyo_api_key';

  //#region Lifecycle

  @override
  void initState() {
    super.initState();
    _loadSavedApiKey();
  }

  Future<void> _loadSavedApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedApiKey = prefs.getString(_apiKeyPrefsKey);

      if (savedApiKey != null && savedApiKey.isNotEmpty) {
        setState(() {
          _apiKeyController.text = savedApiKey;
        });
        // Only initialize if not already initialized
        if (!_klaviyo.isInitialized) {
          await _initializeSDK();
        } else {
          setState(() {
            _isInitialized = true;
            _status = 'SDK already initialized';
          });
        }
      }
    } catch (e) {
      print('Failed to load saved API key: $e');
    }
  }

  //#endregion

  //#region Business Logic

  Future<void> _initializeSDK() async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      setState(() {
        _status = 'Please enter an API key';
      });
      return;
    }

    try {
      await _klaviyo.initialize(
        apiKey: apiKey,
        logLevel: KlaviyoLogLevel.debug,
        environment: PushEnvironment.development,
      );

      // Save API key
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyPrefsKey, apiKey);

      // Register FCM token with Klaviyo (Android only)
      if (Platform.isAndroid) {
        try {
          final messaging = FirebaseMessaging.instance;
          final token = await messaging.getToken();
          if (token != null) {
            await _klaviyo.setPushToken(token);
          }
        } catch (e) {
          print('Failed to register FCM token: $e');
        }
      }

      // Set up silent push listener now that SDK is initialized
      setupSilentPushListener();

      // Sync current profile values
      await _syncCurrentProfile();

      setState(() {
        _isInitialized = true;
        _status = 'SDK initialized successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize: $e';
      });
    }
  }

  Future<void> _syncCurrentProfile() async {
    try {
      final email = await _klaviyo.getEmail();
      final phoneNumber = await _klaviyo.getPhoneNumber();
      final externalId = await _klaviyo.getExternalId();

      setState(() {
        _currentEmail = email;
        _currentPhoneNumber = phoneNumber;
        _currentExternalId = externalId;
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to sync profile: $e';
      });
    }
  }

  Future<void> _setEmail() async {
    if (!_isInitialized) return;

    try {
      await _klaviyo.setEmail(_emailController.text);
      await _syncCurrentProfile();
      setState(() {
        _status = 'Email set successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set email: $e';
      });
    }
  }

  Future<void> _setPhoneNumber() async {
    if (!_isInitialized) return;

    try {
      await _klaviyo.setPhoneNumber(_phoneController.text);
      await _syncCurrentProfile();
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
    if (!_isInitialized) return;

    try {
      await _klaviyo.setExternalId(_externalIdController.text);
      await _syncCurrentProfile();
      setState(() {
        _status = 'External ID set successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set external ID: $e';
      });
    }
  }

  Future<void> _setFullProfile() async {
    if (!_isInitialized) return;

    try {
      await _klaviyo.setProfile(
        KlaviyoProfile(
          email:
              _emailController.text.isNotEmpty ? _emailController.text : null,
          phoneNumber:
              _phoneController.text.isNotEmpty ? _phoneController.text : null,
          externalId: _externalIdController.text.isNotEmpty
              ? _externalIdController.text
              : null,
          firstName: _firstNameController.text.isNotEmpty
              ? _firstNameController.text
              : null,
          lastName: _lastNameController.text.isNotEmpty
              ? _lastNameController.text
              : null,
        ),
      );
      await _syncCurrentProfile();
      setState(() {
        _status = 'Full profile set successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to set profile: $e';
      });
    }
  }

  Future<void> _resetProfile() async {
    if (!_isInitialized) return;

    try {
      await _klaviyo.resetProfile();
      await _syncCurrentProfile();
      setState(() {
        _emailController.clear();
        _phoneController.clear();
        _externalIdController.clear();
        _firstNameController.clear();
        _lastNameController.clear();
        _status = 'Profile reset successfully';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to reset profile: $e';
      });
    }
  }

  Future<void> _resetSDK() async {
    try {
      // Reset profile first if initialized
      if (_isInitialized) {
        await _klaviyo.resetProfile();
      }

      // Clear saved API key
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_apiKeyPrefsKey);

      // Clear all controllers
      _apiKeyController.clear();
      _emailController.clear();
      _phoneController.clear();
      _externalIdController.clear();
      _firstNameController.clear();
      _lastNameController.clear();

      // Reset static state in other tabs
      FormsTab.resetState();
      GeofencingTab.resetState();

      setState(() {
        _isInitialized = false;
        _currentEmail = null;
        _currentPhoneNumber = null;
        _currentExternalId = null;
        _status = 'SDK reset. Enter API key to initialize';
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to reset SDK: $e';
      });
    }
  }

  //#endregion

  //#region View

  Widget _buildProfileValueRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '(not set)',
              style: TextStyle(
                color: value != null ? Colors.black : Colors.grey.shade600,
                fontStyle: value != null ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
                color: _isInitialized
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _isInitialized
                      ? Colors.green.shade900
                      : Colors.orange.shade900,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Current Profile Values Section
            if (_isInitialized) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Profile Values',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: _syncCurrentProfile,
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildProfileValueRow('Email', _currentEmail),
                    _buildProfileValueRow('Phone Number', _currentPhoneNumber),
                    _buildProfileValueRow('External ID', _currentExternalId),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // API Key Section
            if (!_isInitialized) ...[
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initializeSDK,
                child: const Text('Initialize SDK'),
              ),
            ],

            // Profile Fields (only show when initialized)
            if (_isInitialized) ...[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _setEmail,
                child: const Text('Set Email'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _setPhoneNumber,
                child: const Text('Set Phone Number'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _externalIdController,
                decoration: const InputDecoration(
                  labelText: 'External ID',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _setExternalId,
                child: const Text('Set External ID'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _setFullProfile,
                child: const Text('Set Full Profile'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _resetProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset Profile'),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _resetSDK,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Reset SDK & Change API Key'),
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
    _apiKeyController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _externalIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
