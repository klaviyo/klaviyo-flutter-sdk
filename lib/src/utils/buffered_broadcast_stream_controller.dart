import 'dart:async';

/// A broadcast [StreamController] that buffers events arriving before
/// any listener subscribes, then flushes them to the first subscriber.
class BufferedBroadcastStreamController<T> {
  /// Creates a controller.
  ///
  /// When [coalesce] is true, at most one event is held while nothing is
  /// listening: further adds are dropped until a listener flushes the buffer.
  /// Use it for payload-free "something changed, re-read it" signals, where a
  /// burst collapses into one notification with no loss of meaning.
  BufferedBroadcastStreamController({this.coalesce = false});

  /// Whether a burst of buffered events collapses into a single delivered one.
  final bool coalesce;

  final _buffer = <T>[];
  late final StreamController<T> _controller = StreamController<T>.broadcast(
    onListen: _flush,
  );

  Stream<T> get stream => _controller.stream;
  bool get hasListener => _controller.hasListener;

  void add(T event) {
    if (_controller.hasListener) {
      _controller.add(event);
    } else if (!coalesce || _buffer.isEmpty) {
      _buffer.add(event);
    }
  }

  void _flush() {
    _buffer.forEach(_controller.add);
    _buffer.clear();
  }

  void close() => _controller.close();
}
