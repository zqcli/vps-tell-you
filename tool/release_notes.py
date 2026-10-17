"""Print the GitHub release notes for one version from the changelogs.

    python3 tool/release_notes.py 0.6.0 > notes.md
    gh release create v0.6.0 --title "VPS Tell You 0.6.0" --notes-file notes.md

The app's Settings › About › What's New shows the same CHANGELOG.md /
CHANGELOG.en.md sections, so the in-app notes and the GitHub release always
match. Standard library only.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = "https://github.com/zqcli/vps-tell-you"


def section(path: Path, version: str) -> str:
    text = re.sub(r"<!--.*?-->", "", path.read_text(encoding="utf-8"), flags=re.S)
    match = re.search(
        rf"^## {re.escape(version)}\b.*?$(.*?)(?=^## |\Z)", text, flags=re.S | re.M
    )
    if not match:
        sys.exit(f"{path.name}: no section for {version}")
    return match.group(1).strip()


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit("usage: release_notes.py <version>")
    version = sys.argv[1]
    zh = section(ROOT / "CHANGELOG.md", version)
    en = section(ROOT / "CHANGELOG.en.md", version)
    print(
        f"""<p align="center"><img src="https://raw.githubusercontent.com/zqcli/vps-tell-you/v{version}/docs/images/zh/hero.png" width="720" alt="VPS Tell You"></p>

> **安装 / Install**：源码发布，请按 [安装指南]({REPO}/wiki/Install) 自行构建。Source-only release; see the [install guide]({REPO}/wiki/Install-EN).

## 中文

{zh}

## English

{en}

---
MIT License · [README]({REPO}#readme) · [Wiki]({REPO}/wiki)"""
    )


if __name__ == "__main__":
    main()
