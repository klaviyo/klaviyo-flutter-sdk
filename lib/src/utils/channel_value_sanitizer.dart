import 'dart:typed_data';

import 'package:logging/logging.dart';

final Logger _logger = Logger('KlaviyoSDK');

/// Returns a copy of [properties] that the platform channel's
/// `StandardMessageCodec` can encode.
///
/// [DateTime] values become UTC ISO 8601 strings, through nested maps and
/// lists. `null`, [bool], [num], [String], [Uint8List], [Int32List],
/// [Int64List], [Float32List], [Float64List], [List] and [Map] with [String]
/// keys are kept. Any other value, and any nested map with a non-[String]
/// key, is dropped and logged as a warning that names its path. [source]
/// names the calling API in the warning.
Map<String, dynamic> sanitizeChannelProperties(
  Map<String, dynamic> properties, {
  required String source,
}) {
  final result = <String, dynamic>{};
  properties.forEach((key, value) {
    final sanitized = _sanitize(value, key, source);
    if (!identical(sanitized, _dropped)) result[key] = sanitized;
  });
  return result;
}

const Object _dropped = Object();

Object? _sanitize(Object? value, String path, String source) {
  if (value == null ||
      value is bool ||
      value is num ||
      value is String ||
      value is Uint8List ||
      value is Int32List ||
      value is Int64List ||
      value is Float32List ||
      value is Float64List) {
    return value;
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is List) {
    final result = <Object?>[];
    for (var i = 0; i < value.length; i++) {
      final item = _sanitize(value[i], '$path[$i]', source);
      if (!identical(item, _dropped)) result.add(item);
    }
    return result;
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        _warn(source, '$path[$key]', key);
        continue;
      }
      final item = _sanitize(entry.value, '$path.$key', source);
      if (!identical(item, _dropped)) result[key] = item;
    }
    return result;
  }
  _warn(source, path, value);
  return _dropped;
}

void _warn(String source, String path, Object? value) {
  _logger.warning(
    "$source: dropping '$path' because ${value.runtimeType} values "
    "can't be sent to the native SDK",
  );
}
