/// A local text template. Loading or selecting it never writes to a terminal.
class CommandSnippet {
  const CommandSnippet({
    required this.id,
    required this.name,
    required this.content,
    this.revision = 0,
  });

  static const maxNameLength = 80;
  static const maxContentLength = 16384;
  final String id, name, content;
  final int revision;

  String? validate() {
    if (id.isEmpty || id.length > 128 || revision < 0) return '片段标识无效';
    if (name.trim().isEmpty || name.length > maxNameLength) {
      return '名称需为 1–80 个字符';
    }
    if (content.trim().isEmpty || content.length > maxContentLength) {
      return '内容不能为空，最多 16384 个字符';
    }
    return null;
  }

  factory CommandSnippet.fromMap(Map<String, Object?> row) => CommandSnippet(
    id: row['id'] as String,
    name: row['name'] as String,
    content: row['content'] as String,
    revision: row['revision'] as int,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'content': content,
    'revision': revision,
  };
}

/// Complete display-only preview, never a value to send to SSH. Escaping the
/// backslash makes literal "\\r" distinguishable from an actual carriage return.
/// Newlines stay readable but also receive a visible marker; control and bidi
/// formatting characters cannot hide or rewrite the displayed command.
String escapedCommandPreview(String content) {
  final result = StringBuffer();
  for (final rune in content.runes) {
    switch (rune) {
      case 0x5c:
        result.write(r'\\');
      case 0x0a:
        result.write('\\n\n');
      case 0x0d:
        result.write(r'\r');
      case 0x09:
        result.write(r'\t');
      default:
        if (rune < 0x20 ||
            (rune >= 0x7f && rune <= 0x9f) ||
            rune == 0xad ||
            rune == 0x61c ||
            rune == 0x180e ||
            (rune >= 0x200b && rune <= 0x200f) ||
            (rune >= 0x2028 && rune <= 0x202e) ||
            (rune >= 0x2060 && rune <= 0x206f) ||
            rune == 0xfeff) {
          result.write('\\u{${rune.toRadixString(16).padLeft(4, '0')}}');
        } else {
          result.writeCharCode(rune);
        }
    }
  }
  return result.toString();
}
