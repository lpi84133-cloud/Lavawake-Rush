"""Slice the source sprite atlases into individual trimmed PNG sprites.

Each atlas is a transparent sheet holding objects laid out in a known number of
rows with a known number of columns per row. Cut lines are found from the alpha
projection profiles instead of a fixed grid, so wide objects keep their full
silhouette and no sprite gets clipped by a neighbour's cell boundary.

Run:  python tools/slice_sprites.py
"""

from __future__ import annotations

import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "Lavawake_Rush_gameplay_assets")
OUT = os.path.join(ROOT, "assets", "sprites")

ALPHA_THRESHOLD = 20
# Columns/rows holding fewer solid pixels than this count as empty separators,
# which keeps faint ember specks from bridging two neighbouring sprites.
NOISE_FLOOR = 3

# atlas name -> list of rows, each row being the sprite names in left-to-right order.
ATLASES: dict[str, list[list[str]]] = {
    "lava_player_evolution_and_skins_asset": [
        [
            "player_stage_1_droplet",
            "player_stage_2_splash",
            "player_stage_3_crust",
            "player_stage_4_basalt",
            "player_stage_5_forged",
            "player_stage_6_inferno",
            "player_stage_7_crystalline",
            "player_stage_8_prime",
        ],
        [
            "skin_ember",
            "skin_obsidian",
            "skin_glacier",
            "skin_venom",
            "skin_amethyst",
            "skin_sulphur",
        ],
        [
            "skin_cryo",
            "skin_crimson",
            "skin_charcoal",
            "skin_bronze",
            "skin_prism",
            "skin_void",
        ],
    ],
    "basalt_golems_asset": [
        ["golem_shard", "golem_hewn", "golem_titan", "golem_warden"],
        ["golem_bruiser", "golem_overgrown", "golem_amethyst_guard", "golem_boss_magmaheart"],
    ],
    "molten_metal_robots_asset": [
        ["robot_scout", "robot_hammer", "robot_bulwark", "robot_furnace"],
        ["robot_lancer", "robot_juggernaut", "robot_reaper", "robot_boss_coremind"],
    ],
    "fire_demons_asset": [
        ["demon_wisp", "demon_hound", "demon_horned", "demon_wyvern"],
        ["demon_brute", "demon_warlord", "demon_archmage", "demon_boss_pyrelord"],
    ],
    "crystal_creatures_asset": [
        ["crystal_sprite", "crystal_saurian", "crystal_sentinel", "crystal_shardling"],
        ["crystal_colossus", "crystal_tortoise", "crystal_geode_guard", "crystal_boss_prismarch"],
    ],
    "frozen_monsters_asset": [
        ["frost_crawler", "frost_maw", "frost_knight", "frost_breaker"],
        ["frost_shardling", "frost_behemoth", "frost_spearman", "frost_boss_rimewarden"],
    ],
    "elemental_materials_asset": [
        ["mat_magma_ore", "mat_metal_ingot", "mat_fire_essence", "mat_ice_crystal", "mat_obsidian_shard"],
        ["mat_magma_core", "mat_ancient_core", "mat_frost_geode", "mat_ember_cluster", "mat_molten_rock"],
    ],
    "volcanic_environment_objects_asset": [
        [
            "obj_rock_cluster",
            "obj_cracked_boulder",
            "obj_ruby_spikes",
            "obj_basalt_platform",
            "obj_lava_pillar",
            "obj_obsidian_spikes",
        ],
        [
            "obj_ember_nodes",
            "obj_magma_tiles",
            "obj_glow_boulder",
            "obj_amethyst_mound",
            "obj_bubbling_mound",
            "obj_stone_column",
        ],
        [
            "obj_core_geyser",
            "obj_stepping_stones",
            "obj_magma_shards",
            "obj_ruby_deposit",
            "obj_basalt_tower",
            "obj_vent_mound",
        ],
    ],
    "absorption_and_transformation_effects_asset": [
        ["fx_lava_vortex", "fx_crystal_burst", "fx_ash_eruption", "fx_ember_spray", "fx_magma_droplets"],
        ["fx_metal_splash", "fx_ice_burst", "fx_obsidian_burst", "fx_smoke_puff", "fx_heat_ripple"],
        ["fx_fire_swirl", "fx_shock_ring", "fx_shard_scatter", "fx_ground_crack", "fx_ash_plume"],
    ],
}


