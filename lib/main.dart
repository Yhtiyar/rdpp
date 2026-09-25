import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_controller.dart';
import 'core/local_store.dart';
import 'features/reading/book.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(PreferencesStore());
  try {
    await controller.load();
    controller.books = await BookCatalog.load();
    await controller.refreshProtection();
    runApp(LittlewinsApp(controller: controller));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your saved data could not be opened. / Не удалось открыть данные.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: main,
                    child: const Text('Try again / Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
