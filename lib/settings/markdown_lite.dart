/// A tiny reader for the Markdown subset used by `PRIVACY.md` and
/// `PRIVACY.en.md`, so the in-app page and the GitHub page share one file:
///
/// * `# Title` – dropped (the page has its own title)
/// * `## Heading` / `### Heading` – [DocBlockKind.heading] / [DocBlockKind.subheading]
/// * `- item` – a bullet (indented lines continue it)
/// * other text – a paragraph (consecutive lines are joined)
/// * `**bold**` – kept for `parseBold`; `` `code` `` loses its backticks
/// * `[text](url)` – shown as `text`; links to the sibling language file
///   (relative targets, such as `· [English](PRIVACY.en.md)`) are dropped
library;

enum DocBlockKind { heading, subheading, paragraph, bullet }

class DocBlock {
  const DocBlock(this.kind, this.text);
  final DocBlockKind kind;
  final String text;
}

String _inline(String text) => text
    .replaceAll(RegExp(r'\s*·\s*\[[^\]]*\]\((?!https?:)[^)]*\)'), '')
    .replaceAll(RegExp(r'\[([^\]]*)\]\((?!https?:)[^)]*\)'), '')
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAll('`', '')
    .trim();

List<DocBlock> parseDoc(String source) {
  final blocks = <DocBlock>[];
  var lines = <String>[];
  DocBlockKind? open;

  void flush() {
    final kind = open;
    if (kind != null && lines.isNotEmpty) {
      final text = _inline(lines.join(' '));
      if (text.isNotEmpty) blocks.add(DocBlock(kind, text));
    }
    lines = [];
    open = null;
  }

  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    if (line.trim().isEmpty) {
      flush();
    } else if (line.startsWith('### ')) {
      flush();
      blocks.add(DocBlock(DocBlockKind.subheading, _inline(line.substring(4))));
    } else if (line.startsWith('## ')) {
      flush();
      blocks.add(DocBlock(DocBlockKind.heading, _inline(line.substring(3))));
    } else if (line.startsWith('# ')) {
      flush();
    } else if (line.startsWith('- ')) {
      flush();
      open = DocBlockKind.bullet;
      lines = [line.substring(2)];
    } else if (open == DocBlockKind.bullet && raw.startsWith(' ')) {
      lines.add(line.trim());
    } else {
      if (open != DocBlockKind.paragraph) flush();
      open = DocBlockKind.paragraph;
      lines.add(line.trim());
    }
  }
  flush();
  return blocks;
}
