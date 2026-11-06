import 'dart:async';

/// A broadcast [StreamController] that keeps events arriving while no
/// listener is subscribed.
///
/// Events for which [holdKey] returns a non-null key are held in one slot per
/// key. A held event is replayed to every subscriber when it subscribes, and
/// stays held until another event with the same key arrives. That newer event
/// replaces the held one if no listener is subscribed or it is added with
/// `hold: true`, and otherwise clears the slot when it is delivered live.
///
/// All other events are queued and flushed to the first subscriber, then
/// cleared.
class BufferedBroadcastStreamController<T> {
  BufferedBroadcastStreamController({Object? Function(T event)? holdKey})
      : _holdKey = holdKey;

  final Object? Function(T event)? _holdKey;
  final _buffer = <T>[];
  final _held = <Object, T>{};
  late final StreamController<T> _controller = StreamController<T>.broadcast(
    onListen: _flush,
  );

  late final Stream<T> stream =
      Stream<T>.multi(_onSubscribe, isBroadcast: true);

  bool get hasListener => _controller.hasListener;

  /// Adds [event]. With [hold], an event that has a hold key is delivered to
  /// current listeners and also held for later subscribers.
  void add(T event, {bool hold = false}) {
    final key = _holdKey?.call(event);
    if (key != null) {
      _held.remove(key);
      if (hold || !_controller.hasListener) {
        _held[key] = event;
      }
      if (!_controller.hasListener) return;
    }
    _controller.hasListener ? _controller.add(event) : _buffer.add(event);
  }

  /// Drops every held event.
  void clearHeld() => _held.clear();

  void _onSubscribe(MultiStreamController<T> subscriber) {
    final replay = _held.values.toList();
    final subscription = _controller.stream.listen(
      subscriber.addSync,
      onError: subscriber.addErrorSync,
      onDone: subscriber.closeSync,
    );
    subscriber
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = subscription.cancel;
    replay.forEach(subscriber.add);
  }

  void _flush() {
    _buffer.forEach(_controller.add);
    _buffer.clear();
  }

  void close() {
    _buffer.clear();
    _held.clear();
    _controller.close();
  }
}
