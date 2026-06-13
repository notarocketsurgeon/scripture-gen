import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:passage_of_the_day/bible.dart';
import 'package:passage_of_the_day/config.dart';
import 'package:passage_of_the_day/download.dart';
import 'package:passage_of_the_day/format.dart';
import 'package:passage_of_the_day/selector.dart';

void main(List<String> args) async {
  var sandboxName = 'default';
  var outputFormat = 'text';
  var lineByLine = false;
  var numbered = false;
  var showNotes = false;
  String? ref;
  var count = 1;
  var initSb = false;
  var listCurated = false;
  var noDownload = false;

  // New Batch Export Params
  var isBatchExport = false;
  var exportDir = '';
  var outputToTerminal = true;
  var batchSize = 1; // Total number of batches to run

  var i = 0;
  while (i < args.length) {
    final a = args[i];
    if (a == '-s' || a == '--sandbox') {
      if (i + 1 < args.length) sandboxName = args[++i];
    } else if (a == '-f' || a == '--format') {
      if (i + 1 < args.length) outputFormat = args[++i];
    } else if (a == '--line') {
      lineByLine = true;
    } else if (a == '--number') {
      numbered = true;
    } else if (a == '--notes') {
      showNotes = true;
    } else if (a == '-r' || a == '--ref') {
      if (i + 1 < args.length) ref = args[++i];
    } else if (a == '-n' || a == '--count') {
      if (i + 1 < args.length) count = int.tryParse(args[++i]) ?? 1;
    } else if (a == '--init') {
      initSb = true;
    } else if (a == '--list-curated') {
      listCurated = true;
    } else if (a == '--no-download') {
      noDownload = true;
    } else if (a == '--batchexport') {
      isBatchExport = true;
    } else if (a == '--export-dir' && i + 1 < args.length) {
      exportDir = args[++i];
    } else if (a == '--output-terminal' && i + 1 < args.length) {
      outputToTerminal = (args[++i] == 'true');
    } else if (a == '--batch-size' && i + 1 < args.length) {
      batchSize = int.tryParse(args[++i]) ?? 1;
    } else if (a == '-h' || a == '--help') {
      printUsage();
      return;
    }
    i++;
  }

  final sandboxPath = findSandbox(sandboxName);
  final sandbox = Sandbox(sandboxPath);

  if (!args.contains('--line')) {
    lineByLine = sandbox.get('line_by_line', false) as bool;
  }
  if (!args.contains('--number')) {
    numbered = sandbox.get('numbered', false) as bool;
  }
  if (!args.contains('--notes')) {
    showNotes = sandbox.get('show_notes', false) as bool;
  }

  if (initSb) {
    initSandboxDir(sandboxPath);
    stderr.writeln('Initialized sandbox at $sandboxPath');
    return;
  }

  if (listCurated) {
    listCuratedPassages(sandbox);
    return;
  }

  // Handle Batch Export logic
  if (isBatchExport) {
    await runBatchExport(
        sandbox, outputFormat, lineByLine, numbered, showNotes, 
        noDownload, exportDir, outputToTerminal, batchSize);
    return;
  }

  if (ref != null) {
    final passage = await lookupRef(ref, sandbox);
    outputPassage(passage, outputFormat,
        lineByLine: lineByLine, numbered: numbered, showNotes: showNotes);
    return;
  }

  var bible = Bible(sandbox.biblePath);
  if (!bible.isLoaded && !noDownload) {
    stderr.writeln('KJV Bible not found. Downloading...');
    if (await downloadKJV(sandbox.biblePath)) {
      bible = Bible(sandbox.biblePath);
    } else {
      stderr.writeln('Proceeding with curated list only.');
    }
  }

  for (var n = 0; n < count; n++) {
    final passage = selectPassage(bible, sandbox);
    outputPassage(passage, outputFormat,
        lineByLine: lineByLine, numbered: numbered, showNotes: showNotes);
    if (n < count - 1) print('');
  }
}

