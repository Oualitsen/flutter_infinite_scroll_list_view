import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infinite_scroll_list_view/data_list_loader_mixin.dart';

class InfiniteScrollListView<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T element, int index,
      Animation<double> animation) elementBuilder;
  final Future<List<T>?> Function(int index) pageLoader;

  /// See [DataListLoaderMixin.comparator] for the sort-order convention
  /// (positive return value = [a] before [b], i.e. descending order).
  final int Function(T a, T b)? comparator;
  final T Function(T current, T newValue)? pick;

  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool? primary;
  final bool reverse;
  final bool shrinkWrap;
  final Widget? noDataWidget;
  final Widget? loadingWidget;
  final Widget? itemLoadingWidget;
  final Widget? endOfResultWidget;
  final Duration? betweenItemRenderDelay;
  final Widget Function(BuildContext context, T item, Animation<double> animation)? removeAnimationBuilder;
  final bool animateRemovingItemsOnReload;
  final Widget Function(BuildContext context, int index)? separatorBuilder;
  final int? pageSize;
  final bool Function(List<T> page)? isEndOfPage;
  final List<T>? initialItems;
  final void Function()? onReload;
  final void Function(int page)? onLoadMore;
  final Widget Function(BuildContext context, dynamic error)? errorBuilder;
  final Widget Function(BuildContext context, dynamic error)?
      elementErrorBuilder;
  final bool refreshable;
  final Clip clipBehavior;

  InfiniteScrollListView(
      {Key? key,
      required this.elementBuilder,
      required this.pageLoader,
      this.comparator,
      this.physics,
      this.scrollDirection = Axis.vertical,
      this.padding,
      this.controller,
      this.primary,
      this.reverse = false,
      this.shrinkWrap = false,
      this.noDataWidget,
      this.loadingWidget,
      this.endOfResultWidget,
      this.itemLoadingWidget,
      this.errorBuilder,
      this.elementErrorBuilder,
      this.betweenItemRenderDelay,
      this.removeAnimationBuilder,
      this.separatorBuilder,
      this.animateRemovingItemsOnReload = false,
      this.pageSize,
      this.isEndOfPage,
      this.initialItems,
      this.onReload,
      this.onLoadMore,
      this.refreshable = true,
      this.clipBehavior = Clip.hardEdge,
      this.pick})
      : super(key: key);

  InfiniteScrollListView.horizontal({
    Key? key,
    required Widget Function(BuildContext context, T element, int index,
            Animation<double> animation)
        elementBuilder,
    required Future<List<T>?> Function(int index) pageLoader,
    int Function(T a, T b)? comparator,
    T Function(T current, T newValue)? pick,
    ScrollPhysics? physics,
    EdgeInsetsGeometry? padding,
    ScrollController? controller,
    bool? primary,
    bool reverse = false,
    bool shrinkWrap = false,
    Widget? noDataWidget,
    Widget? loadingWidget,
    Widget? itemLoadingWidget,
    Widget? endOfResultWidget,
    Duration? betweenItemRenderDelay,
    Widget Function(BuildContext context, T item, Animation<double> animation)? removeAnimationBuilder,
    Widget Function(BuildContext context, int index)? separatorBuilder,
    bool animateRemovingItemsOnReload = false,
    int? pageSize,
    bool Function(List<T> page)? isEndOfPage,
    List<T>? initialItems,
    void Function()? onReload,
    void Function(int page)? onLoadMore,
    bool refreshable = true,
    Clip clipBehavior = Clip.hardEdge,
    Widget Function(BuildContext context, dynamic error)? errorBuilder,
    Widget Function(BuildContext context, dynamic error)? elementErrorBuilder,
  }) : this(
          key: key,
          elementBuilder: elementBuilder,
          pageLoader: pageLoader,
          comparator: comparator,
          pick: pick,
          physics: physics,
          scrollDirection: Axis.horizontal,
          padding: padding,
          controller: controller,
          primary: primary,
          reverse: reverse,
          shrinkWrap: shrinkWrap,
          noDataWidget: noDataWidget,
          loadingWidget: loadingWidget,
          itemLoadingWidget: itemLoadingWidget,
          endOfResultWidget: endOfResultWidget,
          betweenItemRenderDelay: betweenItemRenderDelay,
          removeAnimationBuilder: removeAnimationBuilder,
          separatorBuilder: separatorBuilder,
          animateRemovingItemsOnReload: animateRemovingItemsOnReload,
          pageSize: pageSize,
          isEndOfPage: isEndOfPage,
          initialItems: initialItems,
          onReload: onReload,
          onLoadMore: onLoadMore,
          refreshable: refreshable,
          clipBehavior: clipBehavior,
          errorBuilder: errorBuilder,
          elementErrorBuilder: elementErrorBuilder,
        );

  @override
  InfiniteScrollListViewState<T> createState() =>
      InfiniteScrollListViewState<T>();
}

