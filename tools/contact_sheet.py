"""Build a labelled contact sheet of every sliced sprite for visual QA."""

from __future__ import annotations

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITES = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "tools", "_preview")

CELL = 190
LABEL = 20
COLS = 7


def build(names: list[str], out_name: str) -> None:
    rows = (len(names) + COLS - 1) // COLS
    sheet = Image.new("RGBA", (COLS * CELL, rows * (CELL + LABEL)), (24, 22, 28, 255))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        cx, cy = (i % COLS) * CELL, (i // COLS) * (CELL + LABEL)
        draw.rectangle([cx, cy, cx + CELL - 2, cy + CELL + LABEL - 2], outline=(70, 66, 80, 255))
        sprite = Image.open(os.path.join(SPRITES, name)).convert("RGBA")
        sprite.thumbnail((CELL - 12, CELL - 12))
        sheet.alpha_composite(sprite, (cx + (CELL - sprite.width) // 2, cy + (CELL - sprite.height) // 2))
        draw.text((cx + 5, cy + CELL + 3), os.path.splitext(name)[0][:30], fill=(235, 230, 240, 255))
    sheet.convert("RGB").save(os.path.join(OUT, out_name), quality=90)
    print(out_name, sheet.size)


all_names = sorted(os.listdir(SPRITES))
groups = {
    "sheet_player.jpg": [n for n in all_names if n.startswith(("player_", "skin_"))],
    "sheet_enemies.jpg": [n for n in all_names if n.startswith(("golem_", "robot_", "demon_"))],
    "sheet_enemies2.jpg": [n for n in all_names if n.startswith(("crystal_", "frost_"))],
    "sheet_objects.jpg": [n for n in all_names if n.startswith(("obj_", "mat_"))],
    "sheet_effects.jpg": [n for n in all_names if n.startswith("fx_")],
}
for out_name, names in groups.items():
    build(names, out_name)
