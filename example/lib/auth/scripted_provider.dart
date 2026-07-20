import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';
import 'package:logging/logging.dart';

import 'auth_models.dart';

/// A single buffered auth diagnostic line (see the note in the Auth-logs UI:
/// these are the wrapper's **bridge diagnostics**, not the native SDK's
/// Auth-category logs — the Dart layer has no access to those).
class AuthLogEntry {
  AuthLogEntry(this.time, this.level, this.message);

  final DateTime time;
  final Level level;
  final String message;
}

/// Backs the registered [AuthTokenProvider] with a scripted, ordered list of
/// responses and exposes the observable token/log state the Auth tab renders.
///
/// Config is **transient** — it lives only in memory and resets on relaunch,
/// matching the native test apps which deliberately do not persist Auth state.
class AuthController extends ChangeNotifier {
  // Caps in-memory growth for long manual test sessions — clearLogs() only
  // moves a display cutoff, so without a cap this list would grow unbounded.
  static const int _maxLogEntries = 500;

  AuthController() {
    // Buffer the wrapper's bridge diagnostics for the Auth-logs section.
    _logSubscription = Logger('KlaviyoSDK').onRecord.listen((record) {
      _logs.add(AuthLogEntry(record.time, record.level, record.message));
      if (_logs.length > _maxLogEntries) {
        _logs.removeRange(0, _logs.length - _maxLogEntries);
      }
      notifyListeners();
    });
  }

  StreamSubscription<LogRecord>? _logSubscription;

  final List<AuthResponse> _responses = [AuthResponse()];
  final Set<String> _servedIds = {};
  final List<AuthLogEntry> _logs = [];

  bool _enabled = false;
  // Non-null while an enable()/disable() is in flight, holding the target
  // state. The UI reflects this (so the switch shows the intended position
  // instead of snapping back to the confirmed state) and disables the control
  // to block re-entrant toggles mid-transition.
  bool? _pendingEnable;
  int _generation = 0;
  String? _currentCallId;
  String? _lastReturnedToken;
  DateTime? _logCutoff;

  // ---- Read-only views for the UI ----------------------------------------

  List<AuthResponse> get responses => List.unmodifiable(_responses);

  /// The switch position: the in-flight target while transitioning, otherwise
  /// the confirmed state.
  bool get enabled => _pendingEnable ?? _enabled;

  /// Whether an enable/disable transition is in flight (control is disabled).
  bool get isTransitioning => _pendingEnable != null;
  String? get currentCallId => _currentCallId;
  String? get lastReturnedToken => _lastReturnedToken;

  /// Served state only applies while the provider is registered — when it's
  /// off, `_servedIds` has been cleared (see `enable`/`disable`) so no row is
  /// considered served (nothing locked/undeletable). Checking `_servedIds`
  /// directly, rather than gating on `_enabled`, matters because the native
  /// side can invoke `_provide` before `_enabled` flips true (registration is
  /// live as soon as the register call is issued, not once it resolves).
  bool isServed(String id) => _servedIds.contains(id);
  bool isRepeatingLast(int index) => index == _responses.length - 1;

  /// A row is locked (non-editable) once served, except the repeating last row.
  bool isLocked(int index) =>
      isServed(_responses[index].id) && !isRepeatingLast(index);

  /// [isLocked] keyed by id instead of index — for callers (like the Configure
  /// Response screen) that only have the response id, not its current index.
  bool isLockedById(String id) {
    final index = _responses.indexWhere((r) => r.id == id);
    return index >= 0 && isLocked(index);
  }

  /// A row can be deleted only if there's more than one and it hasn't served.
  bool canDelete(int index) =>
      _responses.length > 1 && !isServed(_responses[index].id);

  List<AuthLogEntry> get visibleLogs => _logCutoff == null
      ? List.unmodifiable(_logs)
      : _logs.where((e) => e.time.isAfter(_logCutoff!)).toList();

  // ---- Provider registration ---------------------------------------------

