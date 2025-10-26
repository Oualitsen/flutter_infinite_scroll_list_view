# 🌀 Infinite Scroll List View

A **powerful, flexible, and efficient infinite scrolling list view** for Flutter.

`infinite_scroll_list_view` helps you easily build lists that dynamically load more data as the user scrolls — without boilerplate or complicated state management. It also lets you **insert, sort, or update items dynamically** while keeping your UI smooth and consistent.

Perfect for chats, feeds, and long data lists that grow endlessly!

---

## 🚀 Features

- 🔁 **Automatic pagination** — seamlessly load new pages as the user scrolls.  
- ⚡ **Dynamic updates** — add, remove, or update elements while maintaining list order.  
- 🧩 **Custom sorting** — provide your own comparator for complete control over item ordering.  
- 🚨 **Error handling** — use `elementErrorBuilder` to show retry options when data fails to load.  
- 🧠 **Smart deduplication** — use the `pick` function to decide which version of an object to keep when duplicates are detected.  
- 💡 **Simple API** — designed to feel just like Flutter’s built-in `ListView`, but more powerful.

---

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  infinite_scroll_list_view: ^1.1.0
```
Then run
```
flutter pub get
```
## 🧰 Example

```Dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

class _MyHomePageState extends State<MyHomePage> {
  final key = GlobalKey<InfiniteScrollListViewState<Message>>();
  final data = <Message>[];
  final random = Random(100);

  void addData() {
    var id = random.nextInt(100);
    data.add(
      Message("Message #$id", id, DateTime.now().millisecondsSinceEpoch),
    );
    key.currentState!.add(data.last);
  }

  int comparator(Message a, Message b) => a.id - b.id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Infinite Scroll List View')),
      body: InfiniteScrollListView<Message>(
        key: key,
        comparator: comparator,
        pageLoader: loadPage,
        elementBuilder: (context, element, index, animation) {
          return ListTile(
            title: Text(element.content),
            subtitle: Text(
              "${element.id}: updated at ${DateTime.fromMillisecondsSinceEpoch(element.lastUpdate)}",
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addData,
        tooltip: 'Add Message',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<List<Message>> loadPage(int index) async {
    // Simulate fetching a page of data from a server
    // Returning null or an empty list means no more data
    if (index == 0) return data;
    return [];
  }
}

class Message {
  final String content;
  final int id;
  final int lastUpdate;

  Message(this.content, this.id, this.lastUpdate);

  @override
  String toString() => '{id: $id, content: $content}';
}
```

## 💬 Why use Infinite Scroll List View?
Because scrolling should be infinite — not your code.
With this package, you get:

- Simplicity of ListView
- Power of pagination
- Control of custom sorting
- Smooth animations and updates

## ❤️ Contribute

---
If you have ideas, found bugs, or want to add new features, feel free to open an issue or PR!

https://github.com/Oualitsen/flutter_infinite_scroll_list_view