class InfiniteScrollListViewState<T> extends State<InfiniteScrollListView<T>>
    with DataListLoaderMixin<T> {
  final GlobalKey<AnimatedListState> key = GlobalKey<AnimatedListState>();

  int _listLength = 0;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    initMixin();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final initial = widget.initialItems;
      if (initial != null && initial.isNotEmpty) {
        await replace(initial);
      } else {
        await load();
      }
    });
  }

  @override
  void dispose() {
    disposeMixin();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DataWrapper<T>?>(
        stream: dataStream,
        builder: (context, snapshot) {
          Widget list = AnimatedList(
              clipBehavior: widget.clipBehavior,
              initialItemCount: 0,
              key: key,
              physics: widget.physics,
              scrollDirection: widget.scrollDirection,
              padding: widget.padding,
              controller: widget.controller,
              primary: widget.primary,
              reverse: widget.reverse,
              shrinkWrap: widget.shrinkWrap,
              itemBuilder: (BuildContext context, int index,
                  Animation<double> animation) {
                if (index == dataLength) {
                  return lastElement;
                }
                final item = widget.elementBuilder(
                  context,
                  getItem(index),
                  index,
                  animation,
                );
                final sep = widget.separatorBuilder;
                if (sep != null && index < dataLength - 1) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [item, sep(context, index)],
                  );
                }
                return item;
              });

          if (widget.refreshable) {
            list = RefreshIndicator(
              onRefresh: () => load(reload: true),
              child: list,
            );
          }

          final data = snapshot.data;
          Widget? overlay;
          if (data == null) {
            overlay = loadingWidget;
          } else if (data.error != null && dataLength == 0) {
            overlay = getError(context, data.error);
          } else if (data.list?.isEmpty ?? true) {
            overlay = StreamBuilder<bool>(
              stream: loadingStream,
              builder: (context, snapshot) {
                if (snapshot.data == true) return loadingWidget;
                return noDataWidget;
              },
            );
          }

          if (overlay != null) {
            return Stack(children: [
              Offstage(offstage: true, child: list),
              Positioned.fill(child: overlay),
            ]);
          }
          return list;
        });
  }

  @override
  Future<List<T>?> Function(int index) getLoader() {
    return (index) {
      if (!_initialLoadDone) {
        _initialLoadDone = true;
      } else if (index == 0) {
        widget.onReload?.call();
      } else {
        widget.onLoadMore?.call(index);
      }
      return widget.pageLoader(index);
    };
  }

  @override
  void onAdd(int index, T? item) {
    var state = key.currentState;
    if (state == null) {
      return;
    }
    if (item == null) {
      state.insertItem(index);
    } else {
      addAt(index, item);
      state.insertItem(index);
    }
    _listLength++;
  }

  @override
  void onRemove(int index) {
    var state = key.currentState;
    if (state != null) {
      // Capture the item before removeAt erases it from the data model.
      final removedItem = index < dataLength ? getItem(index) : null;
      state.removeItem(
        index,
        (context, animation) {
          final builder = widget.removeAnimationBuilder;
          if (builder != null && removedItem != null) {
            return builder(context, removedItem, animation);
          }
          return const SizedBox.shrink();
        },
      );

      if (index < dataLength) {
        removeAt(index);
      }
      _listLength--;
    }
  }

  @override
  void onUpdate(int index, T item) {
    var state = key.currentState;
    if (state != null) {
      final oldItem = getItem(index);
      updateItem(index, item);

      state.removeItem(
        index,
        (context, animation) {
          final builder = widget.removeAnimationBuilder;
          if (builder != null) return builder(context, oldItem, animation);
          return const SizedBox.shrink();
        },
      );
      state.insertItem(index);
    }
  }

  @override
  int Function(T a, T b)? comparator() => widget.comparator;

  @override
  T Function(T currentValue, T newValue)? get pick => widget.pick;

  Widget get noDataWidget =>
      widget.noDataWidget ??
      const Center(
        child: Text(
          "No data",
          style: TextStyle(color: Colors.red),
        ),
      );

  Widget get loadingWidget =>
      widget.loadingWidget ?? const Center(child: CircularProgressIndicator());

  @override
  Widget getEndOfResultWidget() {
    return widget.endOfResultWidget ?? super.getEndOfResultWidget();
  }

  @override
  Widget getItemLoadingWidget() {
    return widget.itemLoadingWidget ?? super.getItemLoadingWidget();
  }

  Widget getError(BuildContext context, dynamic error) {
    if (widget.errorBuilder != null) {
      return widget.errorBuilder!(context, error);
    } else {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 100),
              Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                "Could not load data",
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            ]),
      );
    }
  }

  @override
  Widget getElementError(BuildContext context, error) {
    if (widget.elementErrorBuilder != null) {
      return widget.elementErrorBuilder!(context, error);
    }
    return super.getElementError(context, error);
  }

  @override
  int get listLength => _listLength;

  @override
  Duration? get betweenItemRenderDelay => widget.betweenItemRenderDelay;

  @override
  bool get isListReady => key.currentState != null;

  @override
  bool get animateRemovingItemsOnReload => widget.animateRemovingItemsOnReload;

  @override
  int? get pageSize => widget.pageSize;

  @override
  bool Function(List<T> page)? get isEndOfPage => widget.isEndOfPage;

  // Convenience re-exports for callers using a GlobalKey on this state.
  @override
  bool get isLoading => super.isLoading;

  @override
  bool get isEndOfResults => super.isEndOfResults;

  @override
  Future<void> clear() => super.clear();

  @override
  Future<void> replace(List<T> items) => super.replace(items);
}
