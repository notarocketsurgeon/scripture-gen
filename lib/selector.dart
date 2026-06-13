import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:passage_of_the_day/bible.dart';
import 'package:passage_of_the_day/config.dart';

List<Verse> selectPassage(Bible bible, Sandbox sandbox) {
  final curatedRefs = loadCurated(sandbox.curatedPath);
  final cw = (sandbox.get('curated_weight', 0.3) as num).toDouble();
  final rng = Random();

  final useCurated = curatedRefs.isNotEmpty &&
      (!bible.isLoaded || rng.nextDouble() < cw);

  if (useCurated) {
    return _selectCurated(curatedRefs, bible, sandbox);
  } else if (bible.isLoaded) {
    final maxV = sandbox.get('max_verses', 5) as int;
    return bible.randomPassage(maxVerses: maxV);
  } else {
    return [];
  }
}

List<Verse> _selectCurated(
  List<ParsedReference> refs,
  Bible bible,
  Sandbox sandbox,
) {
  final stateFile = File(sandbox.statePath);
  Map<String, dynamic> state = {};

  if (stateFile.existsSync()) {
    try {
      state = jsonDecode(stateFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {}
  }

  List<int> order;
  if (state.containsKey('order') &&
      (state['order'] as List).length == refs.length) {
    order = (state['order'] as List).cast<int>();
  } else {
    final featured = <int>[];
    final normal = <int>[];
    for (var i = 0; i < refs.length; i++) {
      if (refs[i].featured) {
        featured.add(i);
      } else {
        normal.add(i);
      }
    }
    normal.shuffle();
    order = [...featured, ...normal];
  }

  var cursor = state['cursor'] as int? ?? 0;
  if (cursor >= order.length) {
    cursor = 0;
  }

  final idx = order[cursor];
  cursor++;

  stateFile.writeAsStringSync(jsonEncode({'order': order, 'cursor': cursor}));

  final ref = refs[idx];

  if (bible.isLoaded) {
    final passage = bible.lookup(ref);
    if (passage.isNotEmpty) return passage;
  }

  var refStr = '${ref.book} ${ref.chapter}';
  if (ref.verseStart != null) {
    refStr += ':${ref.verseStart}';
    if (ref.verseEnd != null && ref.verseEnd != ref.verseStart) {
      refStr += '-${ref.verseEnd}';
    }
  }

  return [
    Verse(
      book: ref.book,
      chapter: ref.chapter,
      verse: ref.verseStart ?? 0,
      text: '[$refStr - Bible text not loaded]',
    ),
  ];
}
