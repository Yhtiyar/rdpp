# Parent age category

Parents can select ages 4–6, 7–9 or 10–12 under **Your settings → Child’s age** after entering their PIN. The setting saves immediately; changing it preserves reading progress, coins, the parent PIN and other settings. A failed save restores the previous category and offers a retry message.

The setting updates the existing age profile. The current book catalogue remains available to every category.

Validation:

- `flutter test --no-pub --reporter expanded`: all 90 tests passed, including category persistence, preservation of progress and failed-save recovery.
- `flutter analyze --no-pub`: no issues.
- Release Flutter web build and `node tools/parent_age_web_check.cjs`: all categories, PIN access, reload persistence, English and Russian, 320px phone, 430px phone, 1365px desktop and reduced motion. No browser errors.
- Screenshots reviewed for layout and consistency with the existing palette, illustrations and typography.

Run the web checks against a locally served build using `APP_URL=http://127.0.0.1:7361 node tools/parent_age_web_check.cjs`. The harness seeds a local test profile with a test PIN and one completed page. Detailed results are in [checks.json](checks.json).

Screenshots: [phone](02-age-4-430.png), [small phone](03-age-320.png), [Russian](04-age-russian-320.png), [desktop](05-age-russian-desktop.png).
