import 'package:flutter/material.dart';

import '../../core/batch_progress.dart';
import '../../ui/components.dart';
import '../../ui/theme.dart';

/// Saved result and child-controlled next step, independent of quiz mutations.
class QuizFeedbackPanel extends StatelessWidget {
  const QuizFeedbackPanel({
    super.key,
    required this.outcome,
    required this.message,
    required this.actionLabel,
    required this.onContinue,
  });
  final BatchAnswerOutcome outcome;
  final String message, actionLabel;
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) {
    final correct = outcome == BatchAnswerOutcome.correct;
    return Container(
      color: correct ? WinTheme.mint : WinTheme.peach,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Semantics(
                liveRegion: true,
                label: message,
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        correct
                            ? Icons.check_circle_rounded
                            : Icons.auto_stories_rounded,
                        color: correct ? WinTheme.green : WinTheme.purple,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          smallGap,
          WinButton(
            actionLabel,
            autofocus: true,
            onPressed: onContinue,
            icon: outcome == BatchAnswerOutcome.wrong
                ? Icons.refresh_rounded
                : Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}
