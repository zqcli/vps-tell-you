# Offline terminal typeface

DejaVu Sans Mono **2.37**, Book and Bold, unmodified TTFs. The default terminal
uses this one bundled family; it does not fetch fonts at runtime. Two weights
occupy 677,408 bytes before APK compression. Italic is platform-synthesized.

- Project: https://dejavu-fonts.github.io/
- Official downloads/version: https://dejavu-fonts.github.io/Download.html
- License: https://dejavu-fonts.github.io/License.html
- Local acquisition: unmodified preinstalled TTFs, with matching
  `fonts-dejavu-core` copyright documentation and embedded version/license metadata.
- `LICENSE-DejaVu.txt` is the complete license embedded in these Mono fonts.
  It is shipped in the app and registered with Flutter's license registry.
- DejaVu changes are public domain; underlying Bitstream Vera copyright and
  redistribution conditions still apply. The fonts are not sold separately.

SHA-256:

- DejaVuSansMono.ttf: `54bf827eb99404e8f430c330ad30f063334f637eba0109b6a18d4f566a8e9dd8`
- DejaVuSansMono-Bold.ttf: `0d3c03d1b667192f91223660a3163325cf83132662fe4d9f7d6e596bf7a995c2`

Rationale: distinct dotted zero / O and 1 / lowercase l / uppercase I; mature
fixed-width outlines; matching Book/Bold advance widths; complete box drawing
U+2500–257F. ASCII advances in both files are 1233/2048 em. At 14 logical pixels
this is about 8.43 pixels per cell, leaving roughly 44 columns in a 390px view
with 8px side padding. Exact PTY dimensions come from xterm's rendered viewport.

Coding ligatures (`liga`, `clig`, `dlig`) and kerning are explicitly disabled in
`CodingTerminalStyle`; terminal byte/cell semantics stay with xterm. System
Noto Sans Mono CJK / Noto Sans CJK / PingFang SC fonts are fallbacks for Chinese,
which xterm treats as two cells. A huge CJK font is deliberately not bundled;
actual fallback appearance therefore depends on the device. No emoji-width or
all-script compatibility claim is made from the Latin font tests alone.
