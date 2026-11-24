import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:klaviyo_flutter_sdk/klaviyo_flutter_sdk.dart';

import 'inbox_api.dart';

/// The inbox call a fetching change is waiting on.
enum _Fetch { refresh, nextPage, filters }

/// Drives the Inbox tab from the public Flutter SDK API: `fetchInboxPage`,
/// `fetchInboxUnreadCount`, `updateInboxMessageState` and `inboxChanged`.
///
/// It never reads the native store directly, and it never opens a deep link or
/// runs a message action: this is a validation screen, not a customer inbox.
class InboxController extends ChangeNotifier {
  InboxController({required InboxApi api}) : _api = api;

  static const int defaultPageSize = 5;

  /// The SDK clamps a page size to 1 through 100.
  static const int minPageSize = 1;
  static const int maxPageSize = 100;

  final InboxApi _api;
  StreamSubscription<void>? _changes;

  /// One entry per `fetchInboxPage` call, in the order fetched, so the screen
  /// can show where each page ends.
  List<List<InboxMessage>> _pages = const [];

  InboxReadFilter _readFilter = InboxReadFilter.all;
  InboxArchiveFilter _archiveFilter = InboxArchiveFilter.active;
  int _pageSize = defaultPageSize;
  String? _nextCursor;
  bool _hasLoaded = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  String? _stateNotice;
  int _unreadCount = 0;
  int _changeSignalCount = 0;
  DateTime? _lastChangeAt;

  /// Bumped by every fetch, so a fetch that finishes after a newer one started
  /// can be ignored.
  int _latestFetch = 0;
  int _latestStateRequest = 0;

  List<InboxMessage> get messages => _pages.expand((page) => page).toList();

  List<List<InboxMessage>> get pages => _pages;

  InboxReadFilter get readFilter => _readFilter;

  InboxArchiveFilter get archiveFilter => _archiveFilter;

  int get pageSize => _pageSize;

  bool get hasLoaded => _hasLoaded;

  bool get isLoading => _isLoading;

  bool get isRefreshing => _isRefreshing;

  String? get errorMessage => _errorMessage;

  String? get stateNotice => _stateNotice;

  int get unreadCount => _unreadCount;

  int get changeSignalCount => _changeSignalCount;

  DateTime? get lastChangeAt => _lastChangeAt;

  bool get hasNextPage => _nextCursor != null;

  int get pagesLoaded => _pages.length;

  bool get isEmpty => _pages.isEmpty || messages.isEmpty;

  /// Reads the first page and the unread count, then follows the SDK's change
  /// signal. Call once, when the tab opens.
  Future<void> start() async {
    _changes ??= _api.onInboxChanged().listen((_) {
      _changeSignalCount += 1;
      _lastChangeAt = DateTime.now();
      // The signal carries no data, so re-read what is on screen. A refresh
      // while one is running is skipped: the running one will see the change.
      if (!_isRefreshing) refresh();
    });
    await refresh();
  }

  /// Stops following the change signal. Call when the tab closes.
  Future<void> stop() async {
    await _changes?.cancel();
    _changes = null;
  }

  /// Reads the first page and the unread count again, for pull-to-refresh.
  ///
  /// [isRefreshing] holds until both a refresh and a next-page fetch have
  /// returned, so the spinner covers the whole read.
  Future<void> refresh() {
    _isRefreshing = true;
    _stateNotice = null;
    return Future.wait([
      _fetchFirstPage(),
      _fetchUnreadCount(),
    ]).whenComplete(() => _isRefreshing = false);
  }

  /// Fetches the first page, replacing every page on screen.
  Future<void> loadFirstPage() => _fetchFirstPage();

  /// Appends the next page, when there is one.
  Future<void> loadNextPage() async {
    final cursor = _nextCursor;
    if (cursor == null || _isLoading) return;
    await _fetchPage(cursor: cursor, replacing: false, kind: _Fetch.nextPage);
  }

