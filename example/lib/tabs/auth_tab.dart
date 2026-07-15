import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../auth/auth_models.dart';
import '../auth/jwt_inspector.dart';
import '../auth/refresh_estimate.dart';
import '../auth/scripted_provider.dart';

/// Screen 1 (MAGE-794): drives the SDK's auth-token provider — toggle
/// registration, script the ordered responses, observe the current token, and
/// watch bridge diagnostics live.
class AuthTab extends StatefulWidget {
  const AuthTab({super.key});

  @override
  State<AuthTab> createState() => _AuthTabState();
}

class _AuthTabState extends State<AuthTab> {
  // Drives the live countdowns / polled current-token view (~1/s).
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth')),
      body: AnimatedBuilder(
        animation: authController,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _providerToggle(),
            const Divider(height: 32),
            _responsesSection(),
            const Divider(height: 32),
            _currentTokenSection(),
            const Divider(height: 32),
            _authLogsSection(),
          ],
        ),
      ),
    );
  }

  // ---- Section 1: provider toggle ----------------------------------------

  Widget _providerToggle() {
    final enabled = authController.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auth token provider'),
          value: enabled,
          onChanged: (on) {
            if (on) {
              authController.enable();
            } else {
              authController.disable();
            }
          },
        ),
        Text(
          enabled
              ? 'Registered. Enabling calls unregisterAuthTokenProvider().'
              : 'Disabling calls registerAuthTokenProvider().',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  // ---- Section 2: provider responses -------------------------------------

  Widget _responsesSection() {
    final responses = authController.responses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Provider responses'),
            TextButton.icon(
              onPressed: authController.addResponse,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: responses.length,
          onReorder: authController.reorder,
          itemBuilder: (context, index) =>
              _responseRow(responses[index], index),
        ),
      ],
    );
  }

  Widget _responseRow(AuthResponse response, int index) {
    final locked = authController.isLocked(index);
    final isCurrent =
        authController.enabled && authController.currentCallId == response.id;
    final repeats = authController.isRepeatingLast(index);
    final callLabel = 'Call ${index + 1}${repeats ? '+' : ''}';
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    final secondaryStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(color: secondary);
    final details = _tokenDetails(response, secondaryStyle);

    return Opacity(
      key: ValueKey(response.id),
      opacity: locked ? 0.5 : 1.0,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Call number (secondary), preceded by a dot marking the most
            // recently served response; its label is blue when current.
            Row(
              children: [
                if (isCurrent) ...[
                  const Icon(Icons.circle, size: 8, color: Colors.blue),
                  const SizedBox(width: 6),
                ],
                Text(
                  callLabel,
                  style: secondaryStyle?.copyWith(
                    color: isCurrent ? Colors.blue : secondary,
                  ),
                ),
              ],
            ),
            // Response type (primary).
            Text(
              response.outcome.label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (details != null) details,
          ],
        ),
        onTap: locked
            ? null
            : () => context.push('/configure-auth-response/${response.id}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'duplicate') {
                  authController.duplicateResponse(response.id);
                } else if (action == 'delete') {
                  authController.deleteResponse(response.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicate'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: authController.canDelete(index),
                  child: const Text('Delete'),
                ),
              ],
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
          ],
        ),
      ),
    );
  }

  /// Secondary-style token summary shown beneath the response type:
  /// `(Well-formed|Malformed) | exp: <expiration>[ | delay: <n.nn>s]`.
  /// Returns `null` for the throw outcomes (no token, so no details line).
  Widget? _tokenDetails(AuthResponse response, TextStyle? secondaryStyle) {
    if (response.outcome == AuthOutcome.throwNetworkError ||
        response.outcome == AuthOutcome.throwOtherError) {
      return null;
    }

    // Resolve well-formedness + the expiration display for this response.
    bool wellFormed;
    String expText;
    var expRed = false;
    switch (response.outcome) {
      case AuthOutcome.customToken:
        final claims = inspectJwt(response.customToken);
        wellFormed = claims?.exp != null;
        if (claims?.exp != null) {
          final dt = DateTime.fromMillisecondsSinceEpoch(claims!.exp! * 1000);
          expText = _formatExpiryDate(dt.toLocal());
          expRed = dt.isBefore(DateTime.now());
        } else {
          expText = '--';
        }
      case AuthOutcome.mockToken:
        if (response.mockKind == MockTokenKind.malformed) {
          wellFormed = false;
          expText = '--';
        } else {
          wellFormed = true;
          if (response.mockExpirationMode == MockExpirationMode.duration) {
            final secs = response.mockDuration.inSeconds;
            expText = '${secs}s';
            expRed = secs < 0;
          } else if (response.mockExpiryDate != null) {
            final dt = response.mockExpiryDate!;
            expText = _formatExpiryDate(dt.toLocal());
            expRed = dt.isBefore(DateTime.now());
          } else {
            expText = '--';
          }
        }
      case AuthOutcome.throwNetworkError:
      case AuthOutcome.throwOtherError:
        return null; // handled above
    }

    final delay = response.delay.inMilliseconds / 1000;
    return Text.rich(
      TextSpan(
        style: secondaryStyle,
        children: [
          TextSpan(
            text: wellFormed ? 'Well-formed' : 'Malformed',
            style: TextStyle(color: wellFormed ? Colors.green : Colors.red),
          ),
          // A malformed token has no meaningful expiration — omit the exp part.
          if (wellFormed) ...[
            const TextSpan(text: ' | exp: '),
            TextSpan(
              text: expText,
              style: expRed ? const TextStyle(color: Colors.red) : null,
            ),
          ],
          if (response.delay > Duration.zero)
            TextSpan(text: ' | delay: ${delay.toStringAsFixed(2)}s'),
        ],
      ),
    );
  }

  /// Formats an absolute expiry as `MMM d, yyyy 'at' HH:mm:ss`.
  String _formatExpiryDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at '
        '${pad(dt.hour)}:${pad(dt.minute)}:${pad(dt.second)}';
  }

  // ---- Section 3: current token ------------------------------------------

  Widget _currentTokenSection() {
    final token =
        authController.enabled ? authController.lastReturnedToken : null;
    final status = tokenStatusOf(token);
    final claims = token == null ? null : inspectJwt(token);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Current token'),
        _kv(
          'Status',
          switch (status) {
            TokenStatus.none => '--',
            TokenStatus.wellFormed => 'Well-formed',
            TokenStatus.malformed => 'Malformed',
          },
        ),
        _kv(
          'Expires',
          claims?.exp == null
              ? '--'
              : DateTime.fromMillisecondsSinceEpoch(claims!.exp! * 1000)
                  .toLocal()
                  .toString(),
        ),
        _expiresIn(claims?.exp, now),
        _refreshIn(claims?.iat, claims?.exp, now),
      ],
    );
  }

  Widget _expiresIn(int? exp, int now) {
    if (exp == null) return _kv('Expires in', '--');
    final remaining = exp - now;
    if (remaining <= 0) {
      return _kv('Expires in', 'Expired', color: Colors.red);
    }
    return _kv(
      'Expires in',
      '${remaining}s',
      color: remaining < 30 ? Colors.red : null,
    );
  }

  Widget _refreshIn(int? iat, int? exp, int now) {
    final target = estimateRefreshTargetEpoch(iat: iat, exp: exp);
    if (target == null) return _kv('Refresh in', '--');
    final remaining = target - now;
    if (remaining <= 0) {
      return _kv('Refresh in', 'Refresh due', color: Colors.orange);
    }
    return _kv('Refresh in', '${remaining}s');
  }

  // ---- Section 4: auth logs (bridge diagnostics) -------------------------

  Widget _authLogsSection() {
    final logs = authController.visibleLogs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionTitle('Auth logs'),
            TextButton(
              onPressed: authController.clearLogs,
              child: const Text('Clear'),
            ),
          ],
        ),
        const Text(
          'Wrapper bridge diagnostics (not the native SDK Auth logs).',
          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          const Text(
            'No Auth logs yet. Enable the provider to generate some.',
          )
        else
          for (final entry in logs.reversed) _logLine(entry),
      ],
    );
  }

  Widget _logLine(AuthLogEntry entry) {
    final isError = entry.level >= Level.WARNING;
    final isDebug = entry.level < Level.INFO;
    final time =
        entry.time.toLocal().toString().split(' ').last.split('.').first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '$time  ${entry.message}',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: isError
              ? Colors.red
              : isDebug
                  ? Colors.grey
                  : null,
        ),
      ),
    );
  }

  // ---- Helpers ------------------------------------------------------------

  Widget _sectionTitle(String text) =>
      Text(text, style: Theme.of(context).textTheme.titleMedium);

  Widget _kv(String key, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(key)),
            Expanded(child: Text(value, style: TextStyle(color: color))),
          ],
        ),
      );
}
