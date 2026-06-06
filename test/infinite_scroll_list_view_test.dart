import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

Widget buildList({
  required Future<List<String>?> Function(int page) pageLoader,
  GlobalKey<InfiniteScrollListViewState<String>>? stateKey,
  int? pageSize,
  bool Function(List<String> page)? isEndOfPage,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InfiniteScrollListView<String>(
        key: stateKey,
        pageSize: pageSize,
        isEndOfPage: isEndOfPage,
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