  /// Changes what the pages are made of, then reads the first page again.
  ///
  /// A cursor only continues the query it came from, so the walk restarts from
  /// the first page rather than continuing with the new filters.
  Future<void> setReadFilter(InboxReadFilter filter) {
    if (filter == _readFilter) return Future<void>.value();
    _readFilter = filter;
    return _fetchFirstPage();
  }

  /// Changes what the pages are made of, then reads the first page again.
  Future<void> setArchiveFilter(InboxArchiveFilter filter) {
    if (filter == _archiveFilter) return Future<void>.value();
    _archiveFilter = filter;
    return _fetchFirstPage();
  }

  /// Changes the page size, then reads the first page again.
  Future<void> setPageSize(int size) {
    final clamped = size.clamp(minPageSize, maxPageSize);
    if (clamped == _pageSize) return Future<void>.value();
    _pageSize = clamped;
    return _fetchFirstPage();
  }

  /// Applies [state] to one message, then re-reads so the list shows what the
  /// SDK stored. A message the device does not have reports a notice instead.
  Future<void> setMessageState(String id, InboxMessageState state) async {
    final request = ++_latestStateRequest;
    String? notice;
    try {
      final existed = await _api.updateMessageState(id, state);
      if (!existed) {
        notice = 'Message $id is not on this device, so its state was not '
            'changed. Retention may have removed it.';
      }
    } catch (error) {
      notice = 'Failed: ${describe(error)}';
    }
    if (request != _latestStateRequest) return;
    _stateNotice = notice;
    notifyListeners();
    await Future.wait([_fetchFirstPage(), _fetchUnreadCount()]);
  }

  /// A failed state change is shown where successful ones are.
  Future<void> showStateNotice(String notice) async {
    _stateNotice = notice;
    notifyListeners();
  }

  Future<void> _fetchFirstPage() =>
      _fetchPage(cursor: null, replacing: true, kind: _Fetch.refresh);

  Future<void> _fetchPage({
    required String? cursor,
    required bool replacing,
    required _Fetch kind,
  }) async {
    final request = ++_latestFetch;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!_api.isInitialized()) {
        throw const KlaviyoNotInitializedException();
      }
      final page = await _api.fetchPage(
        pageSize: _pageSize,
        cursor: cursor,
        readFilter: _readFilter,
        archiveFilter: _archiveFilter,
      );
      if (request != _latestFetch) return;
      _pages = replacing ? [page.messages] : [..._pages, page.messages];
      _nextCursor = page.nextCursor;
      _hasLoaded = true;
    } catch (error) {
      if (request != _latestFetch) return;
      // Attempted, so the screen shows the failure rather than a spinner that
      // never ends. A later refresh can still succeed.
      _hasLoaded = true;
      _errorMessage = describe(error);
      // An invalid cursor cannot be retried: the walk has to start over.
      if (error is KlaviyoInboxException &&
          error.reason == KlaviyoInboxErrorReason.invalidCursor) {
        _nextCursor = null;
      }
    } finally {
      if (request == _latestFetch) {
        _isLoading = false;
        notifyListeners();
      }
    }

    // A refresh reads the count too; a next page or filter change does not
    // change it, but is cheap and keeps the badge honest.
    if (kind == _Fetch.nextPage || kind == _Fetch.filters) {
      await _fetchUnreadCount();
    }
  }

  Future<void> _fetchUnreadCount() async {
    try {
      if (!_api.isInitialized()) return;
      final count = await _api.fetchUnreadCount();
      if (count == _unreadCount) return;
      _unreadCount = count;
      notifyListeners();
    } on KlaviyoException {
      // The count is cosmetic next to the list, which already reports any
      // inbox failure, so a failed count is not surfaced separately.
    }
  }

  /// A short, portable description of an inbox failure.
  static String describe(Object error) {
    if (error is KlaviyoInboxException) {
      return '${error.reason.name}: ${error.message}';
    }
    if (error is KlaviyoException) return error.message;
    return error.toString();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }
}
