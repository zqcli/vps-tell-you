# `lib/core/ui` – design-system components

iOS look on both platforms, no `Platform` / `TargetPlatform` branching. Visual
source of truth: `docs/ui-redesign/{style.css,app.js}`.

```dart
import '../core/ui/ui.dart';      // everything below + AppPalette / context.palette
```

## Rules of thumb

* **Colours**: never hardcode hex. `final p = context.palette;` →
  `p.bg, p.surface, p.text, p.text2, p.text3, p.separator, p.fill, p.primary,
  p.primarySoft, p.green/greenSoft, p.amber/amberSoft, p.red/redSoft`.
  `AppTints.*` are the vivid colours for `AppIconSquare`. `AppColors` (in
  `app_theme.dart`) is only for the PNG export renderer – do not use it in UI.
* **Numbers** (money, days, counters): `TextStyle(fontFeatures: kTabularFigures)`.
  Monospace (host, fingerprint): `kMonoTextStyle`.
* **Horizontal margin**: top-level blocks (`AppSection`, `AppCard`,
  `AppSearchField`, `AppStatGrid`, `AppQuickActionRow`, `AppBanner`) already
  include the 16 px page margin. Do **not** pad the page body again.
  `AppChipRow` scrolls edge to edge with its own 16 px padding.
* **No outlined buttons / text fields.** Fields live in `AppFormRow`; actions
  are rows (`AppRow(center: true)`), `AppButton` (primary / tonal / plain) or
  nav bar buttons.
* A `StatusPill` next to long text must be wrapped in `Flexible` (it ellipsises).
* `ListView` + `AppBar` pages are replaced by `AppScaffold`; keep every
  `ValueKey`, put it on the widget that performs the action (`AppRow(key:)`,
  `AppNavButton.icon(key:)`, …).

## Page skeleton

| Component | Usage |
|---|---|
| `AppScaffold` | `AppScaffold(title: l10n.settings, subtitle: '…', actions: [AppNavButton.icon(Icons.add, tooltip: l10n.add, onPressed: add)], onRefresh: controller.refresh, children: [...])`. Large title that collapses to a centred small one with a blurred bar. Pushed pages get a back button labelled with the previous page's title automatically (`backLabel:` to override). `largeTitle: false` → small title only; `revealTitleOnScroll: true` hides it until the content scrolls (hero headers). `slivers: [...]` instead of `children` for long lists (`SliverList.builder`). `bottomBar:` fixed footer (e.g. a primary `AppButton`). Works inside Material `Scaffold` machinery: SnackBars, `ScaffoldMessenger`, dialogs unchanged; `RefreshFailureNotice` & friends are ordinary children. |
| `AppScaffold.modal` | Page-sheet form: `AppScaffold.modal(title: l10n.addServer, onAction: valid ? save : null, actionLabel: l10n.save, onCancel: confirmDiscard, actionBusy: saving, children: [...])`. "Cancel" left, bold action right (grey while `onAction == null`). |
| `showAppModal<T>` | `await showAppModal<bool>(context, builder: (_) => ServerFormPage(...))` – iOS page sheet (slides up, drag to dismiss, page behind scales). Close with `Navigator.pop(context, result)`. |
| `AppNavButton.icon / .text` | Items for `actions:` (24 px icon or text; `bold` for confirm actions). |

## Grouped lists

| Component | Usage |
|---|---|
| `AppSection` | `AppSection(header: 'Ledger', headerAction: AppLinkButton(label: 'Edit', onPressed: edit), footer: 'Explanatory footnote', children: [rows])` – inset hairlines, radius 14, no border. `footerWidget:` for rich footers. |
| `AppRow` | `AppRow(icon: Icons.folder_outlined, iconColor: AppTints.orange, title: 'Groups', subtitle: '…', value: '3', chevron: true, onTap: open)`; `leading: ProviderAvatar(...)`; `trailing: StatusPill(...)`; `destructive: true`; `center: true` (blue centred button row); `enabled: false`; `AppRow.custom(child: …)` for special content inside the row chrome. |
| `AppSwitchRow` | `AppSwitchRow(title: 'Notifications', value: on, onChanged: setOn)` (tap anywhere toggles). |
| `AppFormRow` | `AppFormRow(label: 'Name', required: true, errorText: err, child: AppTextField(controller: c, hint: 'HK-01'))`; `AppFormRow.pick(label: 'Provider', value: name, placeholder: 'Unspecified', onTap: choose)`; `stacked: true` for multi-line notes. |
| `AppPinnedSearch` + `AppLazySections` | Long searchable lists (hundreds of rows): `AppScaffold(title: …, slivers: [AppPinnedSearch(controller: q, placeholder: …, onChanged: (_) => setState(() {})), AppLazySections(sections: [AppListSection(header: 'Mine', count: n, itemBuilder: (ctx, i) => AppRow(...))])])`. The search field is pinned under the bar (autofocus off by default); sections look like `AppSection` but rows are built lazily; empty sections vanish. `AppListMessage('No matches.')` for an empty result. Matching helpers (accent/case/width-folded, CJK substring, `2 GB` ≙ `2gb`): `lib/core/search_match.dart`. Also used inside `AppScaffold.modal` for full-height pickers. |
| `AppTextField` | Borderless right-aligned `TextField` wrapper (`textAlign: TextAlign.start` for notes, `label:` = a11y label). |
| `AppKeyValueRow` | `AppKeyValueRow(label: 'OS', value: 'Debian 12', mono: false, onLongPress: copy)`; empty value shows "—". |
| `AppIconSquare` | `AppIconSquare(icon: Icons.key, color: AppTints.green)` (30 px; 38 for tool tiles). |

