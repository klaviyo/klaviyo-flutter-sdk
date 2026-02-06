import 'dart:async';

/// A broadcast [StreamController] that buffers events arriving before
/// any listener subscribes, then flushes them to the first subscriber.
class BufferedBroadcastStreamController<T> {
  final _buffer = <T>[];
  late final StreamController<T> _controller = StreamController<T>.broadcast(
    onListen: _flush,
  );

  Stream<T> get stream => _controller.stream;
  bool get hasListener => _controller.hasListener;

  void add(T event) {
    _controller.hasListener ? _controller.add(event) : _buffer.add(event);
  }

  void _flush() {
    _buffer.forEach(_controller.add);
    _buffer.clear();
  }

  void close() => _controller.close();
}
