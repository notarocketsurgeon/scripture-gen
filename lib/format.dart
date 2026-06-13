import 'package:passage_of_the_day/bible.dart';

String stripNotes(String text) {
  // Remove {notes} including any surrounding spaces, then normalize whitespace
  return text
      .replaceAll(RegExp(r'\s*\{[^}]*\}\s*'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String formatPassage(List<Verse> passage,
    {String version = 'KJV', bool lineByLine = false, bool numbered = false, bool showNotes = false}) {
  if (passage.isEmpty) return 'No passage selected.';

  final book = passage.first.book;
  final chapter = passage.first.chapter;
  final firstVerse = passage.first.verse;
  final lastVerse = passage.last.verse;

  final ref = firstVerse == lastVerse
      ? '$book $chapter:$firstVerse'
      : '$book $chapter:$firstVerse-$lastVerse';

  String verses;
  if (numbered && lineByLine) {
    verses = passage.map((v) {
      var t = showNotes ? v.text : stripNotes(v.text);
      return '${v.verse}  $t';
    }).join('\n');
  } else if (numbered) {
    verses = passage.map((v) {
      var t = showNotes ? v.text : stripNotes(v.text);
      return '${v.verse}  $t';
    }).join(' ');
  } else if (lineByLine) {
    verses = passage.map((v) => showNotes ? v.text : stripNotes(v.text)).join('\n');
  } else {
    verses = passage.map((v) => showNotes ? v.text : stripNotes(v.text)).join(' ');
  }

  if (!lineByLine) {
    verses = _wrap(verses, 72);
  }

  return '$ref ($version)\n\n$verses';
}

String _wrap(String text, int width) {
  final words = text.split(' ');
  final lines = <String>[];
  var current = '';

  for (final word in words) {
    if (current.length + word.length + 1 > width) {
      lines.add(current);
      current = word;
    } else {
      current = current.isEmpty ? word : '$current $word';
    }
  }
  if (current.isNotEmpty) lines.add(current);

  return lines.join('\n');
}