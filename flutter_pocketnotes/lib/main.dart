import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ============================================================
// CONFIG: change these 5 constants to match YOUR record type
// ============================================================
const String kTable = 'books';
const String kField1 = 'title';
const String kField2 = 'author';
const String kLabel1 = 'Title';
const String kLabel2 = 'Author';
// ============================================================

// ---------- Model ----------
class Record {
  final int? id;
  final String a;
  final String b;

  Record({this.id, required this.a, required this.b});

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        kField1: a,
        kField2: b,
      };

  factory Record.fromMap(Map<String, Object?> map) => Record(
        id: map['id'] as int,
        a: map[kField1] as String,
        b: map[kField2] as String,
      );
}

// ---------- Database (opened ONCE, reused everywhere) ----------
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Future<Database>? _dbFuture;
  Future<Database> get database => _dbFuture ??= _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'pocket_notes.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE $kTable('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          '$kField1 TEXT NOT NULL, '
          '$kField2 TEXT NOT NULL)',
        );
      },
    );
  }

  Future<List<Record>> getAll() async {
    final db = await database;
    final rows = await db.query(kTable, orderBy: 'id ASC');
    return rows.map(Record.fromMap).toList();
  }

  Future<int> insert(Record r) async {
    final db = await database;
    return db.insert(kTable, r.toMap());
  }

  Future<int> update(Record r) async {
    final db = await database;
    return db.update(
      kTable,
      r.toMap(),
      where: 'id = ?',
      whereArgs: [r.id],
    );
  }

  // Capture #8: circle where + whereArgs in this method.
  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(
      kTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Capture #7: prints every row to the console.
  Future<void> printAllRows() async {
    final db = await database;
    debugPrint((await db.query(kTable)).toString());
  }
}

Future<Record?> showRecordDialog(
  BuildContext context, {
  Record? existing,
}) async {
  final aCtrl = TextEditingController(text: existing?.a ?? '');
  final bCtrl = TextEditingController(text: existing?.b ?? '');

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(existing == null ? 'Add record' : 'Edit record'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: aCtrl,
              decoration: const InputDecoration(labelText: kLabel1),
            ),
            TextField(
              controller: bCtrl,
              decoration: const InputDecoration(labelText: kLabel2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );

  if (saved != true) return null;
  final a = aCtrl.text.trim();
  final b = bCtrl.text.trim();
  if (a.isEmpty || b.isEmpty) return null;

  return Record(id: existing?.id, a: a, b: b);
}

// ---------- Entry point ----------
const String kThemeKey = 'isDark';
final SharedPreferencesAsync prefs = SharedPreferencesAsync();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDark = await prefs.getBool(kThemeKey) ?? false;
  runApp(PocketNotesApp(initialDark: isDark));
}

class PocketNotesApp extends StatefulWidget {
  final bool initialDark;
  const PocketNotesApp({super.key, required this.initialDark});

  @override
  State<PocketNotesApp> createState() => _PocketNotesAppState();
}

class _PocketNotesAppState extends State<PocketNotesApp> {
  late bool _isDark = widget.initialDark;


  Future<void> _setDark(bool value) async {
    setState(() => _isDark = value);
    await prefs.setBool(kThemeKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: HomePage(isDark: _isDark, onThemeChanged: _setDark),
    );
  }
}

// ---------- Home screen ----------
class HomePage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  const HomePage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppDatabase _db = AppDatabase.instance;
  List<Record> _records = [];


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await _db.getAll();
    if (!mounted) return;
    setState(() => _records = rows);
    await _db.printAllRows(); // Capture #7: compare console to the list
  }

  // Add (existing == null) or edit. The context comes from the caller.
  Future<void> _openEditor(BuildContext ctx, {Record? existing}) async {
    final result = await showRecordDialog(ctx, existing: existing);
    if (result == null) return;

    if (existing == null) {
      await _db.insert(result);
    } else {
      await _db.update(result);
    }
    await _load();
  }

  Future<void> _delete(Record r) async {
    await _db.delete(r.id!);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Notes'),
        actions: [
          Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
          Switch(value: widget.isDark, onChanged: widget.onThemeChanged),
        ],
      ),
      body: _records.isEmpty
          ? const Center(child: Text('No records yet. Tap + to add one.'))
          : ListView.builder(
              itemCount: _records.length,
              itemBuilder: (itemContext, i) {
                final r = _records[i];
                return ListTile(
                  leading: CircleAvatar(child: Text('${r.id}')),
                  title: Text(r.a),
                  subtitle: Text(r.b),
                  onTap: () => _openEditor(itemContext, existing: r),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _delete(r),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}