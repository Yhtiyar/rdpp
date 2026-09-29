import 'dart:convert';

import 'package:flutter/services.dart';

class ListeningPage {
  ListeningPage.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      text = j['text'] as String,
      image = j['image'] as String,
      imageAspectRatio = (j['imageAspectRatio'] as num?)?.toDouble(),
      audio = j['audio'] as String;
  final String id, text, image, audio;
  final double? imageAspectRatio;
}

class PictureChoice {
  PictureChoice.fromJson(Map<String, dynamic> j)
    : label = j['label'] as String,
      image = j['image'] as String,
      cell = j['cell'] as int?;
  final String label, image;
  // A cell in a three-column, two-row illustration atlas.
  final int? cell;
}

class ListeningQuestion {
  ListeningQuestion.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      afterPage = j['afterPage'] as int,
      prompt = j['prompt'] as String,
      hint = j['hint'] as String,
      guided = j['guided'] as String,
      feedback = j['feedback'] as String,
      answer = j['answer'] as int,
      audio = Map<String, String>.from(j['audio'] as Map),
      choices = (j['choices'] as List)
          .map((dynamic c) => PictureChoice.fromJson(c as Map<String, dynamic>))
          .toList();
  final String id, prompt, hint, guided, feedback;
  final int afterPage, answer;
  final Map<String, String> audio;
  final List<PictureChoice> choices;
  String textFor(String kind) => switch (kind) {
    'hint' => hint,
    'guided' => guided,
    'feedback' => feedback,
    _ => prompt,
  };
}

class ListeningBook {
  ListeningBook.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      title = j['title'] as String,
      language = j['language'] as String,
      attribution = j['attribution'] as String,
      adaptationNote = j['adaptationNote'] as String,
      version = j['version'] as int,
      playbackRate = (j['playbackRate'] as num?)?.toDouble() ?? .85,
      pages = (j['pages'] as List)
          .map((dynamic p) => ListeningPage.fromJson(p as Map<String, dynamic>))
          .toList(),
      questions = (j['questions'] as List)
          .map(
            (dynamic q) =>
                ListeningQuestion.fromJson(q as Map<String, dynamic>),
          )
          .toList(),
      completionAudio = (j['completion'] as Map)['audio'] as String,
      completionText = (j['completion'] as Map)['text'] as String;
  final String id,
      title,
      language,
      attribution,
      adaptationNote,
      completionAudio,
      completionText;
  final int version;
  final double playbackRate;
  final List<ListeningPage> pages;
  final List<ListeningQuestion> questions;
  String tr(String en, String ru) => language == 'ru' ? ru : en;
}

abstract final class ListeningCatalog {
  static Future<List<ListeningBook>>? _loaded;
  static Future<List<ListeningBook>> load() => _loaded ??= _load();
  static Future<List<ListeningBook>> _load() async {
    try {
      return (jsonDecode(
            await rootBundle.loadString('assets/toddler/catalog.json'),
          ) as List)
          .map((dynamic j) => ListeningBook.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _loaded = null;
      rethrow;
    }
  }
}
