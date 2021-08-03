import 'package:flutter/material.dart';
import 'package:infinite_scroll_list_view/infinite_scroll_list_view.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final key = GlobalKey<InfiniteScrollListViewState<String>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: InfiniteScrollListView<String>(
        refreshable: true,
        noDataWidget: ElevatedButton(
          child: Text("TAP"),
          onPressed: () {
            print("hello ${DateTime.now().millisecond}");
          },
        ),
        pageLoader: getPage,
        elementBuilder: (ctx, text, index, anim) {
          return ListTile(
            title: Text(text),
            onTap: () {},
          );
        },
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterTop,
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void remove(String id) {
    key.currentState!.removeWere((value) => value == id);
  }

  Future<List<String>?> getPage(int index) async {
    if (index == 0 && false) {
      return ["azul", "fellawn"];
    }
    return null;
  }
}
