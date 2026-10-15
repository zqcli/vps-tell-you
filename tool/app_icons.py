"""Resize the icon masters from tool/app_icon_test.dart into the platform sets.

    flutter test tool/app_icon_test.dart
    uv run --with pillow python tool/app_icons.py

iOS gets opaque full-bleed squares (the system rounds the corners; App Store
rejects an alpha channel on the 1024 px icon). Android gets legacy rounded
icons plus an adaptive icon (bubble foreground over a gradient background).
"""

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MASTERS = ROOT / "build" / "app_icon"
IOS_SET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def load(name):
    return Image.open(MASTERS / f"{name}.png").convert("RGBA")


def ios():
    square = load("square")
    opaque = Image.new("RGB", square.size, (255, 255, 255))
    opaque.paste(square, mask=square)
    contents = json.loads((IOS_SET / "Contents.json").read_text())
    for image in contents["images"]:
        points = float(image["size"].split("x")[0])
        pixels = round(points * int(image["scale"].rstrip("x")))
        opaque.resize((pixels, pixels), Image.LANCZOS).save(
            IOS_SET / image["filename"], optimize=True
        )


def android():
    rounded = load("rounded")
    foreground = load("foreground")
    for density, factor in DENSITIES.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(exist_ok=True)
        size = round(48 * factor)
        inner = round(size * 0.92)
        legacy = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        tile = rounded.resize((inner, inner), Image.LANCZOS)
        offset = (size - inner) // 2
        legacy.paste(tile, (offset, offset), tile)
        legacy.save(folder / "ic_launcher.png", optimize=True)
        layer = round(108 * factor)
        foreground.resize((layer, layer), Image.LANCZOS).save(
            folder / "ic_launcher_foreground.png", optimize=True
        )


if __name__ == "__main__":
    ios()
    android()
    print("icons written")
