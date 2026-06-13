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

  final featured = <int>[];
  final normal = <int>[];
  for (var i = 0; i < curatedRefs.length; i++) {
    if (curatedRefs[i].featured) featured.add(i); else normal.add(i);
  }
  normal.shuffle();
  cursor = 0;
  historyIndex = null;

  final port = sandbox.get('port', 4281) as int;
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stderr.writeln('Server running at http://localhost:${server.port}');

  await for (final request in server) {
    final path = request.uri.path;
    if (path == '/') {
      _servePage(request);
    } else if (path == '/api/passage') {
      _servePassage(request, request.uri.queryParameters);
    } else if (path == '/api/lookup') {
      _serveLookup(request, request.uri.queryParameters);
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
      if (r.verseEnd != null && r.verseEnd != r.verseStart) s += '-${r.verseEnd}';
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
  final passage = bible.isLoaded ? bible.lookup(ref) : <Verse>[];
  final text = formatPassage(passage, lineByLine: line, numbered: number, showNotes: showNotes);

  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({
    'index': cursor,
    'total': curatedRefs.length,
    'text': text,
    'ref': passage.isNotEmpty ? '${passage.first.book} ${passage.first.chapter}:${passage.first.verse}' : '${ref.book} ${ref.chapter}:${ref.verseStart}',
  }));
  request.response.close();
}

