/// Tiny parser for the Keep-a-Changelog subset used by `CHANGELOG.md` and
/// `CHANGELOG.en.md`:
///
/// * `# Title` – ignored (the page has its own title)
/// * `## 0.1.0 — Unreleased` – a release
/// * `### Added` – a section of a release
/// * `- item` – a bullet (indented lines continue it)
/// * other text – a paragraph of the current section / release
/// * `<!-- … -->` – comments (may span lines), ignored
/// * `**bold**` inside text – see [parseBold]
library;

class ChangelogSection {
  ChangelogSection(this.title);

  /// `null` for text placed directly under the release heading.
  final String? title;
  final List<ChangelogItem> items = [];
}

/// One bullet or paragraph.
class ChangelogItem {
  const ChangelogItem(this.text, {this.bullet = true});
  final String text;
  final bool bullet;
}

class ChangelogRelease {
  ChangelogRelease(this.title);
  final String title;
  final List<ChangelogSection> sections = [];
}

List<ChangelogRelease> parseChangelog(String source) {
  final releases = <ChangelogRelease>[];
  ChangelogRelease? release;
  ChangelogSection? section;
  var inComment = false;
  var paragraph = <String>[];
  // The bullet whose continuation lines are still being collected.
  var bulletLines = <String>[];

  ChangelogRelease openRelease(String title) {
    final created = ChangelogRelease(title);
    releases.add(created);
    section = null;
    return release = created;
  }

  ChangelogSection openSection(String? title) {
    final created = ChangelogSection(title);
    (release ?? openRelease('')).sections.add(created);
    return section = created;
  }

  ChangelogSection current() => section ?? openSection(null);

  void flush() {
    if (bulletLines.isNotEmpty) {
      current().items.add(ChangelogItem(bulletLines.join(' ')));
      bulletLines = [];
    }
    if (paragraph.isNotEmpty) {
      current().items.add(ChangelogItem(paragraph.join(' '), bullet: false));
      paragraph = [];
    }
  }

  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    var line = raw;
    if (inComment) {
      final end = line.indexOf('-->');
      if (end < 0) continue;
      inComment = false;
      line = line.substring(end + 3);
    }
    while (true) {
      final start = line.indexOf('<!--');
      if (start < 0) break;
      final end = line.indexOf('-->', start + 4);
      if (end < 0) {
        line = line.substring(0, start);
        inComment = true;
        break;
      }
      line = line.substring(0, start) + line.substring(end + 3);
    }
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flush();
    } else if (trimmed.startsWith('### ')) {
      flush();
      openSection(trimmed.substring(4).trim());
    } else if (trimmed.startsWith('## ')) {
      flush();
      openRelease(trimmed.substring(3).trim());
    } else if (trimmed.startsWith('# ')) {
      flush();
    } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
      flush();
      bulletLines = [trimmed.substring(2).trim()];
    } else if (bulletLines.isNotEmpty && line.startsWith(RegExp(r'\s'))) {
      bulletLines.add(trimmed);
    } else {
      if (bulletLines.isNotEmpty) flush();
      paragraph.add(trimmed);
    }
  }
  flush();
  return releases;
}

/// Splits [text] into `(segment, bold)` pairs at `**…**` markers. An
/// unmatched marker stays literal.
List<(String, bool)> parseBold(String text) {
  final parts = <(String, bool)>[];
  var index = 0;
  while (index < text.length) {
    final open = text.indexOf('**', index);
    final close = open < 0 ? -1 : text.indexOf('**', open + 2);
    if (open < 0 || close < 0) {
      parts.add((text.substring(index), false));
      break;
    }
    if (open > index) parts.add((text.substring(index, open), false));
    parts.add((text.substring(open + 2, close), true));
    index = close + 2;
  }
  return parts;
}
