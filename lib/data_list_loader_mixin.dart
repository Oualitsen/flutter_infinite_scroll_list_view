import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class DataWrapper<T> {
  final List<T>? list;
  final Object? error;

  DataWrapper(this.list, this.error);
}

mixin DataListLoaderMixin<T> {
  final BehaviorSubject<bool> endOfResultStream = BehaviorSubject.seeded(false);
  final BehaviorSubject<bool> loadingStream = BehaviorSubject.seeded(false);
  final BehaviorSubject<Object?> errorStream = BehaviorSubject();
  final BehaviorSubject<DataWrapper<T>?> dataSubject = BehaviorSubject();

  int _pageIndex = 0;

  Future<void> reload({int callId: 0}) => load(reload: true, callId: callId);

  final List<Function()> queue = [];
  late StreamSubscription _sub;

  void initMixin() {
    _sub = loadingStream.where((event) => !event).where((e) => queue.isNotEmpty).listen((event) {
      var fn = queue.removeAt(0);
      fn.call();
    });
  }

  void disposeMixin() {
    _sub.cancel();
    endOfResultStream.close();
    loadingStream.close();
    dataSubject.close();
    queue.clear();
    errorStream.close();
  }

  Future<void> load({
    bool reload = false,
    int callId: 0,
    bool ignoreIfLoading: false,
  }) async {
    var _loading = loadingStream.value;

    if (_loading) {
      if (!ignoreIfLoading) {
        queue.add(() => load(reload: reload, callId: callId));
      }
      return;
    } else {
      loadingStream.add(true);
    }

    if (reload) {
      _pageIndex = 0;
    }
    try {
      List<T>? response = await getLoader().call(_pageIndex);
      bool _endOfResult = response?.isEmpty ?? true;
      endOfResultStream.add(_endOfResult);
      if (!_endOfResult) {
        _pageIndex++;
      }
      if (response != null) {
        await _addItems(response, reload);
      }
    } catch (error) {
      /**
       * Clear first
       */
      await _clear(forceSkipDelay: true);

      dataSubject.add(DataWrapper(null, error));
      return Future.error(error);
    } finally {
      if (!loadingStream.isClosed) {
        loadingStream.add(false);
      }
    }
  }

  Future<void> _addItems(List<T> l, bool reload) async {
    /**
     * add the items to the correct index
     */

    if (reload) {
      await _clear();
    }

    if (listLength == dataLength + 1) {
      await callOnRemove(dataLength, skipDelay: true);
    }
    if (l.isNotEmpty) {
      for (int i = 0; i < l.length; i++) {
        await _addItem(l[i], skipDelay: i == 0);
      }
    } else {
      dataSubject.add(DataWrapper([], null));
    }

    /**
     * add a last element here!
     */
    if (dataLength == listLength && dataLength > 0) {
      onAdd(dataLength, null);
    }
  }

  Future<void> _clear({bool forceSkipDelay: false}) async {
    var length = listLength;
    for (int i = length - 1; i >= 0; i--) {
      await callOnRemove(i, skipDelay: forceSkipDelay || !animateRemovingItemsOnReload);
    }
  }

  Future<void> _addItem(T item, {required bool skipDelay}) async {
    int Function(T a, T b)? _comparator = comparator();
    var _list = dataList;
    if (_comparator == null || _list.isEmpty) {
      await callOnAdd(_list.length - 1, item, skipDelay: skipDelay);
      return;
    }
    /**
       * List is not empty and the comparator is not null
     */

    int length = _list.length;
    for (int index = 0; index < length; index++) {
      var currentItem = getItem(index);
      int compare = _comparator(item, currentItem);
      if (compare == 0) {
        await callOnUpdate(index, item, skipDelay: skipDelay);
        return;
      } else if (compare > 0) {
        await callOnAdd(index, item, skipDelay: skipDelay);
        return;
      }
    }

    await callOnAdd(_list.length - 1, item, skipDelay: skipDelay);
  }

  int addAt(int index, T item) {
    var _list = dataList;
    int result = index;
    if (index == _list.length - 1) {
      _list.add(item);
      result = _list.length - 1;
    } else {
      List<T> newList = [];

      for (int i = 0; i < _list.length; i++) {
        if (i == index) {
          newList.add(item);
        }
        newList.add(_list[i]);
      }
      _list = newList;
    }
    dataSubject.add(DataWrapper(_list, null));
    return result;
  }

  updateItem(int index, T newValue) {
    var list = dataList;
    list[index] = newValue;
    dataSubject.add(DataWrapper(list, null));
  }

  Future<void> removeItem(T item) async {
    var _list = dataList;
    int index = _list.indexOf(item);
    if (index != -1) {
      _list.removeAt(index);
      await callOnRemove(index, skipDelay: true);
      dataSubject.add(DataWrapper(_list, null));
    }
  }

  Future<void> removeItemAt(int index) async {
    await callOnRemove(index, skipDelay: true);
  }

  Future<void> removeWere(bool Function(T) filter) async {
    var _list = dataList;
    List<T> list = _list.where(filter).toList();
    list.forEach((item) async => await removeItem(item));
  }

  void removeAt(int index) {
    var list = dataList;
    list.removeAt(index);
    dataSubject.add(DataWrapper(list, null));
  }

  Future<void> update(T item) async {
    await _addItem(item, skipDelay: true);
  }

  Future<void> add(T item) async {
    await _addItem(item, skipDelay: true);
  }

  T getItem(int index) => dataList[index];

  int get dataLength => dataList.length;

  Future<List<T>?> Function(int index) getLoader();

  List<T> get dataList => dataSubject.valueOrNull?.list ?? [];

  int Function(T a, T b)? comparator();

  void onRemove(int index);
  void onAdd(int index, T? item);
  void onUpdate(int index, T item);

  Future<void> callOnAdd(int index, T item, {required bool skipDelay}) async {
    /**
     * Wait till the data is initialized first!.
     */

    Duration? delay = betweenItemRenderDelay;
    if (delay != null && !skipDelay && isListReady) {
      await Future.delayed(delay, () => onAdd(index, item));
    } else {
      onAdd(index, item);
    }
  }

  Future<void> callOnUpdate(int index, T item, {required bool skipDelay}) async {
    /**
     * Wait till the data is initialized first!.
     */

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
    int Function(T a, T b)? _comparator = comparator();
    if (_comparator == null) {
      return -1;
    }
    for (var i = 0; i < dataLength; i++) {
      var b = getItem(i);
      if (_comparator(item, b) == 0) {
        return i;
      }
    }
    return -1;
  }

  Duration? get betweenItemRenderDelay => Duration(milliseconds: 50);

  Widget get lastElement => StreamBuilder<bool>(
        builder: (context, AsyncSnapshot<bool> snapshot) {
          bool? endOfResult = snapshot.data;

          if (endOfResult != null) {
            if (endOfResult) {
              return getEndOfResultWidget();
            } else {
              load(ignoreIfLoading: true);
              return getItemLoadingWidget();
            }
          }
          return SizedBox.shrink();
        },
        stream: endOfResultStream,
        initialData: endOfResultStream.valueOrNull,
      );

  Widget getItemLoadingWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [CircularProgressIndicator()],
    );
  }

  Widget getEndOfResultWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.fiber_manual_record,
          color: Colors.grey,
        )
      ],
    );
  }

  bool get isListReady;

  int get listLength;

  bool get animateRemovingItemsOnReload => false;
}