## Content components

| Component | Usage |
|---|---|
| `AppCard` | `AppCard(child: …, onTap: …)` free-form surface (radius 14). `margin: EdgeInsets.zero` when nested. |
| `StatusPill` | `StatusPill('Expired 2 days', tone: AppTone.red, dot: true)`; tones `neutral, amber, red, green, blue`. |
| `ProviderAvatar` | `ProviderAvatar(name: provider?.name, mark: 'BWG', size: 42, starred: favorite)`; hashed colour, initials, grey `?` for null. `logo: FileImage(file)` shows a picture on a white tile with a hairline border (both themes; decoded at `size × devicePixelRatio`, initials if it cannot be decoded); the semantics label is the name. In screens use `ProviderLogo(ledger:, provider:)` / `ProviderLogo(ledger:, directoryId:, name:)` (lib/providers/directory_widgets.dart), which finds the cached directory logo, so a provider looks the same everywhere. |
| `AppSearchField` | `AppSearchField(controller: q, placeholder: l10n.search, onChanged: …)`. |
| `AppSegmented<T>` | `AppSegmented<String>(options: {'a': 'GiB', 'b': 'TiB'}, value: v, onChanged: set, compact: true)` (compact inside form rows). |
| `AppStepper` | `AppStepper(value: vcpu, min: 1, max: 128, onChanged: set)`. |
| `AppSwitch` | `AppSwitch(value: v, onChanged: set, semanticLabel: '…')`. |
| `AppChip` / `AppChipRow` | `AppChipRow(children: [AppChip(label: 'All', count: 6, selected: true, onTap: …), AppChip(label: 'Filter', icon: Icons.tune_rounded, outlined: true)])` – selected = dark filled. |
| `AppStatTile` / `AppStatGrid` | `AppStatGrid(children: [AppStatTile(value: '1', label: 'Expired', tone: AppTone.red, onTap: …), …])`. |
| `AppQuickAction` / `AppQuickActionRow` | `AppQuickActionRow(children: [AppQuickAction(icon: Icons.terminal, label: 'SSH', onTap: …, dimmed: !available), AppQuickAction(..., tone: AppTone.red)])` – `dimmed` looks disabled but still taps (to explain why). |
| `AppMetricStrip` | **The rule for any "several small KPIs in a row"** (remaining value / days left / daily rate, counters …): `AppCard(child: AppMetricStrip(metrics: [AppMetric(label: 'Value left', value: r'$12.40'), AppMetric(label: 'Days left', value: '7 days'), AppMetric(label: 'Daily', value: r'$0.1370')]))`. 2–4 equal-width columns split by 0.5 px hairlines, **caption and figure both centered** (caption 13 secondary above figure 17 semibold tabular). Keep captions to 1–2 short words and figures pre-formatted (unknown → `—`). It measures real text and falls back to rows of two columns, then to caption-left / figure-right lines, so nothing clips at 320 px / 2× text. Never build ad-hoc `Row`s of `Column`s for this. `AppMetric(onTap:)` makes a column tappable (filters / drill-down, e.g. the server list counters, reminder overview); `onGradient: true` is the white-on-gradient variant. Replaces `AppStatGrid`/`AppStatTile`, which stay only for legacy use. |
| `AppButton` | `AppButton(label: 'Add', icon: Icons.add, kind: AppButtonKind.tonal, compact: true, destructive: false, busy: saving, expand: true, onPressed: …)`. |
| `AppProgressBar` | `AppProgressBar(value: .92, tone: AppTone.amber)`. |
| `AppBanner` | `AppBanner(tone: AppTone.amber, icon: Icons.warning_amber_rounded, text: '…', onTap: …)`. |
| `AppLogo` | `AppLogo(size: 64)`. The app mark (`AppLogoPainter`); decorative unless `semanticLabel` is set. Launcher icons are exported from the same painter: `flutter test tool/app_icon_test.dart && uv run --with pillow python tool/app_icons.py`. |
| `AppEmptyState` | `AppEmptyState(icon: Icons.dns_outlined, title: '…', message: '…', actions: [AppButton(...)])`. |

