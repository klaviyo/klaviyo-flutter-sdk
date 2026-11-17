import 'dart:async';

/// A broadcast [StreamController] that buffers events arriving while no
/// listener is subscribed, then flushes them to the next subscriber once.
///
/// Events for which [holdKey] returns a non-null key take one buffer slot per
/// key: a newer event with the same key replaces the buffered one. All other
/// events are buffered in arrival order.
class BufferedBroadcastStreamController<T> {
  /// Creates a controller. See the class docs for [holdKey].
  BufferedBroadcastStreamController({Object? Function(T event)? holdKey})
      : _holdKey = holdKey;

  final Object? Function(T event)? _holdKey;
  final _buffer = <T>[];
  late final StreamController<T> _controller = StreamController<T>.broadcast(
    onListen: _flush,
  );

  /// The broadcast stream of events.
  Stream<T> get stream => _controller.stream;

  /// Whether the stream has a listener.
  bool get hasListener => _controller.hasListener;

  /// Delivers [event] to listeners, or buffers it if there are none.
  void add(T event) {
    if (_controller.hasListener) {
      _controller.add(event);
      return;
    }
    final key = _holdKey?.call(event);
    if (key != null) {
      _buffer.removeWhere((buffered) => _holdKey?.call(buffered) == key);
    }
    _buffer.add(event);
  }

  /// Drops every buffered event that has a hold key.
  void clearHeld() {
    final holdKey = _holdKey;
    if (holdKey == null) return;
    _buffer.removeWhere((buffered) => holdKey(buffered) != null);
  }

  void _flush() {
    _buffer.forEach(_controller.add);
    _buffer.clear();
  }

  /// Drops the buffer and closes the stream.
  void close() {
    _buffer.clear();
    _controller.close();
  }
}
