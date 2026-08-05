"""Convert source .webp assets to PNG previews and report dimensions."""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets")
OUT = os.path.join(ROOT, "tools", "_preview")

os.makedirs(OUT, exist_ok=True)

for folder in ("Lavawake_Rush_additional_assets", "Lavawake_Rush_gameplay_assets"):
    d = os.path.join(SRC, folder)
    for name in sorted(os.listdir(d)):
        if not name.lower().endswith((".webp", ".png")):
            continue
        p = os.path.join(d, name)
        im = Image.open(p)
        print(f"{name:60s} {im.size[0]:5d}x{im.size[1]:5d} {im.mode}")
        base = os.path.splitext(name)[0]
        im.convert("RGBA").save(os.path.join(OUT, base + ".png"))
