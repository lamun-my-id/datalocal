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
  DataPaginate dpaginate = DataPaginate(page: 1, size: 30);
  // DataQuery? data;
  bool loading = true;
  DataItem? selectedData;
  DataSort? sort;

  DataSearch search = DataSearch(
    keys: [DataKey("title"), DataKey("content")],
    value: "",
  );

  List<DataSort> sorts = [
    DataSort(
        key: DataKey("#createdAt", as: "Tanggal Dibuat (Z-A)"), desc: true),
    DataSort(
        key: DataKey("#createdAt", as: "Tanggal Dibuat (A-Z)"), desc: false),
    DataSort(key: DataKey("title", as: "Judul (A-Z)"), desc: false),
    DataSort(key: DataKey("title", as: "Judul (Z-A)"), desc: true),
  ];

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
      debugMode: true,
    );
    // refresh();
    // state.refresh();
    loading = false;
    setState(() {});
  }

  // refresh() {
  //   state.onRefresh = () async {
  //     // data = await state.find(
  //     //   paginate: dpaginate,
  //     //   sorts: [
  //     //     DataSort(
  //     //       key: DataKey("#createdAt"),
  //     //       desc: true,
  //     //     ),
  //     //   ],
  //     // );
  //     // print("object data length ${data!.length} ${dpaginate.page}");
  //     setState(() {});
  //   };
  // }

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
      await state.removeOne(selectedData!.id);
      selectedData = null;
      titleController.clear();
      contentController.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          InkWell(
            onTap: () async {
              for (int i = 0; i < 1000; i++) {
                await state.insertOne({
                  "title": "Test $i",
                  "content":
                      "Lorem ipsum odor amet, consectetuer adipiscing elit. Consectetur semper aenean malesuada libero augue dis sagittis commodo? Placerat molestie ac massa facilisis justo, habitasse parturient consectetur ligula. Sagittis habitasse mattis commodo placerat velit tellus sociosqu ultricies? Vestibulum tincidunt per tortor enim sit ultricies. Mi penatibus quis tristique mi bibendum primis commodo vehicula cras. Urna potenti ornare molestie orci vitae ante. Sed lacinia platea est pellentesque iaculis. Id cras magna volutpat magnis; hac mollis donec.Felis velit aliquet gravida porta auctor quisque diam ornare. Porta pretium condimentum tortor ultrices ultricies; dignissim dui gravida ullamcorper. Vestibulum vestibulum nunc ridiculus in sagittis consectetur lacus vitae. Diam integer augue facilisi sagittis consectetur neque dui. Dolor mollis tempus sit ullamcorper eget consequat. Interdum a risus egestas scelerisque consequat egestas sit. Nam aliquam curae phasellus tristique primis velit. Mus et per egestas eleifend fringilla class dignissim eleifend congue.Cubilia interdum nam massa felis fermentum pretium porttitor porta. Torquent ut tristique bibendum rutrum nostra phasellus. Vitae elementum ridiculus diam conubia eros sociosqu cubilia placerat. Fames duis felis id, dictum himenaeos morbi. Proin suscipit porttitor ad fusce tortor, ut consectetur. Non ut etiam dictum litora id a diam tincidunt. Congue est commodo nullam tempus platea volutpat elementum.Feugiat sollicitudin ultrices sed litora erat. Habitant maecenas sit mattis vestibulum taciti primis nullam habitasse luctus. Dictum suspendisse porttitor elementum cras hendrerit nisi gravida. Lacinia dapibus habitant nisl fringilla luctus ex metus. Torquent auctor placerat neque; felis ligula varius. Mollis etiam lacus tincidunt feugiat eu eu. Risus nec ante nam felis odio senectus tincidunt dis.Maecenas commodo placerat proin nisl aliquet fermentum hac. Volutpat sapien proin nec feugiat sollicitudin. Blandit suspendisse curabitur habitant gravida aptent ullamcorper class primis. Mi maximus arcu finibus habitant maximus finibus. Maecenas at dictum velit a maecenas. Quisque ad lobortis elementum iaculis fusce pulvinar ornare. Semper montes iaculis netus; congue netus ac. Maximus fusce non lorem tempus, semper morbi adipiscing.",
                  "createdAt": DateTime.now(),
                  "updatedAt": null,
                });
              }
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: SizedBox(
        width: width,
        height: height,
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: SizedBox(
                height: height,
                width: width,
                child: Builder(
                  builder: (_) {
                    if (loading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    return FutureBuilder<DataQuery>(
                      future: state.find(
                        sorts: [
                          sort ?? sorts[3],
                        ],
                        search: (search.value ?? "").isNotEmpty ? search : null,
                        paginate: dpaginate,
                      ),
                      builder: (_, snapshot) {
                        // return const Center(
                        //   child: CircularProgressIndicator(),
                        // );
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        DataQuery data = snapshot.data!;
                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              width: width,
                              child: Row(
                                children: [
                                  DropdownButton<DataSort>(
                                    items: sorts.map((_) {
                                      return DropdownMenuItem(
                                        value: _,
                                        child: Text(_.key.as ?? ""),
                                      );
                                    }).toList(),
                                    onChanged: (_) {
                                      sort = _;
                                      setState(() {});
                                    },
                                    value: sort ?? sorts.first,
                                  ),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  Expanded(
                                    child: TextField(
                                      onChanged: (_) {
                                        search.value = _;
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  Text(
                                    "${(dpaginate.size * (dpaginate.page - 1)) + 1}-${dpaginate.size * dpaginate.page} of ${data.count}",
                                  ),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  InkWell(
                                    onTap: dpaginate.page > 1
                                        ? () {
                                            dpaginate.page--;
                                            // refresh();
                                            // state.refresh();
                                            setState(() {});
                                          }
                                        : null,
                                    child: Icon(
                                      Icons.chevron_left,
                                      color: dpaginate.page > 1
                                          ? Colors.black
                                          : Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  Text("${dpaginate.page}"),
                                  const SizedBox(
                                    width: 16,
                                  ),
                                  InkWell(
                                    onTap: dpaginate.page <
                                            data.count / dpaginate.size.ceil()
                                        ? () {
                                            dpaginate.page++;
                                            // refresh();
                                            setState(() {});
                                            // state.refresh();
                                          }
                                        : null,
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: dpaginate.page <
                                              data.count / dpaginate.size.ceil()
                                          ? Colors.black
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Builder(
                                builder: (_) {
                                  if (!snapshot.hasData) {
                                    return const CircularProgressIndicator();
                                  }
                                  List<DataItem> docs = snapshot.data!.data;
                                  return ListView.builder(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    itemCount: docs.length,
                                    itemBuilder: (_, index) {
                                      DataItem data = docs[index];
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
                                              borderRadius:
                                                  BorderRadius.circular(10),
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
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  data.get(DataKey("content")),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Container(
                                                  width: width,
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 8,
                                                  ),
                                                  alignment:
                                                      Alignment.bottomRight,
                                                  child: Text(
                                                    data
                                                        .get(DataKey(
                                                            "#createdAt"))
                                                        .toString(),
                                                    textAlign: TextAlign.end,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                            // Expanded(
                            //   child: ListView.builder(
                            //     padding: const EdgeInsets.symmetric(
                            //       horizontal: 16,
                            //       vertical: 8,
                            //     ),
                            //     itemCount: data!.length,
                            //     itemBuilder: (_, index) {
                            //       DataItem data = this.data!.data[index];
                            //       return Padding(
                            //         padding: const EdgeInsets.symmetric(
                            //           vertical: 4,
                            //         ),
                            //         child: InkWell(
                            //           onTap: () => openForm(data),
                            //           child: Container(
                            //             width: width,
                            //             padding: const EdgeInsets.symmetric(
                            //               horizontal: 16,
                            //               vertical: 16,
                            //             ),
                            //             decoration: BoxDecoration(
                            //               color: Colors.white,
                            //               borderRadius: BorderRadius.circular(10),
                            //             ),
                            //             child: Column(
                            //               crossAxisAlignment:
                            //                   CrossAxisAlignment.start,
                            //               children: [
                            //                 SizedBox(
                            //                   width: width,
                            //                   child: Text(
                            //                     data.get(DataKey("title")),
                            //                     style: const TextStyle(
                            //                       fontSize: 16,
                            //                       fontWeight: FontWeight.w600,
                            //                     ),
                            //                   ),
                            //                 ),
                            //                 Text(
                            //                   data.get(DataKey("content")),
                            //                   maxLines: 3,
                            //                   overflow: TextOverflow.ellipsis,
                            //                 ),
                            //                 Container(
                            //                   width: width,
                            //                   padding: const EdgeInsets.only(
                            //                     top: 8,
                            //                   ),
                            //                   alignment: Alignment.bottomRight,
                            //                   child: Text(
                            //                     data
                            //                         .get(DataKey("#createdAt"))
                            //                         .toString(),
                            //                     textAlign: TextAlign.end,
                            //                     overflow: TextOverflow.ellipsis,
                            //                     style: const TextStyle(
                            //                       fontSize: 12,
                            //                     ),
                            //                   ),
                            //                 ),
                            //               ],
                            //             ),
                            //           ),
                            //         ),
                            //       );
                            //     },
                            //   ),
                            // ),
                          ],
                        );
                      },
                    );
                  },
                ),
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