  /// Enable the provider: reset scripted state and register with the SDK.
  ///
  /// `_enabled` flips to true only after registration succeeds. If it throws
  /// (e.g. the SDK isn't initialized yet), the toggle stays off rather than
  /// showing ON with no provider registered, and the error is caught here so it
  /// doesn't surface as an unhandled future from the (non-awaited) UI handler.
  Future<void> enable() async {
    // Ignore re-entrant toggles while a transition is in flight (the UI also
    // disables the control, but guard here too). This prevents a second tap
    // from calling _resetServedState() and wiping the cursor/served rows while
    // registration is still running.
    if (_pendingEnable != null) return;
    _pendingEnable = true;
    notifyListeners();

    _resetServedState(); // bumps _generation
    // Capture this operation's generation so a stale in-flight completion can't
    // re-enable after a later toggle.
    final generation = _generation;
    try {
      await KlaviyoSDK().registerAuthTokenProvider(_provide);
      if (generation == _generation) _enabled = true;
    } catch (e) {
      if (generation == _generation) _enabled = false;
      Logger('KlaviyoSDK')
          .warning('Failed to register auth token provider: $e');
    } finally {
      // Only clear the pending flag if this op is still current; a superseding
      // op owns the transition state otherwise.
      if (generation == _generation) _pendingEnable = null;
      notifyListeners();
    }
  }

  /// Disable the provider: unregister and bump the generation so any in-flight
  /// delayed call is discarded.
  Future<void> disable() async {
    if (_pendingEnable != null) return;
    _pendingEnable = false;
    _generation++;
    notifyListeners();

    final generation = _generation;
    try {
      await KlaviyoSDK().unregisterAuthTokenProvider();
      // Mirror enable(): only report disabled once unregistration actually
      // succeeds, so a failure leaves the switch on and retryable instead of
      // claiming "disabled" while the SDK may still hold the old provider.
      if (generation == _generation) {
        _enabled = false;
        _clearServedTracking();
      }
    } catch (e) {
      Logger('KlaviyoSDK')
          .warning('Failed to unregister auth token provider: $e');
    } finally {
      if (generation == _generation) _pendingEnable = null;
      notifyListeners();
    }
  }

  void _resetServedState() {
    _generation++;
    _clearServedTracking();
  }

  void _clearServedTracking() {
    _servedIds.clear();
    _currentCallId = null;
    _lastReturnedToken = null;
  }

  /// The scripted [AuthTokenProvider] handed to the SDK.
  Future<String> _provide() async {
    final generation = _generation;

    // Consume the next not-yet-served response in current list order,
    // clamping to the last (which repeats). Recomputed by id on every call —
    // rather than advancing a positional cursor — so reordering or
    // duplicating rows can't desync the serve order from what's shown in the
    // UI (see AuthResponse's stable id doc comment).
    var index = _responses.indexWhere((r) => !_servedIds.contains(r.id));
    if (index < 0) index = _responses.length - 1;
    final response = _responses[index];

    _currentCallId = response.id;
    _servedIds.add(response.id);
    notifyListeners();

    if (response.delay > Duration.zero) {
      await Future<void>.delayed(response.delay);
    }

    // Generation guard: if (un)register happened during the delay, discard.
    if (generation != _generation) {
      throw StateError('Auth token request discarded (registration changed)');
    }

    switch (response.outcome) {
      case AuthOutcome.throwNetworkError:
        // SocketException is auto-classified as connectivity by the SDK bridge,
        // exercising the connectivity-driven refresh-retry path.
        throw const SocketException('Simulated network error');
      case AuthOutcome.throwOtherError:
        throw Exception('Simulated provider error');
      case AuthOutcome.customToken:
      case AuthOutcome.mockToken:
        final token = response.tokenForServing() ?? '';
        _lastReturnedToken = token;
        notifyListeners();
        return token;
    }
  }

  // ---- Response list editing ----------------------------------------------

  void addResponse() {
    _responses.add(AuthResponse());
    notifyListeners();
  }

  void duplicateResponse(String id) {
    final index = _responses.indexWhere((r) => r.id == id);
    if (index < 0) return;
    _responses.insert(index + 1, _responses[index].duplicate());
    notifyListeners();
  }

  void deleteResponse(String id) {
    final index = _responses.indexWhere((r) => r.id == id);
    if (index < 0 || !canDelete(index)) return;
    _responses.removeAt(index);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    // ReorderableListView reports newIndex past the end when moving down.
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _responses.removeAt(oldIndex);
    _responses.insert(newIndex, item);
    notifyListeners();
  }

  AuthResponse? responseById(String id) {
    final index = _responses.indexWhere((r) => r.id == id);
    return index < 0 ? null : _responses[index];
  }

  /// Called by the Configure Response screen after an edit is committed. The
  /// engine already mutates the response in place (shared reference); this just
  /// notifies listeners so the list re-renders.
  void commitEdits() => notifyListeners();

  void clearLogs() {
    _logCutoff = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    super.dispose();
  }
}

/// App-wide singleton, mirroring the app's `KlaviyoSDK()` singleton style so
/// the Auth tab and the Configure Response screen share one engine.
final AuthController authController = AuthController();
