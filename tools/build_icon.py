"""Compose the launcher icon layers.

Android adaptive icons only reveal the inner 72/108 of each layer, so a plain
full-bleed foreground would crop the corner creatures away. Instead the artwork
is placed just past the safe window and the surrounding bleed is a zoomed,
blurred copy of the same art, giving an icon that fills the whole surface with
no empty edges while keeping the full scene readable.

Run:  python tools/build_icon.py
"""

from __future__ import annotations

import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "Lavawake_Rush_additional_assets", "Icon.png")
OUT = os.path.join(ROOT, "assets", "icon")

SIZE = 1024
# Android reveals 72/108 == 0.667 of the layer; overshoot slightly so the
# artwork always covers the window even under a circular mask.
CONTENT_SCALE = 0.70
FEATHER = 14

os.makedirs(OUT, exist_ok=True)
source = Image.open(SRC).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)

source.save(os.path.join(OUT, "icon.png"), optimize=True)

zoom = int(SIZE * 1.45)
bleed = source.resize((zoom, zoom), Image.LANCZOS)
offset = (zoom - SIZE) // 2
background = bleed.crop((offset, offset, offset + SIZE, offset + SIZE))
background = background.filter(ImageFilter.GaussianBlur(26))
background = ImageEnhance.Brightness(background).enhance(0.72)
background = ImageEnhance.Color(background).enhance(1.08)
background.convert("RGB").save(os.path.join(OUT, "icon_background.png"), optimize=True)

content = int(SIZE * CONTENT_SCALE)
art = source.resize((content, content), Image.LANCZOS)

mask = Image.new("L", (content, content), 0)
ImageDraw.Draw(mask).rectangle([FEATHER, FEATHER, content - FEATHER, content - FEATHER], fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(FEATHER / 1.6))
art.putalpha(mask)

foreground = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
foreground.alpha_composite(art, ((SIZE - content) // 2, (SIZE - content) // 2))
foreground.save(os.path.join(OUT, "icon_foreground.png"), optimize=True)

print("wrote icon.png, icon_background.png, icon_foreground.png")

# Native splash artwork: the wordmark logo, padded for the Android 12 circular
# mask so the native splash matches the in-app loading screen branding.
LOGO = os.path.join(ROOT, "assets", "Lavawake_Rush_additional_assets", "Game_Name.webp")
logo = Image.open(LOGO).convert("RGBA")


def padded_logo(canvas: int, content: int, name: str) -> None:
    art = logo.copy()
    art.thumbnail((content, content), Image.LANCZOS)
    sheet = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    sheet.alpha_composite(art, ((canvas - art.width) // 2, (canvas - art.height) // 2))
    sheet.save(os.path.join(OUT, name), optimize=True)
    print(f"wrote {name}")


padded_logo(1024, 900, "splash_logo.png")
padded_logo(1152, 620, "splash_logo_android12.png")
