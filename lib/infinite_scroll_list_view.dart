import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infinite_scroll_list_view/data_list_loader_mixin.dart';

class InfiniteScrollListView<T> extends StatefulWidget {
  final Widget Function(BuildContext context, T element, int index,
      Animation<double> animation) elementBuilder;
  final Future<List<T>?> Function(int index) pageLoader;

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
  final Widget? onRemoveAnimation;
  final bool animateRemovingItemsOnReload;
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
      this.onRemoveAnimation,
      this.animateRemovingItemsOnReload = false,
      this.refreshable = true,
      this.clipBehavior = Clip.hardEdge,
      this.pick})
      : super(key: key);

  @override
  InfiniteScrollListViewState<T> createState() =>
      InfiniteScrollListViewState<T>();
}

class InfiniteScrollListViewState<T> extends State<InfiniteScrollListView<T>>
    with DataListLoaderMixin<T> {
  final GlobalKey<AnimatedListState> key = GlobalKey<AnimatedListState>();

  int _listLength = 0;

  @override
  void initState() {
    super.initState();
    initMixin();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      load();
    });
  }

  @override
  void dispose() {
    super.dispose();
    var state = key.currentState;
    if (state != null) {
      state.dispose();
    }
    disposeMixin();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DataWrapper<T>?>(
        stream: dataSubject,
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
                return widget.elementBuilder(
                  context,
                  getItem(index),
                  index,
                  animation,
                );
              });

          var children = <Widget>[];

          var data = snapshot.data;
          if (data == null) {
            children.add(loadingWidget);
          } else {
            if (data.error != null && dataLength == 0) {
              children.add(getError(context, data.error));
            } else if (data.list?.isEmpty ?? true) {
              children.add(
                StreamBuilder<bool>(
                    stream: loadingStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        if (snapshot.data!) {
                          return loadingWidget;
                        } else {
                          return noDataWidget;
                        }
                      }
                      return SizedBox.shrink();
                    }),
              );
            }
          }

          /**
           * @Todo find a way to make it refreshable!
           */

          if (widget.refreshable) {
            list = RefreshIndicator(
              onRefresh: () => load(reload: true),
              child: list,
            );
          }
          children.add(list);
          return Stack(
            children: children.reversed.toList(),
          );
        });
  }

  @override
  Future<List<T>?> Function(int index) getLoader() {
    return (index) => widget.pageLoader(index);
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
      state.removeItem(
        index,
        (context, animation) => widget.onRemoveAnimation ?? SizedBox.shrink(),
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
      updateItem(index, item);

      state.removeItem(
        index,
        (context, animation) => widget.onRemoveAnimation ?? SizedBox.shrink(),
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
      Center(
        child: Text(
          "No data",
          style: TextStyle(color: Colors.red),
        ),
      );

  Widget get loadingWidget =>
      widget.loadingWidget ?? Center(child: CircularProgressIndicator());

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
              SizedBox(height: 100),
              Icon(
                Icons.error,
                color: Theme.of(context).colorScheme.error,
                size: 64,
              ),
              SizedBox(height: 16),
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
}
