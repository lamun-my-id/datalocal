import 'dart:async';

import 'package:datalocal/datalocal.dart';
import 'package:datalocal/datalocal_extension.dart';
import 'package:flutter/material.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Data State Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late DataLocal state;
  List<DataItem> data = [];
  bool loading = true;
  DataItem? selectedData;

  TextEditingController titleController = TextEditingController();
  TextEditingController contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future initialize() async {
    state = await DataLocal.create(
      "notes",
      onRefresh: () {
        // print("object-handle");
        setState(() {});
      },
      // debugMode: true,
    );
    state.onRefresh = () {
      data = state.data;
      // print("object data length ${data.length}");
      setState(() {});
    };
    state.refresh();
    loading = false;
    setState(() {});
  }

  openForm(DataItem value) {
    selectedData = value;
    titleController.text = value.get(DataKey('title'));
    contentController.text = value.get(DataKey("content"));
    setState(() {});
  }

  closeForm() {
    selectedData = null;
    titleController.text = "";
    contentController.text = "";
    setState(() {});
  }

  save() async {
    if (selectedData != null) {
      edit();
    } else {
      await state.insertOne({
        "title": titleController.text,
        "content": contentController.text,
        "createdAt": DateTime.now(),
        "updatedAt": null,
      });
      titleController.clear();
      contentController.clear();
      setState(() {});
    }
  }

  edit() async {
    await state.updateOne(selectedData!.id, value: {
      "title": titleController.text,
      "content": contentController.text,
      "updatedAt": DateTime.now(),
    });
    setState(() {});
  }

  delete() async {
    bool rmv = (await showDialog<bool?>(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('Delete this note'),
              content: const Text(
                'This action cannot be undone',
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            );
          },
        )) ??
        false;
    if (rmv) {
      await state.deleteOne(selectedData!.id);
      selectedData = null;
      titleController.clear();
      contentController.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SizedBox(
        width: width,
        height: MediaQuery.of(context).size.height,
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: Builder(
                builder: (_) {
                  if (loading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: state.count,
                          itemBuilder: (_, index) {
                            DataItem data = state.data[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              child: InkWell(
                                onTap: () => openForm(data),
                                child: Container(
                                  width: width,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: width,
                                        child: Text(
                                          data.get(DataKey("title")),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        data.get(DataKey("content")),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // Text(
                                      //   DateTimeUtils.dateFormat(
                                      //           data.get("createdAt")) ??
                                      //       "",
                                      //   overflow: TextOverflow.ellipsis,
                                      //   style: const TextStyle(
                                      //     fontSize: 12,
                                      //   ),
                                      // ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(),
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: width,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: const Text(
                                "Title",
                                style: TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            TextField(
                              controller: titleController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                            Container(
                              width: width,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              child: const Text(
                                "Content",
                                style: TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            TextField(
                              controller: contentController,
                              minLines: 4,
                              maxLines: 100,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 60,
                      width: width,
                      color: Colors.grey[50],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (selectedData != null)
                            InkWell(
                              onTap: () => delete(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "Delete",
                                  style: TextStyle(
                                      // color: Colors.white,
                                      ),
                                ),
                              ),
                            ),
                          const Expanded(child: SizedBox()),
                          if (selectedData != null)
                            InkWell(
                              onTap: () => closeForm(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                      // color: Colors.white,
                                      ),
                                ),
                              ),
                            ),
                          const SizedBox(
                            width: 16,
                          ),
                          InkWell(
                            onTap: () => save(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "Save",
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
