"""Download the UI typefaces and bake static weights so the app needs no network.

Google Fonts ships these families as single-axis variable fonts. Flutter picks a
font file per declared weight, so each weight is instanced out of the variable
master and written into assets/fonts/.

Run:  python tools/fetch_fonts.py
"""

from __future__ import annotations

import os
import urllib.request

from fontTools import ttLib
from fontTools.varLib import instancer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts")
CACHE = os.path.join(ROOT, "tools", "_fontcache")

FAMILIES = {
    "Sora": ("https://github.com/google/fonts/raw/main/ofl/sora/Sora%5Bwght%5D.ttf", [400, 600, 700, 800]),
    "Manrope": ("https://github.com/google/fonts/raw/main/ofl/manrope/Manrope%5Bwght%5D.ttf", [400, 500, 600, 700, 800]),
}

os.makedirs(OUT, exist_ok=True)
os.makedirs(CACHE, exist_ok=True)

for family, (url, weights) in FAMILIES.items():
    master = os.path.join(CACHE, f"{family}-variable.ttf")
    if not os.path.exists(master):
        print(f"downloading {family}")
        urllib.request.urlretrieve(url, master)
    for weight in weights:
        font = ttLib.TTFont(master)
        instancer.instantiateVariableFont(font, {"wght": weight}, inplace=True, updateFontNames=True)
        target = os.path.join(OUT, f"{family}-{weight}.ttf")
        font.save(target)
        print(f"  {os.path.basename(target)}  {os.path.getsize(target) // 1024} KB")
