import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

Future<GlobalKey<InfiniteScrollListViewState<T>>> _pump<T>(
  WidgetTester tester, {
  required Future<List<T>?> Function() loader,
  required int Function(T, T) comparator,
}) async {
  final key = GlobalKey<InfiniteScrollListViewState<T>>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: InfiniteScrollListView<T>.once(
        key: key,
        oncePageLoader: loader,
        comparator: comparator,
        elementBuilder: simpleBuilder((_, item) => Text('$item')),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return key;
}

// ── comparators ──────────────────────────────────────────────────────────────

/// e and f first, then ascending alphabetical.
int _efFirst(String a, String b) {
  final aS = a == 'e' || a == 'f';
  final bS = b == 'e' || b == 'f';
  if (aS && !bS) return 1;
  if (!aS && bS) return -1;
  return b.compareTo(a);
}

/// Descending alphabetical (z → a).
int _descAlpha(String a, String b) => a.compareTo(b);

/// Vowels before consonants, then ascending alphabetical within each group.
const _vowels = {'a', 'e', 'i', 'o', 'u'};
int _vowelsFirst(String a, String b) {
  final aV = _vowels.contains(a);
  final bV = _vowels.contains(b);
  if (aV && !bV) return 1;
  if (!aV && bV) return -1;
  return b.compareTo(a);
}

/// Even numbers before odd, ascending within each group.
int _evenFirst(int a, int b) {
  final aE = a.isEven;
  final bE = b.isEven;
  if (aE && !bE) return 1;
  if (!aE && bE) return -1;
  return b - a; // ascending
}

/// Shorter strings first, then ascending alphabetical for equal lengths.
int _shortestFirst(String a, String b) {
  if (a.length != b.length) return b.length - a.length;
  return b.compareTo(a);
}

// ── tests ────────────────────────────────────────────────────────────────────

void main() {
  group('comparator', () {
    testWidgets('e and f appear first, rest in ascending alphabetical order',
        (tester) async {
      final allLetters = List.generate(
        26,
        (i) => String.fromCharCode('a'.codeUnitAt(0) + i),
      );
      final key = await _pump<String>(tester,
          loader: () async => allLetters, comparator: _efFirst);

      final list = key.currentState!.dataList;
      expect(list[0], 'e');
      expect(list[1], 'f');
      expect(list.sublist(2), [
        'a', 'b', 'c', 'd',
        'g', 'h', 'i', 'j', 'k', 'l', 'm',
        'n', 'o', 'p', 'q', 'r', 's', 't',
        'u', 'v', 'w', 'x', 'y', 'z',
      ]);
    });

    testWidgets('descending alphabetical — items arrive a→z, stored z→a',
        (tester) async {
      final allLetters = List.generate(
        26,
        (i) => String.fromCharCode('a'.codeUnitAt(0) + i),
      );
      final key = await _pump<String>(tester,
          loader: () async => allLetters, comparator: _descAlpha);

      final list = key.currentState!.dataList;
      expect(list.first, 'z');
      expect(list.last, 'a');
      expect(list, List.generate(26,
          (i) => String.fromCharCode('z'.codeUnitAt(0) - i)));
    });

    testWidgets('vowels before consonants, both groups ascending alphabetical',
        (tester) async {
      final allLetters = List.generate(
        26,
        (i) => String.fromCharCode('a'.codeUnitAt(0) + i),
      );
      final key = await _pump<String>(tester,
          loader: () async => allLetters, comparator: _vowelsFirst);

      final list = key.currentState!.dataList;
      final vowelSection = list.takeWhile(_vowels.contains).toList();
      final consonantSection = list.skipWhile(_vowels.contains).toList();

      expect(vowelSection, ['a', 'e', 'i', 'o', 'u']);
      expect(consonantSection.any(_vowels.contains), isFalse);
      // consonants in ascending order
      final sorted = [...consonantSection]..sort();
      expect(consonantSection, sorted);
    });

    testWidgets('even numbers before odd, both groups in ascending order',
        (tester) async {
      final numbers = List.generate(10, (i) => i + 1); // 1..10
      final key = await _pump<int>(tester,
          loader: () async => numbers, comparator: _evenFirst);

      final list = key.currentState!.dataList;
      final evens = list.takeWhile((n) => n.isEven).toList();
      final odds = list.skipWhile((n) => n.isEven).toList();

      expect(evens, [2, 4, 6, 8, 10]);
      expect(odds, [1, 3, 5, 7, 9]);
    });

    testWidgets('shorter strings appear first, tie-broken alphabetically',
        (tester) async {
      final words = ['banana', 'fig', 'kiwi', 'plum', 'apple', 'date', 'pear'];
      final key = await _pump<String>(tester,
          loader: () async => words, comparator: _shortestFirst);

      final list = key.currentState!.dataList;

      // fig (3) before kiwi/plum/pear/date (4) before apple/banana (5/6)
      expect(list.first, 'fig');
      // all length-4 words come before length-5+ words
      final firstLonger = list.indexWhere((w) => w.length > 4);
      final lastShorter = list.lastIndexWhere((w) => w.length <= 4);
      expect(lastShorter < firstLonger, isTrue);
    });

    testWidgets('duplicate items trigger update, not a second insertion',
        (tester) async {
      // comparator returns 0 for equal strings → deduplication
      final key = await _pump<String>(tester,
          loader: () async => ['a', 'b', 'a', 'c', 'b'],
          comparator: (a, b) => b.compareTo(a));

      // Only 3 unique items, no duplicates in the list
      expect(key.currentState!.dataList, ['a', 'b', 'c']);
    });

    testWidgets('items arriving out of order are sorted correctly',
        (tester) async {
      final key = await _pump<String>(tester,
          loader: () async => ['z', 'a', 'm', 'b', 'y'],
          comparator: (a, b) => b.compareTo(a)); // ascending

      expect(key.currentState!.dataList, ['a', 'b', 'm', 'y', 'z']);
    });
  });
}
