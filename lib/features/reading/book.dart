import 'dart:convert';

import 'package:flutter/services.dart';

class Question {
  const Question({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.hint,
    this.explanation = '',
  });
  factory Question.fromJson(Map<String, dynamic> j) => Question(
    prompt: j['prompt'] as String,
    options: List<String>.from(j['options'] as List),
    answer: j['answer'] as int,
    hint: j['hint'] as String,
    explanation: j['explanation'] as String? ?? '',
  );
  final String prompt, hint, explanation;
  final List<String> options;
  final int answer;
}

class BookPage {
  const BookPage({required this.text, required this.sourcePage, this.image});
  factory BookPage.fromJson(Map<String, dynamic> j) => BookPage(
    text: j['text'] as String,
    sourcePage: j['sourcePage'] as int,
    image: j['image'] as String?,
  );
  final String text;
  final String? image;
  final int sourcePage;
}

class BookBatch {
  const BookBatch({
    required this.startPage,
    required this.endPage,
    required this.questions,
  });
  factory BookBatch.fromJson(Map<String, dynamic> j) => BookBatch(
    startPage: j['startPage'] as int,
    endPage: j['endPage'] as int,
    questions: (j['questions'] as List)
        .map((q) => Question.fromJson(q as Map<String, dynamic>))
        .toList(),
  );
  final int startPage, endPage;
  final List<Question> questions;
  int get pageCount => endPage - startPage;
  Iterable<int> get pageIndices =>
      Iterable.generate(pageCount, (i) => startPage + i);
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.language,
    required this.attribution,
    required this.original,
    required this.cover,
    required this.pages,
    required this.batches,
  });
  factory Book.fromJson(Map<String, dynamic> j) => Book(
    id: j['id'] as String,
    title: j['title'] as String,
    author: j['author'] as String,
    language: j['language'] as String,
    attribution: j['attribution'] as String,
    original: j['original'] as String,
    cover: j['cover'] as String,
    pages: (j['pages'] as List)
        .map((p) => BookPage.fromJson(p as Map<String, dynamic>))
        .toList(),
    batches: (j['batches'] as List)
        .map((b) => BookBatch.fromJson(b as Map<String, dynamic>))
        .toList(),
  );
  final String id, title, author, language, attribution, original, cover;
  final List<BookPage> pages;
  final List<BookBatch> batches;
  BookBatch batchForPage(int page) => batches.firstWhere(
    (batch) => page >= batch.startPage && page < batch.endPage,
  );
}

abstract final class BookCatalog {
  static Future<List<Book>> load() async => (jsonDecode(
    await rootBundle.loadString('assets/books/catalog.json'),
  ) as List).map((j) => Book.fromJson(j as Map<String, dynamic>)).toList();
}
