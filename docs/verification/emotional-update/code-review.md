# Independent review and resolution

Reviewer: final_review, read-only, one pass. No critical issues.

- Important: unreachable catalog still exposed purchase/earning copy. Fixed by hiding unavailable purchase controls and offering books; failing widget regression now passes.
- Important: remaining earning capacity below 100 was mistaken for completion. Fixed separate remaining-page message; literal one-page case tested.
- Important: celebrating/encouraging frames static. Fixed expression/paw sequences, stable final poses and reduced-motion behavior; frame sequence regression passes.
- Minor regraded Important: expired confirmed timer said ready. Fixed heading derives from remaining time; real purchase followed by clock advance reproduces and verifies fix.

Additional browser-discovered fixes: book title included in the single live announcement; accessible navigation no longer impersonates the reduced-motion setting; all MiMi frames preloaded and static face used during cold decoding. A hidden-app first sound-service initialization remains silent.

Declined-to-judge scope: native protection/haptics/perceived sound quality (not part of this Flutter web update); unrelated icon/CI/signing baseline (preserved); final browser evidence (collected by implementer); concurrent reward semantics fix (verified by regression test). No deferred code findings.
