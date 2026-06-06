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
    var msg = Message(
        "Message # $id", id, DateTime.now().millisecondsSinceEpoch, true);

    key.currentState!.add(msg);
  }

  void duplocate() {
    var last = key.currentState!.dataList.last;
    var id = last.id;
    var msg2 = Message("Message # $id (no anim)", id,
        DateTime.now().millisecondsSinceEpoch, false);
    key.currentState!.add(msg2);
  }

  int comparator(Message a, Message b) {
    return a.id - b.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite scroll list view'),
        actions: [
          TextButton(
              onPressed: () {},
              child: const Text(
                "Replace",
                style: TextStyle(color: Colors.red),
              ))
        ],
      ),
      body: InfiniteScrollListView<Message>(
        comparator: comparator,
        key: key,
        elementBuilder: (context, element, index, animation) {
          if (element.animate) {
            return buildAnimatedTile(context, element, animation);
          }
          return ListTile(
            title: Text(element.content),
            subtitle: Text(
                "${element.id}: update: ${DateTime.fromMillisecondsSinceEpoch(element.lastUpdate)}"),
          );
        },
        pageLoader: loadPage,
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: duplocate,
            child: const Icon(Icons.add_alarm),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            onPressed: addData,
            tooltip: 'Add Message',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget buildAnimatedTile(
      BuildContext context, element, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0), // Start from right
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: FadeTransition(
        opacity: animation,
        child: ListTile(
          title: Text(element.content),
          subtitle: Text(
            "${element.id}: update: ${DateTime.fromMillisecondsSinceEpoch(element.lastUpdate)}",
          ),
        ),
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
  final bool animate;

  Message(this.content, this.id, this.lastUpdate, this.animate);

  @override
  String toString() {
    return '{id: $id, content: $content}';
  }
}
