"""Export launcher icons from the kitten-and-book artwork used on the homepage.

Run from any directory with: python3 tools/prepare_app_icons.py
Requires Pillow, also used by prepare_art.py.
"""

import json
from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art/mimi_reading.webp"


def main():
    with Image.open(SOURCE) as source:
        artwork = source.convert("RGB")

    targets = {}
    catalog = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for entry in json.loads((catalog / "Contents.json").read_text())["images"]:
        points = float(entry["size"].split("x")[0])
        scale = float(entry["scale"].removesuffix("x"))
        targets[catalog / entry["filename"]] = round(points * scale)

    for density, size in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        targets[ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"] = size

    manifest = json.loads((ROOT / "web/manifest.json").read_text())
    for entry in manifest["icons"]:
        targets[ROOT / "web" / entry["src"]] = int(entry["sizes"].split("x")[0])
    targets[ROOT / "web/favicon.png"] = 32

    for path, size in targets.items():
        # Center-crop to a square without distorting the kitten or the book.
        icon = ImageOps.fit(artwork, (size, size), method=Image.Resampling.LANCZOS)
        icon.save(path, optimize=True)

    print(f"Exported {len(targets)} launcher icons from {SOURCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
