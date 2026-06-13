import 'dart:convert';
import 'dart:io';
import 'dart:math';

const bookNames = [
  "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
  "Joshua", "Judges", "Ruth",
  "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
  "1 Chronicles", "2 Chronicles",
  "Ezra", "Nehemiah", "Esther", "Job",
  "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon",
  "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel",
  "Hosea", "Joel", "Amos", "Obadiah", "Jonah", "Micah",
  "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi",
  "Matthew", "Mark", "Luke", "John", "Acts",
  "Romans", "1 Corinthians", "2 Corinthians", "Galatians",
  "Ephesians", "Philippians", "Colossians",
  "1 Thessalonians", "2 Thessalonians",
  "1 Timothy", "2 Timothy", "Titus", "Philemon",
  "Hebrews", "James",
  "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
  "Jude", "Revelation",
];

final bookAliases = <String, String>{
  'gen': 'Genesis', 'gn': 'Genesis',
  'ex': 'Exodus', 'exod': 'Exodus',
  'lev': 'Leviticus', 'lv': 'Leviticus',
  'num': 'Numbers', 'nm': 'Numbers',
  'deut': 'Deuteronomy', 'dt': 'Deuteronomy',
  'josh': 'Joshua', 'jos': 'Joshua',
  'judg': 'Judges', 'jdg': 'Judges',
  'rth': 'Ruth',
  'sam': '1 Samuel', '1sam': '1 Samuel', '1sa': '1 Samuel',
  '2sam': '2 Samuel', '2sa': '2 Samuel',
  'ki': '1 Kings', '1ki': '1 Kings', '1k': '1 Kings',
  '2ki': '2 Kings', '2k': '2 Kings',
  'chr': '1 Chronicles', '1chr': '1 Chronicles', '1ch': '1 Chronicles',
  '2chr': '2 Chronicles', '2ch': '2 Chronicles',
  'ezr': 'Ezra',
  'neh': 'Nehemiah',
  'est': 'Esther', 'es': 'Esther',
  'ps': 'Psalms', 'psa': 'Psalms', 'psalm': 'Psalms',
  'prov': 'Proverbs', 'prv': 'Proverbs',
  'eccl': 'Ecclesiastes', 'ecc': 'Ecclesiastes',
  'song': 'Song of Solomon', 'sg': 'Song of Solomon', 'sos': 'Song of Solomon',
  'isa': 'Isaiah',
  'jer': 'Jeremiah', 'jr': 'Jeremiah',
  'lam': 'Lamentations', 'la': 'Lamentations',
  'ezek': 'Ezekiel', 'ezk': 'Ezekiel',
  'dan': 'Daniel', 'dn': 'Daniel',
  'hos': 'Hosea',
  'joel': 'Joel',
  'amos': 'Amos',
  'obad': 'Obadiah',
  'jonah': 'Jonah',
  'mic': 'Micah',
  'nah': 'Nahum',
  'hab': 'Habakkuk',
  'zeph': 'Zephaniah', 'zep': 'Zephaniah',
  'hag': 'Haggai', 'hg': 'Haggai',
  'zech': 'Zechariah', 'zec': 'Zechariah',
  'mal': 'Malachi',
  'matt': 'Matthew', 'mt': 'Matthew',
  'mk': 'Mark',
  'lk': 'Luke',
  'jn': 'John',
  'acts': 'Acts',
  'rom': 'Romans', 'ro': 'Romans',
  'cor': '1 Corinthians', '1cor': '1 Corinthians', '1co': '1 Corinthians',
  '2cor': '2 Corinthians', '2co': '2 Corinthians',
  'gal': 'Galatians',
  'eph': 'Ephesians',
  'phil': 'Philippians', 'php': 'Philippians',
  'col': 'Colossians',
  'thess': '1 Thessalonians', '1thess': '1 Thessalonians', '1th': '1 Thessalonians',
  '2thess': '2 Thessalonians', '2th': '2 Thessalonians',
  'tim': '1 Timothy', '1tim': '1 Timothy', '1ti': '1 Timothy',
  '2tim': '2 Timothy', '2ti': '2 Timothy',
  'titus': 'Titus',
  'philem': 'Philemon', 'phm': 'Philemon',
  'heb': 'Hebrews',
  'jam': 'James', 'jas': 'James',
  'pet': '1 Peter', '1pet': '1 Peter', '1pe': '1 Peter',
  '2pet': '2 Peter', '2pe': '2 Peter',
  '1jn': '1 John', '1jo': '1 John',
  '2jn': '2 John', '2jo': '2 John',
  '3jn': '3 John', '3jo': '3 John',
  'jude': 'Jude',
  'rev': 'Revelation', 're': 'Revelation',
};

const bookWeights = {
  "Psalms": 5, "Proverbs": 4,
  "John": 4, "Genesis": 3, "Isaiah": 3,
  "Matthew": 3, "Luke": 3, "Romans": 3,
  "Ephesians": 2, "Philippians": 2, "Revelation": 2,
};

class ParsedReference {
  final String book;
  final int chapter;
  final int? verseStart;
  final int? verseEnd;
  final bool featured;

  ParsedReference({
    required this.book,
    required this.chapter,
    this.verseStart,
    this.verseEnd,
    this.featured = false,
  });
}

String? normalizeBook(String name) {
  var cleaned = name.trim().toLowerCase();

  if (bookAliases.containsKey(cleaned)) return bookAliases[cleaned];

  final noSpace = cleaned.replaceAll(RegExp(r'\s+'), '');
  if (bookAliases.containsKey(noSpace)) return bookAliases[noSpace];

  for (final b in bookNames) {
    if (b.toLowerCase() == cleaned) return b;
  }

  for (final b in bookNames) {
    if (b.toLowerCase().startsWith(cleaned)) return b;
  }

  return null;
}

