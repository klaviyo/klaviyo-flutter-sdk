import 'dart:async';

/// A broadcast [StreamController] that buffers events arriving while no
/// listener is subscribed, then flushes them to the next subscriber once.
///
/// Events for which [holdKey] returns a non-null key take one buffer slot per
/// key: a newer event with the same key replaces the buffered one. All other
/// events are buffered in arrival order.
class BufferedBroadcastStreamController<T> {
  BufferedBroadcastStreamController({Object? Function(T event)? holdKey})
      : _holdKey = holdKey;

  final Object? Function(T event)? _holdKey;
  final _buffer = <T>[];
  late final StreamController<T> _controller = StreamController<T>.broadcast(
    onListen: _flush,
  );

  Stream<T> get stream => _controller.stream;
  bool get hasListener => _controller.hasListener;

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

  void close() {
    _buffer.clear();
    _controller.close();
  }
}
