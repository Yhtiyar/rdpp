import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../ui/components.dart';
import '../../ui/motion_spec.dart';
import '../../ui/theme.dart';

class ChildAgeSetting extends StatefulWidget {
  const ChildAgeSetting({super.key, required this.controller});

  final AppController controller;

  @override
  State<ChildAgeSetting> createState() => _ChildAgeSettingState();
}

class _ChildAgeSettingState extends State<ChildAgeSetting> {
  static const _categories = [
    (4, '4–6', 'Read together', 'Читайте вместе', 'book', WinTheme.peach),
    (
      7,
      '7–9',
      'Explore every story',
      'Открывайте истории',
      'age_middle',
      WinTheme.mint,
    ),
    (
      10,
      '10–12',
      'Think bigger',
      'Узнавайте больше',
      'age_older',
      WinTheme.lavender,
    ),
  ];

  bool _saving = false;
  bool _failed = false;
  AppController get c => widget.controller;

  Future<void> _select(int age) async {
    if (_saving || age == c.age) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await c.setAge(age);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = _categories.firstWhere(
      (category) => category.$1 == c.age,
      orElse: () => _categories[1],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          c.tr('Child’s age', 'Возраст ребёнка'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        smallGap,
        AnimatedContainer(
          duration: MotionSpec.of(context).selection,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: category.$6,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tr('Ages ${category.$2}', '${category.$2} лет'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    smallGap,
                    Text(c.tr(category.$3, category.$4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: MotionSpec.of(context).selection,
                child: Art(
                  category.$5,
                  key: ValueKey(category.$1),
                  width: 78,
                  height: 78,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            for (final option in _categories)
              ButtonSegment(
                value: option.$1,
                label: Semantics(
                  label: c.tr('Ages ${option.$2}', '${option.$2} лет'),
                  excludeSemantics: true,
                  child: Text(option.$2),
                ),
              ),
          ],
          selected: {category.$1},
          showSelectedIcon: false,
          onSelectionChanged: _saving ? null : (ages) => _select(ages.first),
        ),
        smallGap,
        Text(
          c.tr(
            'Change this as they grow. Their progress stays saved.',
            'Меняйте по мере взросления. Прогресс ребёнка сохранится.',
          ),
        ),
        if (_failed) ...[
          smallGap,
          Semantics(
            liveRegion: true,
            child: Text(
              c.tr(
                'Age could not be saved. Please try again.',
                'Не удалось сохранить возраст. Попробуйте ещё раз.',
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
