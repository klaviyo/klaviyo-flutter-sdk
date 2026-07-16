import 'package:flutter/material.dart';

import '../auth/auth_models.dart';
import '../auth/jwt_inspector.dart';
import '../auth/scripted_provider.dart';

/// Screen 2 (MAGE-794): edits a single scripted response. Changes are held in
/// local working state and only written back to the shared response — where the
/// provider picks them up on its next call, no re-register — when **Done** is
/// tapped. Backing out discards the edits.
class ConfigureAuthResponseScreen extends StatefulWidget {
  const ConfigureAuthResponseScreen({required this.responseId, super.key});

  final String responseId;

  @override
  State<ConfigureAuthResponseScreen> createState() =>
      _ConfigureAuthResponseScreenState();
}

class _ConfigureAuthResponseScreenState
    extends State<ConfigureAuthResponseScreen> {
  late final AuthResponse? _model =
      authController.responseById(widget.responseId);

  late AuthOutcome _outcome;
  late TextEditingController _tokenController;
  bool _obscureToken = true;
  late MockTokenKind _mockKind;
  late MockExpirationMode _expirationMode;
  late Duration _duration;
  DateTime? _expiryDate;
  late double _delaySeconds;

  @override
  void initState() {
    super.initState();
    final m = _model;
    _outcome = m?.outcome ?? AuthOutcome.mockToken;
    _tokenController = TextEditingController(text: m?.customToken ?? '');
    _mockKind = m?.mockKind ?? MockTokenKind.valid;
    _expirationMode = m?.mockExpirationMode ?? MockExpirationMode.duration;
    _duration = m?.mockDuration ?? const Duration(seconds: 45);
    _expiryDate = m?.mockExpiryDate;
    _delaySeconds = (m?.delay ?? Duration.zero).inMilliseconds / 1000.0;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _commit() {
    final m = _model;
    if (m != null) {
      m.outcome = _outcome;
      m.customToken = _tokenController.text;
      m.mockKind = _mockKind;
      m.mockExpirationMode = _expirationMode;
      m.mockDuration = _duration;
      m.mockExpiryDate = _expiryDate;
      m.delay = Duration(milliseconds: (_delaySeconds * 1000).round());
      authController.commitEdits();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_model == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configure Response')),
        body: const Center(child: Text('Response no longer exists.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configure Response'),
        actions: [
          TextButton(
            onPressed: _commit,
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Outcome'),
          RadioGroup<AuthOutcome>(
            groupValue: _outcome,
            onChanged: (v) => setState(() => _outcome = v!),
            child: Column(
              children: [
                for (final outcome in AuthOutcome.values)
                  RadioListTile<AuthOutcome>(
                    title: Text(outcome.label),
                    value: outcome,
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          ..._outcomeConfig(),
          const Divider(height: 32),
          _sectionTitle('Delay'),
          _delayStepper(),
        ],
      ),
    );
  }

  List<Widget> _outcomeConfig() {
    switch (_outcome) {
      case AuthOutcome.customToken:
        return _customTokenConfig();
      case AuthOutcome.mockToken:
        return _mockTokenConfig();
      case AuthOutcome.throwNetworkError:
        return const [
          Text(
            'Throws a connectivity error (SocketException). The SDK classifies '
            'this as a network failure and can retry when connectivity returns.',
          ),
        ];
      case AuthOutcome.throwOtherError:
        return const [
          Text(
            'Throws a non-connectivity error. The SDK treats this as '
            'non-retryable.',
          ),
        ];
    }
  }

  List<Widget> _customTokenConfig() {
    final status = tokenStatusOf(_tokenController.text);
    return [
      _sectionTitle('Custom token'),
      TextField(
        controller: _tokenController,
        obscureText: _obscureToken,
        autocorrect: false,
        enableSuggestions: false,
        style: _obscureToken ? null : const TextStyle(fontFamily: 'monospace'),
        decoration: InputDecoration(
          labelText: 'JWT',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureToken = !_obscureToken),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      _statusRow(status),
      _expirySummary(_tokenController.text),
      const Text(
        'Returned to the SDK verbatim.',
        style: TextStyle(fontStyle: FontStyle.italic),
      ),
    ];
  }

  List<Widget> _mockTokenConfig() {
    return [
      _sectionTitle('Mock token'),
      SegmentedButton<MockTokenKind>(
        segments: const [
          ButtonSegment(value: MockTokenKind.valid, label: Text('Valid')),
          ButtonSegment(
            value: MockTokenKind.malformed,
            label: Text('Malformed'),
          ),
        ],
        selected: {_mockKind},
        onSelectionChanged: (s) => setState(() => _mockKind = s.first),
      ),
      const SizedBox(height: 16),
      if (_mockKind == MockTokenKind.valid) ..._validMockConfig(),
      if (_mockKind == MockTokenKind.malformed)
        const Text('A non-JWT string that fails SDK parsing.'),
    ];
  }

  List<Widget> _validMockConfig() {
    return [
      SegmentedButton<MockExpirationMode>(
        segments: const [
          ButtonSegment(
            value: MockExpirationMode.duration,
            label: Text('Duration'),
          ),
          ButtonSegment(value: MockExpirationMode.date, label: Text('Date')),
        ],
        selected: {_expirationMode},
        onSelectionChanged: (s) => setState(() {
          _expirationMode = s.first;
          // Give Date mode a concrete default so the preview and the served
          // token agree — otherwise a null date reads as "-- / no expiry" in
          // the UI while the engine would still mint a token with an expiry.
          if (_expirationMode == MockExpirationMode.date &&
              _expiryDate == null) {
            _expiryDate = DateTime.now().add(const Duration(seconds: 45));
          }
        }),
      ),
      const SizedBox(height: 12),
      if (_expirationMode == MockExpirationMode.duration)
        _durationPresets()
      else
        _datePicker(),
      const SizedBox(height: 8),
      _lifetimePreview(),
    ];
  }

  Widget _durationPresets() {
    return Wrap(
      spacing: 8,
      children: [
        for (final preset in mockDurationPresets)
          ChoiceChip(
            label: Text(_durationLabel(preset)),
            selected: _duration == preset,
            labelStyle:
                preset.isNegative ? const TextStyle(color: Colors.red) : null,
            onSelected: (_) => setState(() => _duration = preset),
          ),
      ],
    );
  }

  Widget _datePicker() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _expiryDate == null
                ? 'No date selected'
                : 'Expires: ${_expiryDate!.toLocal()}',
          ),
        ),
        TextButton(
          onPressed: _pickExpiryDate,
          child: const Text('Pick date/time'),
        ),
      ],
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(minutes: 5)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiryDate ?? now),
    );
    // Cancelling the time picker aborts the change rather than silently
    // committing a midnight expiry the user never confirmed.
    if (time == null || !mounted) return;
    setState(() {
      _expiryDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Widget _lifetimePreview() {
    final now = DateTime.now();
    final expiresAt = _expirationMode == MockExpirationMode.duration
        ? now.add(_duration)
        : _expiryDate;
    if (expiresAt == null) return const SizedBox.shrink();
    final lifetime = expiresAt.difference(now);
    final expired = lifetime.isNegative;
    return Text(
      expired
          ? 'Token lifetime: already expired'
          : 'Token lifetime: ~${lifetime.inSeconds}s',
      style: TextStyle(color: expired ? Colors.red : null),
    );
  }

  Widget _delayStepper() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _delaySeconds <= 0
              ? null
              : () => setState(
                    () => _delaySeconds =
                        (_delaySeconds - 0.25).clamp(0, 10).toDouble(),
                  ),
        ),
        Text('${_delaySeconds.toStringAsFixed(2)}s'),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _delaySeconds >= 10
              ? null
              : () => setState(
                    () => _delaySeconds =
                        (_delaySeconds + 0.25).clamp(0, 10).toDouble(),
                  ),
        ),
        const Expanded(
          child: Text(
            'Provider waits before resolving/throwing (0–10s).',
            textAlign: TextAlign.end,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }

  Widget _statusRow(TokenStatus status) {
    final (label, color) = switch (status) {
      TokenStatus.none => ('--', Colors.grey),
      TokenStatus.wellFormed => ('Well-formed', Colors.green),
      TokenStatus.malformed => ('Malformed', Colors.red),
    };
    return Row(
      children: [
        const Text('Status: '),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  Widget _expirySummary(String token) {
    final claims = inspectJwt(token);
    if (claims?.exp == null) return const SizedBox.shrink();
    final expiresAt =
        DateTime.fromMillisecondsSinceEpoch(claims!.exp! * 1000).toLocal();
    return Text('Expires: $expiresAt');
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  String _durationLabel(Duration d) {
    if (d.isNegative) return 'Expired (${d.inMinutes}m)';
    if (d.inMinutes >= 1) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