void _serveLookup(HttpRequest request, Map<String, String> params) {
  final refStr = params['ref'] ?? '';
  if (refStr.isEmpty) {
    request.response.statusCode = 400;
    request.response.write(jsonEncode({'error': 'No reference provided'}));
    request.response.close();
    return;
  }

  final parsed = parseReference('!$refStr');
  if (parsed == null) {
    request.response.write(jsonEncode({'error': 'Could not parse: $refStr'}));
    request.response.close();
    return;
  }

  final passage = bible.isLoaded ? bible.lookup(parsed) : <Verse>[];
  final line = params['line'] == '1';
  final number = params['number'] == '1';
  final showNotes = params['notes'] == '1';
  final text = formatPassage(passage, lineByLine: line, numbered: number, showNotes: showNotes);

  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode({
    'text': text,
    'ref': passage.isNotEmpty ? '${passage.first.book} ${passage.first.chapter}:${passage.first.verse}' : refStr,
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
.lookup{display:flex;gap:.5rem;align-items:center;margin-bottom:1rem;flex-shrink:0}
.lookup input{flex:1;padding:.5rem .8rem;font-size:1rem;border:1px solid #ccc;border-radius:4px;font-family:inherit}
.lookup button{background:#1a1a1a;color:#fff;border:none;padding:.5rem 1rem;font-size:1rem;cursor:pointer;border-radius:4px}
.lookup button:hover{background:#333}
.selector{margin-bottom:1rem;flex-shrink:0}
.selector select{width:100%;padding:.5rem .8rem;font-size:.9rem;border:1px solid #ccc;border-radius:4px;font-family:inherit;background:#fff}
.controls{display:flex;gap:.5rem;align-items:center;justify-content:center;margin-top:1rem;flex-wrap:wrap;flex-shrink:0}
.controls button{background:#1a1a1a;color:#fff;border:none;padding:.5rem 1rem;font-size:1rem;cursor:pointer;border-radius:4px;min-width:50px}
.controls button:hover{background:#333}
.controls button:disabled{opacity:.3;cursor:default}
#refreshBtn{background:transparent;border:1px solid #ccc;color:#666;padding:.5rem .8rem;font-size:.9rem}
#refreshBtn:hover{background:#eee}
#copyBtn{background:transparent;border:1px solid #ccc;color:#666;padding:.5rem .8rem;font-size:1rem;cursor:pointer;border-radius:4px}
#copyBtn:hover{background:#eee}
#counter{font-size:.85rem;color:#888;padding:0 .5rem;min-width:5rem;text-align:center}
.toggles{display:flex;gap:1rem;justify-content:center;margin-top:.75rem;flex-wrap:wrap;flex-shrink:0}
.toggles label{font-size:.85rem;color:#666;cursor:pointer;display:flex;align-items:center;gap:.3rem}
.toggles input{cursor:pointer}
footer{text-align:center;color:#aaa;font-size:.75rem;padding:1rem;flex-shrink:0}
</style>
</head>
<body>
<main>
<div class="lookup">
<input type="text" id="refInput" placeholder="Enter passage (e.g. John 3:16)" onkeydown="if(event.key==='Enter')lookupRef()">
<button onclick="lookupRef()">Go</button>
</div>
<div class="selector">
<select id="selector" onchange="goToSelector()">
<option value="">Browse curated...</option>
</select>
</div>
<div id="ref"></div>
<div id="text"></div>
<div class="controls">
<button id="prev" onclick="nav(-1)">←</button>
<button id="next" onclick="nav(1)">→</button>
<button id="refreshBtn" onclick="refreshNow()">↻</button>
<button id="copyBtn" onclick="copyPassage()">⧉</button>
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
var current = 0, total = 0, savedText = '';

function params() {
  return 'line='+(document.getElementById('lineToggle').checked?1:0)
       + '&number='+(document.getElementById('numToggle').checked?1:0)
       + '&notes='+(document.getElementById('notesToggle').checked?1:0);
}

function load() {
  var rand = document.getElementById('randToggle').checked ? 1 : 0;
  fetch('/api/passage?'+params()+'&random='+rand+'&_='+Date.now())
    .then(function(r){return r.json()}).then(function(d){current=d.index;total=d.total;savedText=d.text;render(d)});
}

function refreshNow() {
  var rand = document.getElementById('randToggle').checked;
  if (rand) {
    load();
  } else {
    fetch('/api/passage?dir=goto&i='+current+'&'+params()+'&_='+Date.now())
      .then(function(r){return r.json()}).then(function(d){current=d.index;total=d.total;savedText=d.text;render(d)});
  }
}

function nav(dir) {
  var rand = document.getElementById('randToggle').checked ? 1 : 0;
  if (dir === 0 || rand) {
    fetch('/api/passage?random=1&'+params()+'&_='+Date.now())
      .then(function(r){return r.json()}).then(function(d){current=d.index;total=d.total;savedText=d.text;render(d)});
    return;
  }
  var d = dir < 0 ? 'prev' : 'next';
  fetch('/api/passage?dir='+d+'&'+params()+'&_='+Date.now())
    .then(function(r){return r.json()}).then(function(d){current=d.index;total=d.total;savedText=d.text;render(d)});
}

function lookupRef() {
  var ref = document.getElementById('refInput').value.trim();
  if (!ref) return;
  fetch('/api/lookup?ref='+encodeURIComponent(ref)+'&'+params()+'&_='+Date.now())
    .then(function(r){return r.json()}).then(function(d){
      if (d.error) { document.getElementById('ref').textContent = d.error; document.getElementById('text').textContent = ''; return; }
      document.getElementById('ref').textContent = d.ref || '';
      document.getElementById('text').textContent = d.text.split('\\n\\n').slice(1).join('\\n\\n') || d.text;
      document.getElementById('counter').textContent = '';
      savedText = d.text;
    });
}

function goToSelector() {
  var sel = document.getElementById('selector');
  var idx = parseInt(sel.value);
  if (isNaN(idx)) return;
  fetch('/api/passage?dir=goto&i='+idx+'&'+params()+'&_='+Date.now())
    .then(function(r){return r.json()}).then(function(d){current=d.index;total=d.total;savedText=d.text;render(d)});
  document.getElementById('randToggle').checked = false;
}

function render(d) {
  var parts = d.text.split('\\n\\n');
  document.getElementById('ref').textContent = parts[0] || '';
  document.getElementById('text').textContent = parts.slice(1).join('\\n\\n') || '';
  document.getElementById('counter').textContent = (d.index + 1) + ' / ' + d.total;
  document.getElementById('prev').disabled = d.index === 0;
}

function copyPassage() {
  var ref = document.getElementById('ref').textContent;
  var text = document.getElementById('text').textContent;
  var full = ref + '\\n\\n' + text;
  navigator.clipboard.writeText(full).then(function() {
    var btn = document.getElementById('copyBtn');
    btn.textContent = '\\u2713';
    setTimeout(function() { btn.textContent = '\\u29C9'; }, 1500);
  });
}

// Toggles do NOT trigger API calls — they only affect the next load/refresh
// Refresh button handles the actual data fetch

document.addEventListener('keydown', function(e) {
  if (e.key === 'ArrowLeft') nav(-1);
  if (e.key === 'ArrowRight') nav(1);
  if (e.key === 'r' || e.key === 'R') refreshNow();
});

// Populate selector
fetch('/api/list?_='+Date.now()).then(function(r){return r.json()}).then(function(refs){
  var sel = document.getElementById('selector');
  for (var i = 0; i < refs.length; i++) {
    var opt = document.createElement('option');
    opt.value = i;
    opt.textContent = (i+1)+'. '+refs[i];
    sel.appendChild(opt);
  }
});

load();
</script>
</body>
</html>
''';