import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every reading title has a complete listening edition and picture questions', () {
    final books = jsonDecode(
      File('assets/toddler/catalog.json').readAsStringSync(),
    ) as List;
    final reading = jsonDecode(
      File('assets/books/catalog.json').readAsStringSync(),
    ) as List;
    expect(
      books.map((dynamic b) => b['id']).toSet(),
      reading.map((dynamic b) => b['id']).toSet(),
    );
    expect(books.map((dynamic b) => b['id']).toSet().length, books.length);
    for (final dynamic book in books) {
      final pages = book['pages'] as List;
      final questions = book['questions'] as List;
      expect(pages, isNotEmpty);
      expect(book['version'], greaterThanOrEqualTo(2));
      expect(book['textPolicy'], 'verbatim');
      expect(book['attribution'], isNotEmpty);
      expect(book['adaptationNote'], isNotEmpty);
      final source = reading.singleWhere((dynamic b) => b['id'] == book['id']);
      final sourceText = (source['pages'] as List)
          .map((dynamic p) => p['text'] as String)
          .join(' ')
          .split(RegExp(r'\s+'))
          .join(' ')
          .trim();
      expect(
        pages.map((dynamic p) => p['text']).join(' '),
        sourceText,
        reason: '${book['id']} must preserve the complete original text',
      );
      for (var start = 0; start < pages.length; start += 3) {
        final end = (start + 3).clamp(0, pages.length);
        expect(
          questions.where((dynamic q) => q['afterPage'] == end - 1).length,
          end - start == 1 ? 1 : 2,
        );
      }
      for (final dynamic page in pages) {
        expect(page['sourcePages'], isNotEmpty);
        expect(
          page['text'],
          sourceText.substring(
            page['sourceTextStart'] as int,
            page['sourceTextEnd'] as int,
          ),
        );
        expect(File(page['image'] as String).existsSync(), isTrue);
      }
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i] as Map;
        final checkpoint = ((i ~/ 2 + 1) * 3 - 1).clamp(0, pages.length - 1);
        expect(q['afterPage'], checkpoint);
        expect((q['choices'] as List).length, 2);
        expect(q['answer'], i % 2);
        final choices = q['choices'] as List;
        expect(
          choices
              .map((dynamic c) => '${c['image']}:${c['cell']}')
              .toSet()
              .length,
          2,
        );
        for (final dynamic choice in q['choices']) {
          expect(choice['label'], isNotEmpty);
          expect(File(choice['image'] as String).existsSync(), isTrue);
        }
        for (final field in ['prompt', 'hint', 'guided', 'feedback']) {
          expect(q[field], isNotEmpty);
        }
        final groupStart = checkpoint ~/ 3 * 3;
        final passage = pages
            .sublist(groupStart, checkpoint + 1)
            .map((dynamic p) => p['text'])
            .join(' ');
        final evidence = q['evidence'] as Map;
        expect(evidence['quote'], isNotEmpty);
        expect(passage, contains(evidence['quote']), reason: q['id'] as String);
        final groupIds = pages
            .sublist(groupStart, checkpoint + 1)
            .map((dynamic p) => p['id'])
            .toSet();
        expect(evidence['pageIds'], isNotEmpty);
        expect(groupIds.containsAll(evidence['pageIds'] as List), isTrue);
      }
    }
  });
  test('every narration and recovery clip is bundled and versioned', () {
    final books = jsonDecode(
      File('assets/toddler/catalog.json').readAsStringSync(),
    ) as List;
    final manifest = jsonDecode(
      File('assets/toddler/audio_manifest.json').readAsStringSync(),
    ) as Map;
    final clips = <String>[];
    final profiles = <String, Map>{};
    for (final dynamic book in books) {
      final russian = book['language'] == 'ru';
      expect(
        book['model'],
        russian
            ? 'google/gemini-3.8-flash-lite-tts'
            : 'qwen/qwen-audio-3.0-tts-plus',
      );
      expect(book['voice'], russian ? 'Sulafat' : 'longanlingxin');
      profiles[book['id'] as String] = book as Map;
      for (final dynamic page in book['pages']) {
        clips.add(page['audio'] as String);
      }
      for (final dynamic q in book['questions']) {
        clips.addAll((q['audio'] as Map).values.cast<String>());
      }
      clips.add(book['completion']['audio'] as String);
    }
    expect(clips.toSet().length, clips.length);
    for (final path in clips) {
      expect(path, startsWith('assets/books/'));
      final owner = profiles[path.split('/')[2]]!;
      expect(path, startsWith('assets/books/${owner['id']}/audio/'));
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(manifest.containsKey(path), isTrue, reason: path);
      expect(File(path).lengthSync(), manifest[path]['bytes']);
      expect(
        sha256.convert(File(path).readAsBytesSync()).toString(),
        manifest[path]['sha256'],
      );
      expect(manifest[path]['model'], owner['model']);
      expect(manifest[path]['voice'], owner['voice']);
    }
  });
}