final _refPattern = RegExp(
  r'^(\d?\s*[A-Za-z][A-Za-z\s]*)\s+(\d+)(?::\s*(\d+))?(?:\s*-\s*(\d+))?\s*$',
  caseSensitive: false,
);

ParsedReference? parseReference(String ref) {
  ref = ref.trim();
  if (ref.isEmpty || ref.startsWith('#')) return null;

  final featured = ref.startsWith('!');
  if (featured) ref = ref.substring(1).trim();

  final m = _refPattern.firstMatch(ref);
  if (m == null) return null;

  final bookRaw = m.group(1)!.trim();
  final chapter = int.parse(m.group(2)!);
  final vs = m.group(3) != null ? int.tryParse(m.group(3)!) : null;
  final ve = m.group(4) != null ? int.tryParse(m.group(4)!) : vs;

  final book = normalizeBook(bookRaw);
  if (book == null) return null;

  return ParsedReference(
    book: book,
    chapter: chapter,
    verseStart: vs,
    verseEnd: ve,
    featured: featured,
  );
}

List<ParsedReference> loadCurated(String path) {
  final f = File(path);
  if (!f.existsSync()) return [];

  final refs = <ParsedReference>[];
  for (final line in f.readAsLinesSync()) {
    final p = parseReference(line);
    if (p != null) refs.add(p);
  }
  return refs;
}

class Verse {
  final String book;
  final int chapter;
  final int verse;
  final String text;

  Verse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });
}

class Bible {
  final String path;
  Map<String, Map<int, Map<int, String>>> books = {};
  bool isLoaded = false;

  Bible(this.path) {
    _load();
  }

  void _load() {
    final f = File(path);
    if (!f.existsSync()) return;
    try {
      final raw = jsonDecode(f.readAsStringSync());
      if (raw is List) {
        _parseList(raw);
      } else if (raw is Map) {
        _parseMap(raw.cast<String, dynamic>());
      } else {
        stderr.writeln('Unrecognized Bible JSON format');
        return;
      }
      isLoaded = true;
    } catch (e) {
      stderr.writeln('Error loading Bible: $e');
    }
  }

  void _parseList(List<dynamic> data) {
    for (final book in data) {
      final name = book['name'] as String;
      final chapters = book['chapters'] as List<dynamic>;
      var canon = name;
      for (final n in bookNames) {
        if (n.toLowerCase() == name.toLowerCase()) {
          canon = n;
          break;
        }
      }
      books[canon] = {};
      for (var ci = 0; ci < chapters.length; ci++) {
        final ch = ci + 1;
        final verses = chapters[ci] as List<dynamic>;
        books[canon]![ch] = {};
        for (var vi = 0; vi < verses.length; vi++) {
          books[canon]![ch]![vi + 1] = verses[vi] as String;
        }
      }
    }
  }

  void _parseMap(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      var canon = entry.key;
      for (final n in bookNames) {
        if (n.toLowerCase() == entry.key.toLowerCase()) {
          canon = n;
          break;
        }
      }

      books[canon] = {};
      final chapters = entry.value as Map<String, dynamic>;
      for (final chEntry in chapters.entries) {
        final ch = int.parse(chEntry.key);
        books[canon]![ch] = {};
        final verses = chEntry.value as Map<String, dynamic>;
        for (final vEntry in verses.entries) {
          books[canon]![ch]![int.parse(vEntry.key)] = vEntry.value as String;
        }
      }
    }
  }

  List<Verse> lookup(ParsedReference ref) {
    final bookData = books[ref.book];
    if (bookData == null) return [];

    final chapterData = bookData[ref.chapter];
    if (chapterData == null) return [];

    final result = <Verse>[];
    final verseNums = chapterData.keys.toList()..sort();

    if (ref.verseStart != null) {
      final start = ref.verseStart!;
      final end = ref.verseEnd ?? start;
      for (final v in verseNums) {
        if (v >= start && v <= end) {
          result.add(Verse(
            book: ref.book,
            chapter: ref.chapter,
            verse: v,
            text: chapterData[v]!,
          ));
        }
      }
    } else {
      for (final v in verseNums) {
        result.add(Verse(
          book: ref.book,
          chapter: ref.chapter,
          verse: v,
          text: chapterData[v]!,
        ));
      }
    }

    return result;
  }

  List<Verse> randomPassage({int maxVerses = 5}) {
    if (books.isEmpty) return [];

    final rng = Random();

    final bookList = books.keys.toList();
    final weights = bookList.map((b) {
      final w = bookWeights[b] ?? 1;
      return w * books[b]!.length;
    }).toList();

    final total = weights.fold(0, (a, b) => a + b);
    var roll = rng.nextDouble() * total;
    var selectedBook = bookList.first;
    for (var i = 0; i < bookList.length; i++) {
      roll -= weights[i];
      if (roll <= 0) {
        selectedBook = bookList[i];
        break;
      }
    }

    final chapters = books[selectedBook]!.keys.toList()..sort();
    final chapter = chapters[rng.nextInt(chapters.length)];

    final verseDict = books[selectedBook]![chapter]!;
    final verseNums = verseDict.keys.toList()..sort();

    final mlen = maxVerses < verseNums.length ? maxVerses : verseNums.length;
    var length = 1;
    while (length < mlen && rng.nextDouble() < 0.35) {
      length++;
    }

    final start = rng.nextInt(verseNums.length - length + 1);
    final selected = verseNums.sublist(start, start + length);

    return selected.map((v) => Verse(
      book: selectedBook,
      chapter: chapter,
      verse: v,
      text: verseDict[v]!,
    )).toList();
  }
}
