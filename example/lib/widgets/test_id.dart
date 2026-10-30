import 'package:flutter/widgets.dart';

/// Tags [child] with a stable test ID so UI automation can find it.
///
/// The ID is exposed two ways:
/// - as the semantics `identifier`, which surfaces as the Android
///   `resource-id` and the iOS `accessibilityIdentifier` for native drivers
///   (Maestro `id:`, Appium, simulator/emulator agents);
/// - as a [ValueKey] for `find.byKey` in widget and integration tests.
///
/// IDs are snake_case `<screen>_<element>_<type>` (e.g.
/// `push_request_permission_button`) and kept in step with the other Klaviyo
/// example apps.
///
/// By default the child's semantics are merged into one node so the ID lands
/// on the actionable element itself. Pass `merge: false` when the child holds
/// separately actionable descendants (e.g. a text field with a suffix button).
class TestId extends StatelessWidget {
  TestId(this.id, {required this.child, this.merge = true})
      : super(key: ValueKey<String>(id));

  final String id;
  final Widget child;
  final bool merge;

  @override
  Widget build(BuildContext context) {
    final tagged = Semantics(identifier: id, child: child);
    return merge ? MergeSemantics(child: tagged) : tagged;
  }
}
