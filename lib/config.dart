import 'dart:convert';
import 'dart:io';

import 'package:passage_of_the_day/bible.dart';

String findSandbox(String nameOrPath) {
  if (nameOrPath.contains('/') || nameOrPath.contains('\\')) {
    final p = nameOrPath;
    Directory(p).createSync(recursive: true);
    return p;
  }

  final env = Platform.environment['PASSAGE_SANDBOX'];
  if (env != null && env.isNotEmpty) {
    Directory(env).createSync(recursive: true);
    return env;
  }

  final root = _findProjectRoot();
  final sb = '$root/passages/$nameOrPath';
  Directory(sb).createSync(recursive: true);
  return sb;
}

String _findProjectRoot() {
  var dir = Directory.current.path;
  while (true) {
    if (Directory('$dir/passages').existsSync() ||
        File('$dir/pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = Directory(dir).parent.path;
    if (parent == dir) break;
    dir = parent;
  }
  Directory('passages/default').createSync(recursive: true);
  return Directory.current.path;
}

class Sandbox {
  final String path;
  late Map<String, dynamic> _config;

  Sandbox(this.path) {
    _config = _loadJson('config.json');
  }

  Map<String, dynamic> _loadJson(String name) {
    final f = File('$path/$name');
    if (f.existsSync()) {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }
    return {};
  }

  dynamic get(String key, [dynamic defaultValue]) =>
      _config[key] ?? defaultValue;

  String get curatedPath => '$path/curated.txt';
  String get biblePath => '$path/kjv.json';
  String get statePath => '$path/.curated_state.json';
  String get name => path.split(RegExp(r'[/\\]')).last;
}

void initSandboxDir(String path) {
  Directory(path).createSync(recursive: true);

  if (!File('$path/config.json').existsSync()) {
    File('$path/config.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'bible': 'KJV',
        'curated_weight': 0.3,
        'max_verses': 5,
        'line_by_line': false,
        'numbered': false,
        'show_notes': false,
        'port': 4281,
      }),
    );
  }

  final curated = File('$path/curated.txt');
  if (!curated.existsSync()) {
    curated.writeAsStringSync(
      '# Passage of the Day - Curated Passages\n'
      '# Lines starting with # are comments.\n'
      '# Use ! to mark featured passages (shown first).\n'
      '# Format: Book Chapter:Verse or Book Chapter:Verse-Verse\n'
      '#\n'
      'John 3:16\n'
      'Psalm 23\n'
      'Psalm 119:105\n'
      'Proverbs 3:5-6\n'
      'Romans 8:28\n'
      'Philippians 4:13\n'
      'Jeremiah 29:11\n'
      'Isaiah 40:31\n'
      'Matthew 6:33\n'
      '!Psalm 1:1-3\n'
      '!Genesis 1:1\n',
    );
  }
}

void listCuratedPassages(Sandbox sandbox) {
  final refs = loadCurated(sandbox.curatedPath);
  if (refs.isEmpty) {
    print('No curated passages found.');
    return;
  }
  for (final r in refs) {
    final prefix = r.featured ? '★ ' : '  ';
    var ref = '${r.book} ${r.chapter}';
    if (r.verseStart != null) {
      ref += ':${r.verseStart}';
      if (r.verseEnd != null && r.verseEnd != r.verseStart) {
        ref += '-${r.verseEnd}';
      }
    }
    print('$prefix$ref');
  }
}