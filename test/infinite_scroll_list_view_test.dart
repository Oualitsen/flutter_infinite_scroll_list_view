import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

Widget _buildList({
  required Future<List<String>?> Function(int page) pageLoader,
  int? pageSize,
  bool Function(List<String> page)? isEndOfPage,
}) {
  return MaterialApp(
    home: Scaffold(
      body: InfiniteScrollListView<String>(
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
      await tester.pumpWidget(_buildList(
        pageLoader: (page) async {
          callCount++;
          return page == 0 ? ['a', 'b'] : [];
        },
      ));

      // page 0 loads on init, page 1 loads when sentinel becomes visible
      await tester.pumpAndSettle();
      expect(callCount, 2); // page 0 + one empty page to detect end
    });

    testWidgets('pageSize — stops when page has fewer items than pageSize',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_buildList(
        pageSize: 5,
        pageLoader: (page) async {
          callCount++;
          // returns 3 items, which is less than pageSize=5 → end of results
          return ['a', 'b', 'c'];
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 1); // no extra empty-page round-trip
    });

    testWidgets('pageSize — continues when page is full', (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_buildList(
        pageSize: 3,
        pageLoader: (page) async {
          callCount++;
          // page 0 is full (3 == pageSize) → loads next; page 1 is partial → stops
          return page == 0 ? ['a', 'b', 'c'] : ['d'];
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets('isEndOfPage — custom predicate overrides pageSize and default',
        (tester) async {
      int callCount = 0;
      await tester.pumpWidget(_buildList(
        pageSize: 10, // would require 10 items, but isEndOfPage overrides
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
      await tester.pumpWidget(_buildList(
        pageSize: 10, // irrelevant — null response short-circuits everything
        pageLoader: (page) async {
          callCount++;
          return null;
        },
      ));

      await tester.pumpAndSettle();
      expect(callCount, 1);
    });
  });
}
