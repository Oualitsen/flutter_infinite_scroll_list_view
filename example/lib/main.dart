import 'dart:math';

import 'package:flutter/material.dart';
import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'infinite scroll list view',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final key = GlobalKey<InfiniteScrollListViewState<Message>>();
  final data = <Message>[];
  final random = Random(100);
  void addData() {
    var id = random.nextInt(100);
    data.add(
        Message("Message # $id", id, DateTime.now().millisecondsSinceEpoch));

    key.currentState!.add(data.last);
  }

  int comparator(Message a, Message b) {
    return a.id - b.id;
  }

  int zeroComp(Message a, Message b) {
    return 0;
  }

  int comparator2(Message a, Message b) {
    return -(a.id - b.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite scroll list view'),
      ),
      body: InfiniteScrollListView<Message>(
        comparator: comparator,
        key: key,
        elementBuilder: (context, element, index, animation) {
          return ListTile(
            title: Text(element.content),
            subtitle: Text(
                "${element.id}: update: ${DateTime.fromMillisecondsSinceEpoch(element.lastUpdate)}"),
          );
        },
        pageLoader: loadPage,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addData,
        tooltip: 'Add Message',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<List<Message>> loadPage(int index) async {
    // use this function to fetch data from your sever.
    // returning a null or empty list means the end of data and no more calls
    // will be made.
    if (index == 0) {
      return data;
    }
    return [];
  }
}

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
