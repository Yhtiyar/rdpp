import 'package:flutter/material.dart';

import 'package:readapp/ui/mimi_reading.dart';

/// Flutter web animation workbench; never part of the application routes.
void main() => runApp(const MaterialApp(home: _Preview()));

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  double? phase;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFFBFF),
    body: Center(
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiMiReading(progress: phase),
            const SizedBox(height: 24),
            Text(
              phase == null
                  ? 'Playing · 5 seconds'
                  : 'Pose ${phase!.toStringAsFixed(3)}',
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Exact phase'),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null) setState(() => phase = parsed.clamp(0, 1));
              },
            ),
            Slider(
              value: phase ?? 0,
              onChanged: (v) => setState(() => phase = v),
            ),
            Wrap(
              children: [
                for (final value in [
                  0.0,
                  .17,
                  .37,
                  .46,
                  .50,
                  .53,
                  .60,
                  .68,
                  .80,
                ])
                  TextButton(
                    onPressed: () => setState(() => phase = value),
                    child: Text(value.toStringAsFixed(2)),
                  ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => phase = null),
              child: const Text('Play loop'),
            ),
          ],
        ),
      ),
    ),
  );
}
