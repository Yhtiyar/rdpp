# SDD ledger — plan: docs/superpowers/plans/2026-09-27-toddler-books.md
Ruling: Work in the existing feature branch without committing or moving user changes — it contains required unpublished MiMi assets; targeted edits preserve the user's current workspace — risk is shared-tree interference, addressed with focused diffs.
Ruling: Use a separate versioned listening preferences key — avoids introducing listening data into reading rewards and pending save snapshots — future parent reset must clear both namespaces.
Ruling: Use 12 adapted Frog Prince pages and 9 Колобок pages — permits complete three-page groups and preserves story events and endings — counts intentionally differ from the original English edition.
Pre-flight: Task 1 manifest paths consumed by Tasks 2/3, same schema; Task 2 engine observed by Task 3, injected audio/store; Task 4 checks original reading contract and actual asset playback. No interface conflicts.
Auditions: Qwen Plus longanlingxin returned HTTP200 audio/mpeg for English and Russian; ASR pending. API key stays outside bundles and logs.
Task 1: complete — 21 short pages, 14 questions, six generated English answer pictures in one atlas, existing Russian art reused; 79 Qwen Plus MP3s generated. Content and generator tests passed; cache dry run zero pending.
Task 2: complete — initial 5 engine tests passed; fresh review found load/dispose and adapter cancellation issues now covered by failing regression tests before fixes.
Task 3: implemented — Home/Library entry points and listening screen; compact widget test passed. Browser visual iteration removes tall empty frames around landscape artwork.
Final review: fresh reviewer found four Important issues: load-before-save data loss, queued cancellation, duplicate speaking routes, unhandled derived audio stream errors. Fix pass has reproducing tests and is in progress.
Final: minor (deferred): generator validates MP3 headers and hashes, not full decoding; current assets receive separate full browser decode audit before acceptance.
Final: minor (deferred): generator submits bounded concurrent requests upfront rather than aborting the queue on authentication/credit failure; estimated cost is capped including retries.
Review scope rulings: browser behavior, small-screen presentation and speech fidelity are assessed with browser evidence and sample ASR, not inferred from source review. Human voice preference remains subjective; no claim of a native-speaker listening review.

Final: fixed load-before-save — delayed/read-failing store regressions RED→GREEN; full Flutter suite 88/88.
Final: fixed audio start cancellation and duplicated platform errors — adapter tests with held preparation and error broadcasts RED→GREEN.
Final: fixed duplicate routes and covered-route playback — guarded entry test; covered-route and delayed-covered-load tests RED→GREEN.
Task 4: final verification in progress — full tests 88/88, generator 4/4, release build successful; both-book browser and original reading regression running against final assets. Original browser and recovery runs passed, all79 MP3s decode.
No commits/pushes/merges made; current feature branch and user changes retained. Working ledger kept with uncommitted work so progress remains recoverable.

Task 4: complete — final release browser runs passed for both narrated books (52 real end events), all79 MP3 decode checks, five recovery checks, and the existing reading/rewards browser regression. Final static analysis clean, Flutter suite88/88, Python generator4/4, final content2/2; key absent from final bundle; cache zero stale clips.