Future<void> runBatchExport(
    Sandbox sandbox, String format, bool lineByLine, bool numbered,
    bool showNotes, bool noDownload, String customDir, bool toTerminal, int numBatches) async {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  final baseDir = customDir.isEmpty ? 'out' : customDir;
  final batchRoot = p.join(baseDir, 'export_$timestamp');

  await Directory(batchRoot).create(recursive: true);
  stderr.writeln('Batch export started. Target: $batchRoot');

  var bible = Bible(sandbox.biblePath);
  if (!bible.isLoaded && !noDownload) {
    stderr.writeln('Error: KJV Bible not found. Cannot perform batch export without text.');
    return;
  }

  for (var b = 1; b <= numBatches; b++) {
    final passage = selectPassage(bible, sandbox);
    if (passage.isEmpty) continue;

    // Build Title using only available Verse fields: book, chapter, verse
    String title = "";
    final v = passage[0];
    title = '${v.book} ${v.chapter}:${v.verse}';

    final body = formatPassage(passage,
        lineByLine: lineByLine, numbered: numbered, showNotes: showNotes);
    
    final fileContent = "TITLE: $title\n\n$body";

    if (toTerminal) {
      print(fileContent);
    } else {
      final batchFile = File(p.join(batchRoot, 'passage_$b.txt'));
      await batchFile.writeAsString(fileContent);
    }
  }

  stderr.writeln('Batch export completed: $batchRoot');
}

Future<List<Verse>> lookupRef(String refStr, Sandbox sandbox) async {
  final parsed = parseReference('!$refStr');
  if (parsed == null) {
    stderr.writeln('Could not parse reference: $refStr');
    return [];
  }

  final bible = Bible(sandbox.biblePath);
  if (bible.isLoaded) {
    return bible.lookup(parsed);
  }

  stderr.writeln('KJV Bible not found. Downloading...');
  if (await downloadKJV(sandbox.biblePath)) {
    final b2 = Bible(sandbox.biblePath);
    return b2.lookup(parsed);
  }

  stderr.writeln('Cannot look up reference without Bible text.');
  return [];
}

void outputPassage(List<Verse> passage, String format,
    {bool lineByLine = false, bool numbered = false, bool showNotes = false}) {
  switch (format) {
    case 'json':
      final json = passage.map((v) => {
        'book': v.book,
        'chapter': v.chapter,
        'verse': v.verse,
        'text': showNotes ? v.text : stripNotes(v.text).trim(),
      }).toList();
      print(const JsonEncoder.withIndent('  ').convert(json));
      break;
    default:
      print(formatPassage(passage,
          lineByLine: lineByLine, numbered: numbered, showNotes: showNotes));
  }
}

void printUsage() {
  print('''
Usage: passage [options]

Options:
  -s, --sandbox PATH   Sandbox path or name
  -f, --format FORMAT  Output format: text, json
  -r, --ref REF        Look up specific reference
  -n, --count NUM      Number of passages (default: 1)
  --line               One verse per line (default: wrapped text)
  --number             Show verse numbers before each verse
  --notes              Show KJV textual notes {like this} (stripped by default)
  --init               Initialize a sandbox
  --list-curated       List curated passages
  --no-download        Skip KJV download
  -h, --help           Show this help

Batch Export:
  --batchexport         Enable batch export mode. Creates timestamped folder with 'passage_X.txt' files (TITLE \n\n BODY).
  --export-dir PATH     Target directory for exports (default: 'out')
  --output-terminal     Display output to terminal (true/false)
  --batch-size NUM      Total number of batches to run (default: 1)

Display modes:
  (no flags)    Wrapped text, verses run together, notes stripped
  --line        Each verse on its own line
  --number      Verse numbers shown before each verse (works with or without --line)
  --notes       Show {translator notes} in the text (stripped by default)
  -f json       Structured JSON output
''');
}