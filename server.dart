import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:passage_of_the_day/bible.dart';
import 'package:passage_of_the_day/config.dart';
import 'package:passage_of_the_day/download.dart';
import 'package:passage_of_the_day/format.dart';

final sandbox = Sandbox(findSandbox('default'));
late Bible bible;
List<ParsedReference> curatedRefs = [];
int cursor = 0;
int? historyIndex;

void main() async {
  // Load Bible
  bible = Bible(sandbox.biblePath);
  if (!bible.isLoaded) {
    stderr.writeln('Bible not loaded. Downloading...');
    await downloadKJV(sandbox.biblePath);
    bible = Bible(sandbox.biblePath);
  }

  curatedRefs = loadCurated(sandbox.curatedPath);
  if (curatedRefs.isEmpty) {
    stderr.writeln('No curated passages found.');
    return;
  }

  // Shuffle non-featured
  final featured = <int>[];
  final normal = <int>[];
  for (var i = 0; i < curatedRefs.length; i++) {
    if (curatedRefs[i].featured) {
      featured.add(i);
    } else {
      normal.add(i);
    }
  }
  normal.shuffle();
  cursor = 0;
  historyIndex = null;

  final port = sandbox.get('port', 0) as int;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  final actualPort = server.port;
  stderr.writeln('Server running at http://localhost:$actualPort');

  await for (final request in server) {
    final path = request.uri.path;
    if (path == '/') {
      _servePage(request);
    } else if (path == '/api/passage') {
      _servePassage(request, request.uri.queryParameters);
    } else if (path == '/api/list') {
      _serveList(request);
    } else {
      request.response.statusCode = 404;
      request.response.close();
    }
  }
}

void _servePage(HttpRequest request) {
  request.response.headers.contentType = ContentType.html;
  request.response.write(_html());
  request.response.close();
}

void _serveList(HttpRequest request) {
  final refs = curatedRefs.map((r) {
    var s = '${r.book} ${r.chapter}';
    if (r.verseStart != null) {
      s += ':${r.verseStart}';
      if (r.verseEnd != null && r.verseEnd != r.verseStart) {
        s += '-${r.verseEnd}';
      }
    }
    return s;
  }).toList();

  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(refs));
  request.response.close();
}

void _servePassage(HttpRequest request, Map<String, String> params) {
  final dir = params['dir'] ?? 'next';
  final line = params['line'] == '1';
  final number = params['number'] == '1';
  final random = params['random'] == '1';
  final showNotes = params['notes'] == '1';
  final rng = Random();

  if (random) {
    cursor = rng.nextInt(curatedRefs.length);
    historyIndex = cursor;
  } else if (dir == 'prev' && historyIndex != null && historyIndex! > 0) {
    historyIndex = historyIndex! - 1;
    cursor = historyIndex!;
  } else if (dir == 'next') {
    cursor++;
    historyIndex = cursor;
  } else if (dir == 'goto' && params.containsKey('i')) {
    cursor = int.parse(params['i']!);
    historyIndex = cursor;
  }

  if (cursor >= curatedRefs.length) cursor = 0;
  if (cursor < 0) cursor = 0;

  final ref = curatedRefs[cursor];
  final List<Verse> passage = bible.isLoaded ? bible.lookup(ref) : <Verse>[];
  final text = formatPassage(passage, lineByLine: line, numbered: number, showNotes: showNotes);

  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({
    'index': cursor,
    'total': curatedRefs.length,
    'text': text,
    'ref': passage.isNotEmpty
        ? '${passage.first.book} ${passage.first.chapter}:${passage.first.verse}'
        : '${ref.book} ${ref.chapter}:${ref.verseStart}',
  }));
  request.response.close();
}

