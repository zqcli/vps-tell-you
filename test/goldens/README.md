# Theme component references

`mobile_theme_light.png` and `mobile_theme_dark.png` render a small synthetic
ledger card with neutral/warning/error badges, cloud notices, an input and action
buttons. They deliberately retain Flutter's bundled Ahem test font, so these
references check deterministic shape, wrapping, padding and color rather than
system font rendering. They contain no user records, credentials or live data.

Regenerate deliberately with the repository's pinned Flutter SDK:

```sh
flutter test --update-goldens test/mobile_theme_test.dart
flutter test test/mobile_theme_test.dart
```

The same test file separately checks WCAG normal-text and control-outline
contrast, actual pages at 390 logical pixels with 1×/2× text in both themes,
fixed-dark terminal presentation, and repeated cancellation/keyboard cleanup.
These widget tests do not replace Android/iOS device accessibility acceptance.
