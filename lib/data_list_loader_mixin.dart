import 'dart:async';

import 'package:flutter/material.dart';

import 'package:infinite_scroll_list_view/reactive_value.dart';

class DataWrapper<T> {
  final List<T>? list;
  final Object? error;

  DataWrapper(this.list, this.error);
}

mixin DataListLoaderMixin<T> {
  final _endOfResultStream = ReactiveValue<bool>(false);
  final _loadingStream = ReactiveValue<bool>(false);
  final _dataStream = ReactiveValue<DataWrapper<T>?>(null);

  /// Emits `true` while a page is being fetched, `false` otherwise.
  Stream<bool> get loadingStream => _loadingStream.stream;

  /// Emits the current list state whenever items are added, removed, or updated.
  Stream<DataWrapper<T>?> get dataStream => _dataStream.stream;

  bool get isLoading => _loadingStream.valueOrNull ?? false;
  bool get isEndOfResults => _endOfResultStream.valueOrNull ?? false;

  int _pageIndex = 0;
  bool _disposed = false;

  Future<void> reload() => load(reload: true);

  /// Empties the list and resets pagination without triggering a new fetch.
  Future<void> clear() async {
    _pageIndex = 0;
    await _clear(forceSkipDelay: true);
    _addToEndOfResultStream(false);
    if (_dataStream.valueOrNull?.list?.isNotEmpty ?? false) {
      _dataStream.add(DataWrapper([], null));
    }
  }

  /// Atomically replaces the entire list with [items] without a reload animation.
  /// Marks end-of-results so the sentinel does not auto-trigger pagination.
  /// Call [load] or [reload] afterwards if you want to resume fetching.
  Future<void> replace(List<T> items) async {
    await _clear(forceSkipDelay: true);
    if (_disposed) return;
    _pageIndex = 0;
    for (int i = 0; i < items.length; i++) {
      if (_disposed) return;
      await _addItem(items[i], skipDelay: true);
    }
    _addToEndOfResultStream(true);
    addLastItem();
  }

  final List<Function()> queue = [];
  late StreamSubscription _sub;

  void initMixin() {
    _sub = _loadingStream.stream
        .where((event) => !event)
        .where((e) => queue.isNotEmpty)
        .listen((event) {
      var fn = queue.removeAt(0);
      fn.call();
    });
  }

  void disposeMixin() {
    _disposed = true;
    _sub.cancel();
    _endOfResultStream.close();
    _loadingStream.close();
    _dataStream.close();
    queue.clear();
  }

  Future<void> load({
    bool reload = false,
    bool ignoreIfLoading = false,
  }) async {
    var _loading = _loadingStream.value;

    if (_loading) {
      if (!ignoreIfLoading) {
        // Keep only the latest pending load — earlier queued calls are stale.
        queue.clear();
        queue.add(() => load(reload: reload));
      }
      return;
    } else {
      _addToLoadingStream(true);
    }

    if (reload) {
      _pageIndex = 0;
    }
    try {
      _addToEndOfResultStream(false);
      List<T>? response = await getLoader().call(_pageIndex);
      if (_disposed) return;
      final bool Function(List<T> page) _isEndOfPage = isEndOfPage
          ?? (pageSize != null
              ? (page) => page.length < pageSize!
              : (page) => page.isEmpty);
      bool _endOfResult = response == null || _isEndOfPage(response);

      _addToEndOfResultStream(_endOfResult);
      if (!_endOfResult) {
        _pageIndex++;
      }
      await _addItems(response ?? [], reload);
    } catch (error) {
      if (_disposed) return;
      // await _clear(forceSkipDelay: true);
      _addToEndOfResultStream(true);
      _dataStream.add(DataWrapper(dataList, error));
      return Future.error(error);
    } finally {
      _addToLoadingStream(false);
    }
  }

  Future<void> _addItems(List<T> l, bool reload) async {
    if (reload) {
      await _clear();
      if (_disposed) return;
    }

    if (listLength == dataLength + 1) {
      await callOnRemove(dataLength, skipDelay: true);
      if (_disposed) return;
    }
    if (l.isNotEmpty) {
      if (betweenItemRenderDelay == null) {
        for (final item in l) {
          if (_disposed) return;
          _addItemSync(item);
        }
      } else {
        for (int i = 0; i < l.length; i++) {
          await _addItem(l[i], skipDelay: i == 0);
          if (_disposed) return;
        }
      }
    } else {
      DataWrapper<T>? _data = _dataStream.valueOrNull;
      if (_data == null) {
        _dataStream.add(DataWrapper([], null));
      } else if (_data.error != null) {
        _dataStream.add(DataWrapper(_data.list ?? [], null));
      }
    }

    addLastItem();
  }

  @protected
  void addLastItem() {
    if (dataLength == listLength && dataLength > 0) {
      onAdd(dataLength, null);
    }
  }

  Future<void> _clear({bool forceSkipDelay = false}) async {
    var length = listLength;
    for (int i = length - 1; i >= 0; i--) {
      if (_disposed) return;
      await callOnRemove(i,
          skipDelay: forceSkipDelay || !animateRemovingItemsOnReload);
    }
  }

  @protected
  void removeAt(int index) {
    final list = [...dataList];
    list.removeAt(index);
    _dataStream.add(DataWrapper(list, null));
  }

  Future<void> _addItem(T item, {required bool skipDelay}) async {
    int Function(T a, T b)? _comparator = comparator();
    T Function(T current, T newVal) _pick = pick ?? (a, b) => b;
    var _list = dataList;
    if (_comparator == null || _list.isEmpty) {
      await callOnAdd(_list.length, item, skipDelay: skipDelay);
      return;
    }

    int length = _list.length;
    for (int index = 0; index < length; index++) {
      var currentItem = getItem(index);
      int compare = _comparator(item, currentItem);
      if (compare == 0) {
        await callOnUpdate(index, _pick(currentItem, item),
            skipDelay: skipDelay);
        return;
      } else if (compare > 0) {
        await callOnAdd(index, item, skipDelay: skipDelay);
        return;
      }
    }
    await callOnAdd(_list.length, item, skipDelay: skipDelay);
  }

  // Synchronous version of _addItem used by the batch fast-path.
  void _addItemSync(T item) {
    int Function(T a, T b)? _comparator = comparator();
    T Function(T current, T newVal) _pick = pick ?? (a, b) => b;
    var _list = dataList;
    if (_comparator == null || _list.isEmpty) {
      onAdd(_list.length, item);
      return;
    }
    for (int index = 0; index < _list.length; index++) {
      final currentItem = getItem(index);
      final compare = _comparator(item, currentItem);
      if (compare == 0) {
        onUpdate(index, _pick(currentItem, item));
        return;
      } else if (compare > 0) {
        onAdd(index, item);
        return;
      }
    }
    onAdd(_list.length, item);
  }

  void addAt(int index, T item) {
    var _list = dataList;
    _list = [
      ..._list.sublist(0, index),
      item,
      ..._list.sublist(index),
    ];
    _dataStream.add(DataWrapper(_list, null));
  }

  updateItem(int index, T newValue) {
    var list = dataList;
    list[index] = newValue;
    _dataStream.add(DataWrapper(list, null));
  }

  Future<void> removeItem(T item, [int? index]) async {
    var _list = dataList;
    int _index = index ?? _list.indexOf(item);

    if (_index != -1) {
      await callOnRemove(_index, skipDelay: true);

      if (dataLength == 0 && listLength == 1) {
        await callOnRemove(0, skipDelay: true);
      }
    }
  }

  Future<void> removeWhere(bool Function(T) filter) async {
    while (true) {
      final list = dataList;
      final index = list.indexWhere(filter);
      if (index != -1) {
        await removeItem(list[index], index);
      } else {
        break;
      }
    }
  }

  Future<void> update(T item) async {
    await _addItem(item, skipDelay: true);
  }

  Future<void> add(T item) async {
    await _addItem(item, skipDelay: true);
    addLastItem();
  }

  T getItem(int index) => dataList[index];

  int get dataLength => dataList.length;

  Future<List<T>?> Function(int index) getLoader();

  List<T> get dataList => _dataStream.valueOrNull?.list ?? [];

  /// Comparator used for sorting and deduplication.
  ///
  /// Return a positive value if [a] should appear **before** [b] (descending
  /// order), zero if they are considered equal (triggers an update instead of
  /// an insert), and a negative value if [a] should appear after [b].
  int Function(T a, T b)? comparator();

  T Function(T currentValue, T newValue)? pick;

  void onRemove(int index);
  void onAdd(int index, T? item);
  void onUpdate(int index, T item);

  Future<void> callOnAdd(int index, T item, {required bool skipDelay}) async {
    Duration? delay = betweenItemRenderDelay;
    if (delay != null && !skipDelay && isListReady) {
      await Future.delayed(delay, () => onAdd(index, item));
    } else {
      onAdd(index, item);
    }
  }

  Future<void> callOnUpdate(int index, T item,
      {required bool skipDelay}) async {
    Duration? delay = betweenItemRenderDelay;
    if (delay != null && !skipDelay && isListReady) {
      await Future.delayed(delay, () => onUpdate(index, item));
    } else {
      onUpdate(index, item);
    }
  }

  Future<void> callOnRemove(int index, {required bool skipDelay}) async {
    Duration? delay = betweenItemRenderDelay;
    if (delay != null && !skipDelay && isListReady) {
      await Future.delayed(delay, () => onRemove(index));
    } else {
      onRemove(index);
    }
  }

  int getIndexOf(T item) {
    final cmp = comparator() ?? (T a, T b) => a == b ? 0 : -1;
    for (var i = 0; i < dataLength; i++) {
      if (cmp(item, getItem(i)) == 0) {
        return i;
      }
    }
    return -1;
  }

  Duration? get betweenItemRenderDelay => const Duration(milliseconds: 50);

  Widget get lastElement => StreamBuilder<bool>(
        stream: _endOfResultStream.stream,
        initialData: _endOfResultStream.valueOrNull,
        builder: (context, AsyncSnapshot<bool> snapshot) {
          bool? endOfResult = snapshot.data;

          if (endOfResult != null) {
            if (endOfResult) {
              var data = _dataStream.valueOrNull;

              if (data?.error != null) {
                return getElementError(context, data!.error);
              }

              return getEndOfResultWidget();
            } else {
              load(ignoreIfLoading: true);
              return getItemLoadingWidget();
            }
          }
          return const SizedBox.shrink();
        },
      );

  Widget getItemLoadingWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [CircularProgressIndicator()],
    );
  }

  Widget getEndOfResultWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(
          Icons.fiber_manual_record,
          color: Colors.grey,
        )
      ],
    );
  }

  Widget getElementError(BuildContext context, dynamic error) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.red),
          onPressed: load,
        )
      ],
    );
  }

  void _addToEndOfResultStream(bool value) {
    if (!_endOfResultStream.isClosed &&
        _endOfResultStream.valueOrNull != value) {
      _endOfResultStream.add(value);
    }
  }

  void _addToLoadingStream(bool value) {
    if (!_loadingStream.isClosed && _loadingStream.valueOrNull != value) {
      _loadingStream.add(value);
    }
  }

  bool get isListReady;

  int get listLength;

  bool get animateRemovingItemsOnReload => false;

  int? get pageSize => null;

  bool Function(List<T> page)? get isEndOfPage => null;
}