String _html() => '''
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Passage of the Day</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Georgia,"Times New Roman",serif;background:#faf9f7;color:#1a1a1a;min-height:100vh;display:flex;flex-direction:column;align-items:center}
main{max-width:640px;width:100%;padding:2rem 1.5rem;flex:1;display:flex;flex-direction:column}
#ref{font-size:1.1rem;color:#555;margin-bottom:2rem;min-height:1.5rem}
#text{font-size:1.2rem;line-height:1.7;white-space:pre-wrap;min-height:8rem}
.controls{display:flex;gap:.5rem;align-items:center;justify-content:center;margin-top:2rem;flex-wrap:wrap;flex-shrink:0}
.controls button{background:#1a1a1a;color:#fff;border:none;padding:.5rem 1rem;font-size:1rem;cursor:pointer;border-radius:4px;min-width:60px}
.controls button:hover{background:#333}
.controls button:disabled{opacity:.3;cursor:default}
#counter{font-size:.85rem;color:#888;padding:0 .5rem;min-width:5rem;text-align:center}
.toggles{display:flex;gap:1rem;justify-content:center;margin-top:.75rem;flex-wrap:wrap;flex-shrink:0}
.toggles label{font-size:.85rem;color:#666;cursor:pointer;display:flex;align-items:center;gap:.3rem}
.toggles input{cursor:pointer}
footer{text-align:center;color:#aaa;font-size:.75rem;padding:1rem;flex-shrink:0}
</style>
</head>
<body>
<main>
<div id="ref"></div>
<div id="text"></div>
<div class="controls">
<button id="prev" onclick="nav(-1)">←</button>
<button id="next" onclick="nav(1)">→</button>
<button id="randBtn" onclick="nav(0)">↻</button>
<span id="counter"></span>
</div>
<div class="toggles">
<label><input type="checkbox" id="randToggle" checked> Random</label>
<label><input type="checkbox" id="lineToggle"> Line by line</label>
<label><input type="checkbox" id="numToggle"> Verse numbers</label>
<label><input type="checkbox" id="notesToggle"> Show notes</label>
</div>
</main>
<footer>Passage of the Day</footer>
<script>
let current = 0, total = 0;

function params() {
  return 'line='+(document.getElementById('lineToggle').checked?1:0)
       + '&number='+(document.getElementById('numToggle').checked?1:0)
       + '&notes='+(document.getElementById('notesToggle').checked?1:0);
}

function load() {
  const rand = document.getElementById('randToggle').checked ? 1 : 0;
  fetch('/api/passage?'+params()+'&random='+rand+'&_='+Date.now())
    .then(r=>r.json()).then(d=>{current=d.index;total=d.total;render(d)});
}

function refresh() {
  fetch('/api/passage?dir=goto&i='+current+'&'+params()+'&_='+Date.now())
    .then(r=>r.json()).then(d=>{current=d.index;total=d.total;render(d)});
}

function nav(dir) {
  const rand = document.getElementById('randToggle').checked ? 1 : 0;
  if (dir === 0 || rand) {
    fetch('/api/passage?random=1&'+params()+'&_='+Date.now())
      .then(r=>r.json()).then(d=>{current=d.index;total=d.total;render(d)});
    return;
  }
  const d = dir < 0 ? 'prev' : 'next';
  fetch('/api/passage?dir='+d+'&'+params()+'&_='+Date.now())
    .then(r=>r.json()).then(d=>{current=d.index;total=d.total;render(d)});
}

function render(d) {
  const parts = d.text.split('\\n\\n');
  document.getElementById('ref').textContent = parts[0] || '';
  document.getElementById('text').textContent = parts.slice(1).join('\\n\\n') || '';
  document.getElementById('counter').textContent = (d.index + 1) + ' / ' + d.total;
  document.getElementById('prev').disabled = d.index === 0;
}

document.getElementById('lineToggle').onchange = refresh;
document.getElementById('numToggle').onchange = refresh;
document.getElementById('notesToggle').onchange = refresh;
document.getElementById('randToggle').onchange = load;

document.addEventListener('keydown', e => {
  if (e.key === 'ArrowLeft') nav(-1);
  if (e.key === 'ArrowRight') nav(1);
  if (e.key === 'r' || e.key === 'R') nav(0);
});

load();
</script>
</body>
</html>
''';