## Overlays

| Function | Usage |
|---|---|
| `showAppSheet<T>` | `showAppSheet<T>(context, title: 'Filter', builder: (ctx) => AppSection(children: [...]))` – grabber, title, ✕, scrollable, keyboard-aware. `Navigator.pop(ctx, value)` returns. |
| `showAppPicker<T>` | `await showAppPicker<int>(context, title: 'Cycle', selected: cycle, options: [AppPickerOption(value: 1, title: 'Monthly')], footnote: '…')` → value or `null` (use a sentinel such as `''` for a "None" option). |
| `showAppActionMenu<T>` | `showAppActionMenu<void>(context, title: server.name, actions: [AppMenuAction(label: 'Copy address', onPressed: copy), AppMenuAction(label: 'Archive', destructive: true, onPressed: archive)])` – callbacks run after the sheet closed; returns the chosen `value`. |
| `showAppConfirm` | `if (await showAppConfirm(context, title: …, message: …, action: …, dangerous: true))` – same signature/return as `confirmAction`. Dangerous → action sheet with red button; otherwise Cupertino alert. Full message always shown. |
| `showAppToast` | `showAppToast(context, 'Archived', actionLabel: 'Undo', onAction: undo)` – floating dark toast. |

## Old → new

| Old | New |
|---|---|
| `Scaffold` + `AppBar` + `ListView` | `AppScaffold(children: …)` |
| full-screen edit form route | `showAppModal` + `AppScaffold.modal` |
| `LedgerCard(child: Column(...))` of rows | `AppSection(children: [AppRow, …])` |
| `LedgerCard` for free content | `AppCard` |
| `SettingRow(icon, title, subtitle, onTap)` | `AppRow(icon:, iconColor:, title:, subtitle:, chevron: true, onTap:)` |
| `SectionTitle('x', action: …)` | `AppSection(header: 'x', headerAction: …)` |
| `InfoNote('…')` under a group | `AppSection(footer: '…')` |
| `LedgerBadge` | `StatusPill` |
| `confirmAction(...)` | `showAppConfirm(...)` (same args) |
| `showStage(...)` | `showAppConfirm` / `showAppSheet` |
| `showDialog(AlertDialog(... DropdownButton ...))` filters | `showAppPicker` / `showAppSheet` |
| `FilledButton` / `OutlinedButton` full width | `AppButton` (tonal / primary) or a centred `AppRow` |
| `OutlinedButton` in `Wrap` actions | `AppSection` rows, `AppQuickAction`s or sheet items |
| `SwitchListTile` / `Switch.adaptive` | `AppSwitchRow` / `AppSwitch` |
| `SegmentedButton` / `ChoiceChip` row | `AppSegmented` / `AppChipRow` |
| `TextField` with outline | `AppFormRow(child: AppTextField(...))` |
| `ScaffoldMessenger…showSnackBar` | `showAppToast` (`showFailure` still works) |

The legacy widgets (`LedgerCard`, `SectionTitle`, `LedgerBadge`, `InfoNote`,
`SettingRow`, `confirmAction`, `showStage`, `showFailure`) stay and are
restyled, so unmigrated pages already look close; `confirmAction` still shows a
Material `AlertDialog` (iOS-styled) so existing `find.byType(AlertDialog)` test
finders keep working until a page switches to `showAppConfirm`
(`CupertinoAlertDialog` / `CupertinoActionSheet`).

## Testing notes

* Back button: `find.byKey(const ValueKey('app-nav-back'))` (also has the
  "Back" tooltip). Sheet close: `ValueKey('app-sheet-close')`.
* Modal save/cancel: `find.text(l10n.save)` / `find.text(l10n.cancel)`.
* `AppSwitch` is a `CupertinoSwitch`; `AppSegmented` a
  `CupertinoSlidingSegmentedControl`; confirmations are `CupertinoAlertDialog` /
  `CupertinoActionSheet` (dangerous).
* `AppScaffold` is a `CustomScrollView`, so `find.byType(ListView)` no longer
  matches migrated pages – use `find.byType(Scrollable).first` or
  `CustomScrollView`.
* Pump with `pump(Duration)` instead of `pumpAndSettle` while an `AppButton`
  with `busy: true` is on screen (its spinner never settles).
* Do not use `Cupertino` icons (`CupertinoIcons`): the `cupertino_icons`
  package is not a dependency. Use Material icons.

## Alignment rules

* Section / list headers: use `AppSection(header:, headerAction:)` or, for custom
  headers, `AppHeaderRow(title:, action:)` – the action is always flush right,
  both sides shrink instead of overflowing at 320 px / 2×.
* Centered: metric-strip columns, stat tiles, quick actions, buttons (icon +
  label), empty states, "nothing here" placeholder rows inside a group, sheet
  and dialog titles / messages. Left-aligned: row titles, form labels,
  footnotes, banners.
