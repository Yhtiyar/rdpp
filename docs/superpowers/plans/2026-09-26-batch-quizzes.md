# Three-page reading quizzes

Implement inline with the Flutter and executing-plans skills.

Purpose: replace page-by-page questions with button-started quizzes after three read
pages, at least four answer options, bounded attempts, and persisted anti-spam
progress. Questions remain offline and in each book's original language.

Confirmed by the user: two attempts total per question; a
session is the current batch, and three errors reset that batch, not already
verified pages/rewards. An exhausted question advances without credit; if the
quiz ends with an exhausted question, rereading is required. All four questions
must be passed to verify the batch. The last shorter batch also gets four
questions. Existing earned pages/coins survive migration, and only newly
verified pages earn 10 coins each.

- [x] Author and validate four source-grounded, four-option questions per batch
      for both books; update the catalog generator and model.
- [x] Persist batch reading, question attempts and errors. Gate sequential
      reading, count all wrong submissions, reset on three errors, reward only
      passed batches, and prevent duplicate rewards and concurrent submissions.
- [x] Update reader/quiz UI: offer Start test at batch end, offer Continue test for unfinished quizzes,
      show attempt/error counts, exhaustion, reset and batch reward screens.
- [x] Test persistence across restart, contents/back navigation, final partial
      batch, migration, failed saves, duplicate submits and rewards. Update web
      smoke flow; run analyzer, tests, web build and browser checks.
- [x] Review final changes against the four user requirements.

Preserve unrelated icon, CI and signing changes. No MobAI or device operations.

Follow-up: the user requested manual quiz launch. Reading, scrolling and reopening
a book must never push the quiz route; only Start test / Continue test does.
