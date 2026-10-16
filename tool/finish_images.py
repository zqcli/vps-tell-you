"""Turns the raw simulator captures into docs/images/<lang>/*.png|gif.

    flutter test tool/app_icon_test.dart          # -> build/app_icon/rounded.png
    uv run --with pillow --with imageio-ffmpeg python tool/finish_images.py

Input:  build/shots/<lang>/raw/*.png, *.mp4   (tool/make_screenshots.py)
Output: docs/images/<lang>/  440 px wide PNGs, 360 px wide GIFs, hero.png.
GIFs are looked up per language, falling back to the other language's capture
(`--reuse-gif-from zh`) when a language has none.
"""

import argparse
import subprocess
from pathlib import Path

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
PNGS = [
    "servers", "servers-dark", "detail", "form", "provider-picker", "costs",
    "calculator", "reminders", "terminal", "sftp", "sftp-editor", "tcp",
    "providers", "settings", "about",
]
GIFS = {
    # name: (seconds trimmed from the start, max seconds kept)
    "add-server": (0.7, 60),
    "terminal": (0.7, 60),
    "renew": (0.7, 60),
}
SLOGAN = {"zh": "每台 VPS，心里有数", "en": "Know every VPS at a glance"}
SUB = {
    "zh": "到期、费用、连接，都在本机",
    "en": "Renewals, costs and access, on device",
}
PINGFANG = next(
    path
    for path in [Path("/System/Library/Fonts/PingFang.ttc")]
    + sorted(Path("/System/Library/AssetsV2").glob("*Font*/*/AssetData/PingFang.ttc"))
    if path.exists()
)
SF = "/System/Library/Fonts/SFNS.ttf"
MAX_GIF = 4 * 1024 * 1024


def font(size, weight="Semibold", lang="zh"):
    if lang == "en":
        try:
            f = ImageFont.truetype(SF, size)
            f.set_variation_by_name(weight)
            return f
        except Exception:  # SF variable font unavailable: PingFang has Latin
            pass
    index = {"Regular": 3, "Medium": 7, "Semibold": 11}[weight]  # PingFang SC
    return ImageFont.truetype(str(PINGFANG), size, index=index)


def png(raw, out):
    image = Image.open(raw).convert("RGB")
    height = round(image.height * 440 / image.width)
    image = image.resize((440, height), Image.LANCZOS)
    image.save(out, optimize=True)


def gif(ffmpeg, mp4, out, skip, keep):
    for colors in (128, 96, 64):
        subprocess.run(
            [ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-ss", str(skip),
             "-t", str(keep), "-i", str(mp4), "-vf",
             "fps=12,scale=360:-1:flags=lanczos,split[a][b];"
             f"[a]palettegen=max_colors={colors}:stats_mode=diff[p];"
             "[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
             "-loop", "0", str(out)], check=True)
        if out.stat().st_size <= MAX_GIF:
            return
    raise SystemExit(f"{out} is still > 4 MB")


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *image.size), radius, fill=255)
    image = image.convert("RGBA")
    image.putalpha(mask)
    return image


def hero(lang, raw, out):
    w, h = 1600, 900
    start, end = (0x3B, 0x82, 0xF6), (0x4F, 0x46, 0xE5)
    gradient = Image.new("RGB", (w, h))
    pixels = gradient.load()
    for y in range(h):
        for x in range(w):
            t = (x / w * 0.65 + y / h * 0.35)
            pixels[x, y] = tuple(round(a + (b - a) * t) for a, b in zip(start, end))
    canvas = gradient.convert("RGBA")
    shots = [raw / f"{n}.png" for n in ("servers", "detail", "terminal")]
    width, gap = 292, 28
    x0 = 626
    for i, path in enumerate(shots):
        shot = Image.open(path).convert("RGB")
        shot = shot.resize((width, round(shot.height * width / shot.width)), Image.LANCZOS)
        card = rounded(shot, 40)
        y = (150, 80, 150)[i]
        shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).rounded_rectangle(
            (x0 + i * (width + gap) + 4, y + 18, x0 + i * (width + gap) + width + 4,
             y + card.height + 18), 40, fill=(10, 20, 80, 120))
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(22)))
        frame = Image.new("RGBA", (width + 8, card.height + 8), (255, 255, 255, 235))
        frame = rounded(frame, 44)
        canvas.alpha_composite(frame, (x0 + i * (width + gap) - 4, y - 4))
        canvas.alpha_composite(card, (x0 + i * (width + gap), y))
    icon = Image.open(ROOT / "build/app_icon/rounded.png").convert("RGBA")
    icon = icon.resize((168, 168), Image.LANCZOS)
    canvas.alpha_composite(icon, (80, 215))
    draw = ImageDraw.Draw(canvas)
    draw.text((80, 420), "VPS Tell You", font=font(72, "Semibold", lang), fill="white")
    draw.text((80, 520), SLOGAN[lang], font=font(38 if lang == "zh" else 34, "Medium", lang),
              fill=(255, 255, 255, 235))
    draw.text((80, 585), SUB[lang], font=font(24, "Regular", lang),
              fill=(255, 255, 255, 190))
    canvas.convert("RGB").save(out, optimize=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", action="append", choices=["zh", "en"])
    parser.add_argument("--reuse-gif-from", choices=["zh", "en"])
    args = parser.parse_args()
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    for lang in args.lang or ["zh", "en"]:
        raw = ROOT / "build/shots" / lang / "raw"
        out = ROOT / "docs/images" / lang
        out.mkdir(parents=True, exist_ok=True)
        for name in PNGS:
            png(raw / f"{name}.png", out / f"{name}.png")
        hero(lang, raw, out / "hero.png")
        for name, (skip, keep) in GIFS.items():
            source = raw / f"{name}.mp4"
            if not source.exists() and args.reuse_gif_from:
                source = ROOT / "build/shots" / args.reuse_gif_from / "raw" / f"{name}.mp4"
            gif(ffmpeg, source, out / f"{name}.gif", skip, keep)
        print(lang, "done")


if __name__ == "__main__":
    main()
