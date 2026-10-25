import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const HissabApp());

class HissabApp extends StatelessWidget {
  const HissabApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hissab Kitab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B58)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F7FA),
          foregroundColor: Color(0xFF172B4D),
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF172B4D)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0.8,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF8FAFC),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class Entry {
  String id, book, note;
  bool income;
  double amount;
  DateTime date;
  Entry(this.id, this.book, this.note, this.income, this.amount, this.date);

  Map<String, dynamic> toJson() => {
        'id': id,
        'book': book,
        'note': note,
        'income': income,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        j['id'],
        j['book'],
        j['note'],
        j['income'],
        (j['amount'] as num).toDouble(),
        DateTime.parse(j['date']),
      );
}

String fmt(double v) {
  final s = v.abs().toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
  final parts = s.split('.');
  final intPart =
      parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  final out = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return v < 0 ? '-$out' : out;
}

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Entry> entries = [];
  List<String> books = ['School', 'Home'];
  String current = 'School';
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final e = p.getString('entries');
    final b = p.getStringList('books');
    setState(() {
      if (e != null) {
        entries = (jsonDecode(e) as List)
            .map((x) => Entry.fromJson(x as Map<String, dynamic>))
            .toList();
      }
      if (b != null && b.isNotEmpty) books = b;
      current = p.getString('current') ?? books.first;
      if (!books.contains(current)) current = books.first;
      loaded = true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    await p.setStringList('books', books);
    await p.setString('current', current);
  }

  List<Entry> _sortedEntries() {
    final list = entries.where((e) => e.book == current).toList()
      ..sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    return list;
  }

  Future<void> _addEntry(bool income) async => _showEntryDialog(income);

  Future<void> _editEntry(Entry entry) async =>
      _showEntryDialog(entry.income, existing: entry);

  Future<void> _showEntryDialog(bool income, {Entry? existing}) async {
    final amountC = TextEditingController(
        text: existing == null ? '' : fmt(existing.amount).replaceAll(',', ''));
    final noteC = TextEditingController(text: existing?.note ?? '');
    DateTime date = existing?.date ?? DateTime.now();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null
              ? (income ? 'Add Income' : 'Add Expense')
              : 'Edit Entry',
              style: TextStyle(
                color: income ? const Color(0xFF16805D) : const Color(0xFFC2414B),
                fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: amountC,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (Rs)',
                    prefixText: 'Rs ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final amount = double.tryParse((v ?? '').trim().replaceAll(',', ''));
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Enter a valid amount greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: noteC,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    hintText: 'What was this transaction for?',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(fmtDate(date)),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setD(() => date = DateTime(
                      d.year, d.month, d.day, date.hour, date.minute));
                  },
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(income ? 'Transaction type: Income' : 'Transaction type: Expense',
                    style: Theme.of(ctx).textTheme.bodySmall),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              icon: Icon(existing == null ? Icons.save_outlined : Icons.check),
              label: Text(existing == null ? 'Save entry' : 'Save changes'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      final amt = double.parse(amountC.text.trim().replaceAll(',', ''));
      setState(() {
        if (existing == null) {
          entries.add(Entry(DateTime.now().microsecondsSinceEpoch.toString(),
              current, noteC.text.trim(), income, amt, date));
        } else {
          final index = entries.indexWhere((e) => e.id == existing.id);
          if (index != -1) {
            entries[index]
              ..amount = amt
              ..note = noteC.text.trim()
              ..date = date;
          }
        }
      });
      await _save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(existing == null ? 'Entry saved successfully' : 'Entry updated successfully'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _addBook() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Account Book'),
        content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Name', border: OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    final name = c.text.trim();
    if (ok == true && name.isNotEmpty && !books.contains(name)) {
      setState(() {
        books.add(name);
        current = name;
      });
      _save();
    }
  }

  Future<void> _deleteBook() async {
    if (books.length <= 1) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$current"?'),
        content: const Text('All records in this book will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, delete')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        entries.removeWhere((e) => e.book == current);
        books.remove(current);
        current = books.first;
      });
      _save();
    }
  }

  Future<void> _printDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Print Report'),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'all'),
              child: const Text('All records')),
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'range'),
              child: const Text('Select date range')),
        ],
      ),
    );
    if (choice == null) return;
    DateTimeRange? range;
    if (choice == 'range') {
      range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (range == null) return;
    }
    await _printReport(range);
  }

  Future<void> _printReport(DateTimeRange? range) async {
    final sorted = _sortedEntries();
    double opening = 0;
    final rows = <Entry>[];
    for (final e in sorted) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      if (range != null && d.isBefore(range.start)) {
        opening += e.income ? e.amount : -e.amount;
      } else if (range != null && d.isAfter(range.end)) {
        // outside range
      } else {
        rows.add(e);
      }
    }

    double tIn = 0, tOut = 0;
    double run = opening;
    final data = <List<String>>[];
    if (range != null) {
      data.add(['', 'Opening balance', '', '', fmt(opening)]);
    }
    for (final e in rows) {
      if (e.income) {
        tIn += e.amount;
        run += e.amount;
      } else {
        tOut += e.amount;
        run -= e.amount;
      }
      data.add([
        fmtDate(e.date),
        e.note.isEmpty ? (e.income ? 'Income' : 'Expense') : e.note,
        e.income ? fmt(e.amount) : '',
        e.income ? '' : fmt(e.amount),
        fmt(run),
      ]);
    }
    data.add(['', 'TOTAL', fmt(tIn), fmt(tOut), fmt(run)]);

    final title = range == null
        ? 'All records'
        : '${fmtDate(range.start)} to ${fmtDate(range.end)}';

    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (ctx) => [
        pw.Text('Hissab Kitab - $current',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(title),
        pw.Text('Printed: ${fmtDate(DateTime.now())}'),
        pw.SizedBox(height: 12),
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total Income: Rs ${fmt(tIn)}'),
              pw.Text('Total Expense: Rs ${fmt(tOut)}'),
              pw.Text('Balance: Rs ${fmt(run)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ]),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Details', 'Income', 'Expense', 'Balance'],
          data: data,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: const pw.TextStyle(fontSize: 10),
          columnWidths: {
            0: const pw.FixedColumnWidth(60),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(60),
            3: const pw.FixedColumnWidth(60),
            4: const pw.FixedColumnWidth(65),
          },
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
        ),
      ],
    ));

    await Printing.layoutPdf(
      name: 'Hissab_Kitab_$current',
      onLayout: (format) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final list = _sortedEntries();

    double totalIn = 0, totalOut = 0;
    for (final e in list) {
      e.income ? totalIn += e.amount : totalOut += e.amount;
    }
    final balance = totalIn - totalOut;

    final days = <DateTime, List<Entry>>{};
    for (final e in list) {
      final k = DateTime(e.date.year, e.date.month, e.date.day);
      days.putIfAbsent(k, () => []).add(e);
    }
    final dayKeys = days.keys.toList()..sort();
    final closing = <DateTime, double>{};
    double run = 0;
    for (final k in dayKeys) {
      for (final e in days[k]!) {
        run += e.income ? e.amount : -e.amount;
      }
      closing[k] = run;
    }
    final shownKeys = dayKeys.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hissab Kitab'),
        actions: [
          IconButton(
              tooltip: 'Print',
              onPressed: _printDialog,
              icon: const Icon(Icons.print)),
          IconButton(
              tooltip: 'New book',
              onPressed: _addBook,
              icon: const Icon(Icons.create_new_folder_outlined)),
          IconButton(
              tooltip: 'Delete book',
              onPressed: _deleteBook,
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              for (final b in books)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(b),
                    selected: b == current,
                    onSelected: (_) {
                      setState(() => current = b);
                      _save();
                    },
                  ),
                ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('CURRENT BALANCE', style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              Text('Rs ${fmt(balance)}',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: balance >= 0 ? Colors.teal : Colors.red)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat('Total Income', totalIn, Colors.green),
                _stat('Total Expense', totalOut, Colors.red),
              ]),
            ]),
          ),
        ),
        Expanded(
          child: shownKeys.isEmpty
              ? const Center(child: Text('No entries yet'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: shownKeys.length,
                  itemBuilder: (ctx, i) {
                    final k = shownKeys[i];
                    final items = days[k]!;
                    double dIn = 0, dOut = 0;
                    for (final e in items) {
                      e.income ? dIn += e.amount : dOut += e.amount;
                    }
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: Column(children: [
                        Container(
                          color:
                              Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            Text(fmtDate(k),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text('Balance: ${fmt(closing[k]!)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: closing[k]! >= 0
                                        ? Colors.teal
                                        : Colors.red)),
                          ]),
                        ),
                        for (final e in items.reversed)
                          Dismissible(
                            key: ValueKey(e.id),
                            direction: DismissDirection.horizontal,
                            background: Container(color: Colors.red.shade100),
                            confirmDismiss: (_) async =>
                                await showDialog<bool>(
                                  context: ctx,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Delete this entry?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('No')),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text('Yes')),
                                    ],
                                  ),
                                ) ??
                                false,
                            onDismissed: (_) {
                              setState(() =>
                                  entries.removeWhere((x) => x.id == e.id));
                              _save();
                            },
                            child: ListTile(
                              dense: false,
                              onTap: () => _editEntry(e),
                              leading: CircleAvatar(
                                backgroundColor: e.income
                                    ? const Color(0xFFE1F5EC)
                                    : const Color(0xFFFCE8E8),
                                child: Icon(
                                  e.income
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: e.income ? const Color(0xFF16805D) : const Color(0xFFC2414B)),
                              ),
                              title: Text(e.note.isEmpty
                                  ? (e.income ? 'Income' : 'Expense')
                                  : e.note),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${e.income ? '+' : '-'}${fmt(e.amount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: e.income ? const Color(0xFF16805D) : const Color(0xFFC2414B)),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Entry actions',
                                    onSelected: (action) {
                                      if (action == 'edit') _editEntry(e);
                                      if (action == 'delete') {
                                        showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Delete this entry?'),
                                            content: const Text('This action cannot be undone.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
                                            ],
                                          ),
                                        ).then((yes) {
                                          if (yes == true && mounted) {
                                            setState(() => entries.removeWhere((x) => x.id == e.id));
                                            _save();
                                          }
                                        });
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit entry'))),
                                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete entry'))),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Text('Day income: ${fmt(dIn)}',
                                    style: const TextStyle(
                                        color: Colors.green, fontSize: 12)),
                                Text('Day expense: ${fmt(dOut)}',
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 12)),
                              ]),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'in',
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            onPressed: () => _addEntry(true),
            icon: const Icon(Icons.add),
            label: const Text('Income'),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'out',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            onPressed: () => _addEntry(false),
            icon: const Icon(Icons.remove),
            label: const Text('Expense'),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double v, Color c) => Column(children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(fmt(v),
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
      ]);
}
