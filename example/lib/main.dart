import 'dart:async';

import 'package:datalocal/datalocal.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DataLocalExampleApp());
}

class DataLocalExampleApp extends StatelessWidget {
  const DataLocalExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DataLocal 2 Example',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    ),
    home: const NotesPage(),
  );
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _controller = TextEditingController();
  DataLocalDatabase? _database;
  DataLocalCollection<Map<String, Object?>>? _notes;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      const databaseName = 'datalocal-v2-example';
      final keys = DataLocalSecureStorageKeyProvider(
        databaseName: databaseName,
      );
      final database = await DataLocalDatabase.open(
        name: databaseName,
        storage: DataLocalSharedPreferencesAsyncStorage(),
        encryption: DataLocalAesGcmEncryptionProvider(keyProvider: keys),
      );
      if (!mounted) {
        await database.close();
        return;
      }
      setState(() {
        _database = database;
        _notes = database.mapCollection('notes');
      });
    } catch (error) {
      if (mounted) {
        setState(() => _initializationError = error);
      }
    }
  }

  Future<void> _addNote() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    await _notes!.insert(<String, Object?>{'title': title});
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    final database = _database;
    if (database != null) {
      unawaited(database.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _initializationError;
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('DataLocal 2 Example')),
        body: Center(child: Text('Initialization failed: $error')),
      );
    }
    final notes = _notes;
    if (notes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('DataLocal 2 Example')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Encrypted local note',
                    ),
                    onSubmitted: (_) => _addNote(),
                  ),
                ),
                IconButton(
                  tooltip: 'Add note',
                  onPressed: _addNote,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<DataLocalQuerySnapshot<Map<String, Object?>>>(
              stream: notes.query().orderBy('title').watch(),
              builder: (context, snapshot) {
                final documents =
                    snapshot.data?.documents ??
                    const <DataLocalDocument<Map<String, Object?>>>[];
                if (documents.isEmpty) {
                  return const Center(child: Text('No notes yet'));
                }
                return ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    return ListTile(
                      title: Text(document.data['title']! as String),
                      subtitle: Text(
                        'revision ${document.revision} · ${document.id}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Delete note',
                        onPressed: () => notes.delete(document.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
