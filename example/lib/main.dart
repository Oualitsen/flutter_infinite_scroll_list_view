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
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
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

class _MyHomePageState extends State<MyHomePage> {
  final key = GlobalKey<InfiniteScrollListViewState<Message>>();
  final data = <Message>[];
  final random = Random(100);
  void addData() {
    var id = random.nextInt(100);
    data.add(
        Message("Message # ${id}", id, DateTime.now().millisecondsSinceEpoch));
    // if (data.isEmpty) {
    //   data.add(Message("Message # 0", 0));
    // } else {
    //   var nextId = data.last.id + 1;
    //   data.add(Message("Message # ${nextId}", nextId));
    // }
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
        title: Text(widget.title),
      ),
      body: InfiniteScrollListView<Message>(
        comparator: zeroComp,
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
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<List<Message>> loadPage(int index) async {
    if (index == 0) {
      return data;
    }
    return [];
  }
}
