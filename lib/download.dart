import 'dart:convert';
import 'dart:io';

const kjvUrls = [
  'https://raw.githubusercontent.com/thiagobodruk/bible/master/json/en_kjv.json',
  'https://raw.githubusercontent.com/scrollmapper/bible_databases/master/json/en_kjv.json',
];

Future<bool> downloadKJV(String targetPath) async {
  final target = File(targetPath);
  target.parent.createSync(recursive: true);

  for (final url in kjvUrls) {
    try {
      stderr.writeln('  Downloading KJV Bible from $url...');

      final uri = Uri.parse(url);
      final client = HttpClient();
      client.userAgent = 'PassageOfTheDay/0.1';

      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        stderr.writeln('  HTTP ${response.statusCode}');
        client.close();
        continue;
      }

      final content = await response.transform(utf8.decoder).join();
      final data = jsonDecode(content);

      target.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      stderr.writeln('  Saved to $targetPath');
      client.close();
      return true;
    } catch (e) {
      stderr.writeln('  Failed: $e');
    }
  }

  stderr.writeln('  Could not download KJV from any source.');
  return false;
}
