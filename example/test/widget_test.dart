import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

class Message {
  final String content;
  final int id;
  final int lastUpdate;

  Message(this.content, this.id, this.lastUpdate);

  @override
  String toString() {
    return '{id: $id, content: $content}';
  }
}

void main() {
  Widget createWidgetUnderTest(
      {required Future<List<Message>?> Function(int) loader}) {
    return MaterialApp(
      home: Scaffold(
        body: InfiniteScrollListView<Message>(
          pageLoader: loader,
          elementBuilder: (context, element, index, animation) {
            return ListTile(
              title: Text(element.content),
            );
          },
          comparator: (a, b) => a.id - b.id,
        ),
      ),
    );
  }

  testWidgets('loads initial items', (WidgetTester tester) async {
    final messages = List.generate(5, (i) => Message('Message $i', i, i));

    await tester.pumpWidget(createWidgetUnderTest(loader: (index) async {
      if (index == 0) {
        return messages;
      }
      return [];
    }));

    // wait for widgets to build and data to load
    await tester.pumpAndSettle();

    // Verify all messages are displayed
    for (var msg in messages) {
      expect(find.text(msg.content), findsOneWidget);
    }
  });

  testWidgets('shows loading widget while fetching',
      (WidgetTester tester) async {
    final completer = Completer<List<Message>>();

    await tester.pumpWidget(createWidgetUnderTest(loader: (index) {
      if (index == 0) return completer.future;
      return Future.value([]);
    }));

    // Should show CircularProgressIndicator initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete([Message('Test', 0, 0)]);
    await tester.pumpAndSettle();

    // Loading should disappear and list should appear
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Test'), findsOneWidget);
  });

  testWidgets('shows no data widget when empty', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest(loader: (index) async => []));

    await tester.pumpAndSettle();

    expect(find.text('No data'), findsOneWidget);
  });

  testWidgets('supports pull-to-refresh', (WidgetTester tester) async {
    var loaded = false;
    int callCount = 0;
    await tester.pumpWidget(createWidgetUnderTest(loader: (index) async {
      if (index == 0) {
        callCount++;
        loaded = true;
        return [
          Message(callCount == 1 ? 'Initial Data' : 'Refreshed data', 1, 0)
        ];
      }
      return [];
    }));

    await tester.pumpAndSettle();

    // Drag to trigger RefreshIndicator
    await tester.drag(find.byType(AnimatedList), const Offset(0, 300));
    await tester.pump(); // start animation
    await tester.pump(const Duration(seconds: 1)); // allow refresh

    expect(loaded, true);
    expect(find.text('Refreshed data'), findsOneWidget);
  });
}
