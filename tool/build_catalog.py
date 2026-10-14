#!/usr/bin/env python3
"""Validate catalog/providers/*/ and (re)generate catalog/index.json.

    python3 tool/build_catalog.py            # validate, write index.json
    python3 tool/build_catalog.py --check    # exit 1 if index.json is stale

Python 3.9+ standard library only. See catalog/README.md for the format.

index.json is the only file the app polls. It is deterministic: providers are
sorted by id and keys have a fixed order. `catalogVersion` goes up by one only
when the content changed (the providers, their text or their logos);
`generatedAt` is rewritten only together with it, so running the script twice
changes nothing.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent / "catalog"
PROVIDERS = CATALOG / "providers"
INDEX = CATALOG / "index.json"

SCHEMA_VERSION = 1
ID_PATTERN = re.compile(r"^[a-z0-9-]{2,40}$")
KINDS = ("cloud", "vps")
REGIONS = ("cn", "global")
LOGO_SIZE = 256
LOGO_MAX_BYTES = 64 * 1024
NAME_MAX = 80
ALIAS_MAX = 80
ALIASES_MAX = 20
DESCRIPTION_MAX = {"zh": 40, "en": 120}
INDEX_MAX_BYTES = 1024 * 1024  # what the app accepts
PROVIDERS_MAX = 1000
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"
FIELDS = {"id", "name", "aliases", "kind", "region", "website", "description"}


class Invalid(Exception):
    pass


def _text(value, label: str, maximum: int) -> str:
    if not isinstance(value, str) or not value.strip():
        raise Invalid(f"{label}: must be a non-empty string")
    if value != value.strip():
        raise Invalid(f"{label}: has leading or trailing whitespace")
    if len(value) > maximum:
        raise Invalid(f"{label}: longer than {maximum} characters")
    if "\x00" in value or "\n" in value or "\r" in value:
        raise Invalid(f"{label}: contains control characters")
    return value


def _lang_map(value, label: str, limits: dict[str, int]) -> dict[str, str]:
    if not isinstance(value, dict) or set(value) != set(limits):
        raise Invalid(f'{label}: must be an object with exactly {sorted(limits)}')
    return {lang: _text(value[lang], f"{label}.{lang}", limits[lang]) for lang in limits}


def check_logo(path: Path, label: str) -> tuple[str, int]:
    """Returns (sha256, bytes) of a valid logo, else raises Invalid."""
    if not path.is_file():
        raise Invalid(f"{label}: logo.png is not a file")
    data = path.read_bytes()
    if len(data) > LOGO_MAX_BYTES:
        raise Invalid(f"{label}: logo.png is {len(data)} bytes (max {LOGO_MAX_BYTES})")
    if not data.startswith(PNG_MAGIC) or data[12:16] != b"IHDR":
        raise Invalid(f"{label}: logo.png is not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    if (width, height) != (LOGO_SIZE, LOGO_SIZE):
        raise Invalid(f"{label}: logo.png is {width}x{height}, must be {LOGO_SIZE}x{LOGO_SIZE}")
    return hashlib.sha256(data).hexdigest(), len(data)


def load_provider(folder: Path) -> dict:
    label = f"providers/{folder.name}"
    source = folder / "provider.json"
    if not source.is_file():
        raise Invalid(f"{label}: provider.json is missing")
    try:
        raw = json.loads(source.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise Invalid(f"{label}/provider.json: {error}") from None
    if not isinstance(raw, dict):
        raise Invalid(f"{label}/provider.json: must be an object")
    unknown = set(raw) - FIELDS
    missing = FIELDS - set(raw)
    if unknown:
        raise Invalid(f"{label}: unknown fields {sorted(unknown)}")
    if missing:
        raise Invalid(f"{label}: missing fields {sorted(missing)}")

    provider_id = raw["id"]
    if not isinstance(provider_id, str) or not ID_PATTERN.match(provider_id):
        raise Invalid(f"{label}: id must match {ID_PATTERN.pattern}")
    if provider_id != folder.name:
        raise Invalid(f"{label}: id {provider_id!r} differs from the folder name")

    aliases = raw["aliases"]
    if not isinstance(aliases, list) or len(aliases) > ALIASES_MAX:
        raise Invalid(f"{label}: aliases must be a list of at most {ALIASES_MAX}")
    aliases = [_text(a, f"{label}: alias", ALIAS_MAX) for a in aliases]
    if len({a.casefold() for a in aliases}) != len(aliases):
        raise Invalid(f"{label}: duplicate alias")

    if raw["kind"] not in KINDS:
        raise Invalid(f"{label}: kind must be one of {KINDS}")
    if raw["region"] not in REGIONS:
        raise Invalid(f"{label}: region must be one of {REGIONS}")
    website = _text(raw["website"], f"{label}: website", 200)
    if not re.match(r"^https://[^/\s]+(/\S*)?$", website):
        raise Invalid(f"{label}: website must be an https:// URL")

    # The logo is optional: without logo.png the app shows initials.
    logo = None
    if (folder / "logo.png").exists():
        sha, size = check_logo(folder / "logo.png", label)
        logo = {"path": f"providers/{provider_id}/logo.png", "sha256": sha, "bytes": size}
    entry = {
        "id": provider_id,
        "name": _lang_map(raw["name"], f"{label}: name", {"zh": NAME_MAX, "en": NAME_MAX}),
        "aliases": aliases,
        "kind": raw["kind"],
        "region": raw["region"],
        "website": website,
        "description": _lang_map(raw["description"], f"{label}: description", DESCRIPTION_MAX),
    }
    if logo:
        entry["logo"] = logo
    return entry


def load_all() -> list[dict]:
    if not PROVIDERS.is_dir():
        raise Invalid("catalog/providers/ does not exist")
    providers = []
    for folder in sorted(p for p in PROVIDERS.iterdir() if p.is_dir()):
        providers.append(load_provider(folder))
    stray = [p.name for p in PROVIDERS.iterdir() if not p.is_dir() and p.name != ".gitkeep"]
    if stray:
        raise Invalid(f"catalog/providers/ may only contain folders, found {stray}")
    if len(providers) > PROVIDERS_MAX:
        raise Invalid(f"more than {PROVIDERS_MAX} providers")

    # Every name and alias finds exactly one provider (case-insensitive).
    owner: dict[str, str] = {}
    for provider in providers:
        terms = {t.casefold() for t in [*provider["name"].values(), *provider["aliases"]]}
        for term in terms:
            if owner.setdefault(term, provider["id"]) != provider["id"]:
                raise Invalid(
                    f"{term!r} is used by both {owner[term]} and {provider['id']} "
                    "(names and aliases must be unique)"
                )
    return providers


def render(version: int, generated_at: str, providers: list[dict]) -> str:
    document = {
        "schemaVersion": SCHEMA_VERSION,
        "catalogVersion": version,
        "generatedAt": generated_at,
        "providers": providers,
    }
    text = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    if len(text.encode("utf-8")) > INDEX_MAX_BYTES:
        raise Invalid("index.json would exceed the 1 MiB the app accepts")
    return text


def read_existing() -> dict | None:
    if not INDEX.is_file():
        return None
    try:
        existing = json.loads(INDEX.read_text(encoding="utf-8"))
    except ValueError:
        return None
    return existing if isinstance(existing, dict) else None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true", help="exit 1 if index.json is stale")
    parser.add_argument("--now", help="generatedAt to use for a new version (testing)")
    parser.add_argument("--catalog", type=Path, help="catalog directory (default: ./catalog of this repository)")
    args = parser.parse_args(argv)
    global CATALOG, PROVIDERS, INDEX
    if args.catalog:
        CATALOG = args.catalog.resolve()
        PROVIDERS, INDEX = CATALOG / "providers", CATALOG / "index.json"
    try:
        providers = load_all()
    except Invalid as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    existing = read_existing()
    same = (
        existing is not None
        and existing.get("schemaVersion") == SCHEMA_VERSION
        and existing.get("providers") == providers
        and isinstance(existing.get("catalogVersion"), int)
        and isinstance(existing.get("generatedAt"), str)
    )
    if same:
        version, generated = existing["catalogVersion"], existing["generatedAt"]
    else:
        previous = existing.get("catalogVersion") if existing else 0
        version = (previous if isinstance(previous, int) and previous >= 0 else 0) + 1
        generated = args.now or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    text = render(version, generated, providers)
    if args.check:
        if not same or INDEX.read_text(encoding="utf-8") != text:
            print("catalog/index.json is stale: run `python3 tool/build_catalog.py`", file=sys.stderr)
            return 1
        print(f"catalog/index.json is up to date (version {version}, {len(providers)} providers)")
        return 0
    if INDEX.is_file() and INDEX.read_text(encoding="utf-8") == text:
        print(f"unchanged: version {version}, {len(providers)} providers")
        return 0
    INDEX.write_text(text, encoding="utf-8")
    print(f"wrote catalog/index.json: version {version}, {len(providers)} providers")
    return 0


if __name__ == "__main__":
    sys.exit(main())
