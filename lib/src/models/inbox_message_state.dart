/// A local state an inbox message can be put into.
///
/// Read and archived are independent, so archiving a message leaves it read or
/// unread. Applying a state a message is already in changes nothing.
enum InboxMessageState {
  /// Mark the message read.
  read,

  /// Mark the message unread.
  unread,

  /// Archive the message.
  archived,

  /// Take the message out of the archive.
  unarchived;

  /// The value the native bridge expects for this state.
  String get wireValue => name;
}
