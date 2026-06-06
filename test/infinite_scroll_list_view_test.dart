import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

Widget buildList({
  required Future<List<String>?> Function(int page) pageLoader,
  GlobalKey<InfiniteScrollListViewState<String>>? stateKey,
  int? pageSize,
  bool Function(List<String> page)? isEndOfPage,
  List<String>? initialItems,
  void Function()? onReload,
  void Function(int page)? onLoadMore,
  Widget Function(BuildContext, int)? separatorBuilder,
  Widget Function(BuildContext, String, Animation<double>)? removeAnimationBuilder,
  Widget? noDataWidget,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InfiniteScrollListView<String>(
        key: stateKey,
        pageSize: pageSize,
        isEndOfPage: isEndOfPage,
        initialItems: initialItems,
        onReload: onReload,
        onLoadMore: onLoadMore,
        separatorBuilder: separatorBuilder,
        removeAnimationBuilder: removeAnimationBuilder,
        noDataWidget: noDataWidget,
        pageLoader: pageLoader,
        elementBuilder: (context, item, index, animation) => Text(item),
      ),
    ),
  );
}

void main() {
  group('end-of-page detection', () {
    testWidgets('defaults to isEmpty — stops after empty page', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(buildList(
        pageLoader: (page) async {
          callCount++;
          return page == 0 ? ['a', 'b'] : [];
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 2); // page 0 + one empty page to detect end
    });

    testWidgets('pageSize — stops when page has fewer items than pageSize',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(buildList(
        pageSize: 5,
        pageLoader: (page) async {
          callCount++;
          return ['a', 'b', 'c'];
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 1); // no extra empty-page round-trip
    });

    testWidgets('pageSize — continues when page is full', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(buildList(
        pageSize: 3,
        pageLoader: (page) async {
          callCount++;
          return page == 0 ? ['a', 'b', 'c'] : ['d'];
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets('isEndOfPage — custom predicate overrides pageSize and default',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(buildList(
        pageSize: 10,
        isEndOfPage: (page) => page.any((item) => item == 'LAST'),
        pageLoader: (page) async {
          callCount++;
          return ['a', 'LAST'];
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 1);
    });

    testWidgets('null pageLoader response always means end of results',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(buildList(
        pageSize: 10,
        pageLoader: (page) async {
          callCount++;
          return null;
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 1);
    });
  });

  group('isLoading / isEndOfResults', () {
    testWidgets('isLoading is true during fetch, false after', (tester) async {
      final key = GlobalKey<InfiniteScrollListViewState<String>>();
      final completer = Completer<List<String>>();

      await tester.pumpWidget(buildList(
        stateKey: key,
        pageLoader: (page) => completer.future,
      ));
      await tester.pump();

      expect(key.currentState!.isLoading, isTrue);

      completer.complete([]);
      await tester.pumpAndSettle();

      expect(key.currentState!.isLoading, isFalse);
    });

    testWidgets('isEndOfResults is true after last page', (tester) async {
      final key = GlobalKey<InfiniteScrollListViewState<String>>();
      await tester.pumpWidget(buildList(
        stateKey: key,
        pageSize: 5,
        pageLoader: (page) async => ['a', 'b'],
      ));
      await tester.pumpAndSettle();

      expect(key.currentState!.isEndOfResults, isTrue);
    });
  });

  group('clear()', () {
    testWidgets('empties the list and resets page index without fetching',
        (tester) async {
      final key = GlobalKey<InfiniteScrollListViewState<String>>();
      int callCount = 0;
      await tester.pumpWidget(buildList(
        stateKey: key,
        pageSize: 5,
        pageLoader: (page) async {
          callCount++;
          return ['a', 'b', 'c'];
        },
      ));
      await tester.pumpAndSettle();

      expect(key.currentState!.dataLength, 3);
      expect(callCount, 1);

      await key.currentState!.clear();
      await tester.pumpAndSettle();

      expect(key.currentState!.dataLength, 0);
      expect(callCount, 1); // no extra fetch
      expect(key.currentState!.isEndOfResults, isFalse);
    });
  });

  group('replace()', () {
    testWidgets('swaps list contents without triggering a fetch', (tester) async {
      final key = GlobalKey<InfiniteScrollListViewState<String>>();
      int callCount = 0;
      await tester.pumpWidget(buildList(
        stateKey: key,
        pageSize: 5,
        pageLoader: (page) async {
          callCount++;
          return ['a', 'b', 'c'];
        },
      ));
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await key.currentState!.replace(['x', 'y']);
      await tester.pumpAndSettle();

      expect(key.currentState!.dataLength, 2);
      expect(key.currentState!.dataList, ['x', 'y']);
      expect(callCount, 1); // still no extra fetch
    });
  });

  group('initialItems', () {
    testWidgets('pre-populates list without a network fetch', (tester) async {
      int callCount = 0;
      final key = GlobalKey<InfiniteScrollListViewState<String>>();
      await tester.pumpWidget(buildList(
        stateKey: key,
        initialItems: ['x', 'y', 'z'],
        pageLoader: (page) async {
          callCount++;
          return ['a'];
        },
      ));
      await tester.pumpAndSettle();

      expect(key.currentState!.dataList, ['x', 'y', 'z']);
      expect(callCount, 0); // no fetch triggered
    });

    testWidgets('falls back to pageLoader when initialItems is null',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(buildList(
        pageSize: 5,
        pageLoader: (page) async {
          callCount++;
          return ['a'];
        },
      ));
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });
  });

  group('onReload / onLoadMore callbacks', () {
    testWidgets('onReload fires on reload, not on initial load', (tester) async {
      int reloadCount = 0;
      final key = GlobalKey<InfiniteScrollListViewState<String>>();
      await tester.pumpWidget(buildList(
        stateKey: key,
        pageSize: 5,
        pageLoader: (page) async => ['a'],
        onReload: () => reloadCount++,
      ));
      await tester.pumpAndSettle();

      expect(reloadCount, 0); // initial load must not fire onReload

      await key.currentState!.reload();
      await tester.pumpAndSettle();

      expect(reloadCount, 1);
    });

    testWidgets('onLoadMore fires for pages after the first', (tester) async {
      final pages = <int>[];
      // pageSize=2: page 0 returns 2 items (full → not end), page 1 returns 1
      // item (fewer than pageSize → end). So onLoadMore fires exactly once for page 1.
      await tester.pumpWidget(buildList(
        pageSize: 2,
        pageLoader: (page) async => page == 0 ? ['a', 'b'] : ['c'],
        onLoadMore: (page) => pages.add(page),
      ));
      await tester.pumpAndSettle();

      expect(pages, [1]); // page 0 = initial load (skipped), page 1 = loadMore
    });
  });

  group('horizontal constructor', () {
    testWidgets('sets scrollDirection to horizontal', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: InfiniteScrollListView<String>.horizontal(
            pageSize: 5,
            pageLoader: (page) async => ['a', 'b'],
            elementBuilder: (context, item, index, animation) => Text(item),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final list = tester.widget<AnimatedList>(find.byType(AnimatedList));
      expect(list.scrollDirection, Axis.horizontal);
    });
  });

  group('separatorBuilder', () {
    testWidgets('renders separators between items but not after the last',
        (tester) async {
      await tester.pumpWidget(buildList(
        pageSize: 5,
        pageLoader: (page) async => ['a', 'b', 'c'],
        separatorBuilder: (context, index) => const Text('---'),
      ));
      await tester.pumpAndSettle();

      // 3 items → 2 separators
      expect(find.text('---'), findsNWidgets(2));
    });
  });

  group('removeAnimationBuilder', () {
    testWidgets('receives the removed item during exit animation', (tester) async {
      final key = GlobalKey<InfiniteScrollListViewState<String>>();
      String? capturedItem;

      await tester.pumpWidget(buildList(
        stateKey: key,
        pageSize: 5,
        pageLoader: (page) async => ['a', 'b', 'c'],
        removeAnimationBuilder: (context, item, animation) {
          capturedItem = item;
          return const SizedBox.shrink();
        },
      ));
      await tester.pumpAndSettle();

      await key.currentState!.removeItem('b');
      await tester.pumpAndSettle();

      expect(capturedItem, 'b');
    });
  });

  group('noDataWidget layout', () {
    testWidgets('shows noDataWidget when list is empty and not loading',
        (tester) async {
      await tester.pumpWidget(buildList(
        pageSize: 5,
        pageLoader: (page) async => [],
        noDataWidget: const Text('empty!'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('empty!'), findsOneWidget);
      // AnimatedList is still in the tree (Offstage keeps it alive but hidden)
      expect(find.byType(AnimatedList, skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows list when data is present', (tester) async {
      await tester.pumpWidget(buildList(
        pageSize: 5,
        pageLoader: (page) async => ['a'],
        noDataWidget: const Text('empty!'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('empty!'), findsNothing);
      expect(find.text('a'), findsOneWidget);
    });
  });

  group('dispose safety', () {
    testWidgets('disposing mid-fetch does not call AnimatedList callbacks',
        (tester) async {
      final completer = Completer<List<String>>();

      await tester.pumpWidget(buildList(
        pageLoader: (page) => completer.future,
      ));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());

      completer.complete(['a', 'b', 'c']);
      await tester.pumpAndSettle();
    });
  });
}
