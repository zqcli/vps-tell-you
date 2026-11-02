import 'package:flutter/foundation.dart';

enum ServerFilter { all, favorites, pending }

enum DueFilter { all, overdue, next30, unknown }

enum ServerSort { favorites, due, name, updated }

/// List controls are local presentation state, independent of ledger changes.
class ServerListState extends ChangeNotifier {
  String _search = '';
  ServerFilter _filter = ServerFilter.all;
  DueFilter _dueFilter = DueFilter.all;
  ServerSort _sort = ServerSort.favorites;
  String? _groupFilter;

  String get search => _search;
  ServerFilter get filter => _filter;
  DueFilter get dueFilter => _dueFilter;
  ServerSort get sort => _sort;

  /// null = all groups; empty string = ungrouped.
  String? get groupFilter => _groupFilter;

  void updateFilters({
    String? query,
    ServerFilter? category,
    DueFilter? due,
    ServerSort? order,
  }) {
    final previous = (_search, _filter, _dueFilter, _sort);
    _search = query ?? _search;
    _filter = category ?? _filter;
    _dueFilter = due ?? _dueFilter;
    _sort = order ?? _sort;
    if (previous != (_search, _filter, _dueFilter, _sort)) notifyListeners();
  }

  void setGroup(String? id) {
    if (_groupFilter == id) return;
    _groupFilter = id;
    notifyListeners();
  }

  void resetFilters() {
    if (_search.isEmpty &&
        _filter == ServerFilter.all &&
        _dueFilter == DueFilter.all &&
        _groupFilter == null) {
      return;
    }
    _search = '';
    _filter = ServerFilter.all;
    _dueFilter = DueFilter.all;
    _groupFilter = null;
    notifyListeners();
  }
}