def row_bands(profile: np.ndarray, count: int) -> list[tuple[int, int]]:
    """Split the sheet vertically into `count` bands at the emptiest valleys.

    Rows are evenly spaced on every atlas, so each cut is searched inside a
    window around its ideal position and placed in the middle of the longest
    run of minimum density found there.
    """
    length = len(profile)
    step = length / count
    half_window = step * 0.42
    edges = [0]
    for k in range(1, count):
        lo = max(1, int(step * k - half_window))
        hi = min(length - 1, int(step * k + half_window))
        window = profile[lo:hi]
        floor = max(int(window.min()), NOISE_FLOOR)
        best_start = best_len = 0
        run_start = None
        for i, low in enumerate([*(window <= floor), False]):
            if low and run_start is None:
                run_start = i
            elif not low and run_start is not None:
                if i - run_start > best_len:
                    best_start, best_len = run_start, i - run_start
                run_start = None
        edges.append(lo + best_start + best_len // 2)
    edges.append(length)
    return list(zip(edges, edges[1:]))


def horizontal_spans(strip: np.ndarray, count: int) -> list[tuple[int, int]]:
    """Return `count` x-spans, one per sprite, from a single row of the sheet.

    Non-empty columns are grouped into blobs, then the closest neighbouring
    blobs are merged until exactly `count` groups remain. This reunites sprites
    whose loose embers or shards sit in their own columns without assuming the
    sprites are evenly sized.
    """
    density = strip.sum(axis=0)
    spans: list[list[int]] = []
    start = None
    for x, value in enumerate([*(density > NOISE_FLOOR), False]):
        if value and start is None:
            start = x
        elif not value and start is not None:
            spans.append([start, x, int(density[start:x].sum())])
            start = None

    if len(spans) < count:
        raise RuntimeError(f"row holds {len(spans)} blobs, fewer than the {count} expected sprites")

    # Always absorb the lightest blob first so stray shards and ember specks
    # rejoin their parent sprite before two whole sprites are ever merged.
    while len(spans) > count:
        i = min(range(len(spans)), key=lambda j: spans[j][2])
        # Weighting the gap by the neighbour's mass keeps scattered embers
        # clustering with each other rather than snapping onto a large sprite.
        candidates = []
        if i > 0:
            candidates.append((spans[i - 1][2] * (spans[i][0] - spans[i - 1][1] + 1), i - 1))
        if i < len(spans) - 1:
            candidates.append((spans[i + 1][2] * (spans[i + 1][0] - spans[i][1] + 1), i))
        j = min(candidates)[1]
        spans[j] = [spans[j][0], spans[j + 1][1], spans[j][2] + spans[j + 1][2]]
        del spans[j + 1]
    return [(a, b) for a, b, _ in spans]


def main() -> int:
    if os.path.isdir(OUT):
        shutil.rmtree(OUT)
    os.makedirs(OUT, exist_ok=True)

    total = 0
    for atlas, rows in ATLASES.items():
        image = Image.open(os.path.join(SRC, atlas + ".webp")).convert("RGBA")
        solid = np.array(image.getchannel("A")) > ALPHA_THRESHOLD

        for names, (top, bottom) in zip(rows, row_bands(solid.sum(axis=1), len(rows))):
            strip = solid[top:bottom, :]
            for name, (left, right) in zip(names, horizontal_spans(strip, len(names))):
                ys, _ = np.nonzero(strip[:, left:right])
                box = (left, top + int(ys.min()), right, top + int(ys.max()) + 1)
                image.crop(box).save(os.path.join(OUT, name + ".png"), optimize=True)
                total += 1
        print(f"{atlas}: {sum(len(r) for r in rows)} sprites")

    print(f"\n{total} sprites written to {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
