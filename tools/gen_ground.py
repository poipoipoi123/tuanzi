#!/usr/bin/env python3
"""合成橡果小镇的地面底图（一张 2400x1600 的 PNG，16px 网格）。

素材全部来自 Kenney CC0 素材包：
  - 草地 / 土路：assets/tiles/kenney_tiny_town/
  - 水面：assets/tiles/kenney_tiny_battle/（tiny_town 没有水面；
    两个包的草地主色都是 84c669，拼在一起看不出跨包）

路面边缘用 tiny_town 自带的「草边瓦片」：这批瓦片的边缘是扇贝状的草，
每块自带一圈草，所以路面必须够宽（本脚本 PATH_HALF_W = 48，约 6 格），
否则两侧的草齿会把路啃成虚线。

BLOB 的键是 (上,下,左,右) —— 四条边是否挨着草地，由 gen_ground 的
blobs.py 按「边带 4px 内草色占比 >= 40%」实测得出，不是按角排序。

运行：python tools/gen_ground.py
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOWN = os.path.join(ROOT, 'assets', 'tiles', 'kenney_tiny_town', 'tiles')
BATTLE = os.path.join(ROOT, 'assets', 'tiles', 'kenney_tiny_battle', 'tiles')
OUT_DIR = os.path.join(ROOT, 'assets', 'generated')

TILE = 16
WORLD_W, WORLD_H = 2400, 1600
COLS, ROWS = WORLD_W // TILE, WORLD_H // TILE
SEED = 20261010

GRASS_BULK = 0
GRASS_TUFT = 1
WATER = 37

# (上,下,左,右) 哪边挨着草 -> tiny_town 瓦片。实测自 .tmp/eg.py。
BLOB = {
    (0, 0, 0, 0): 25,  # 纯沙，路面正中
    (1, 0, 0, 0): 13,  # 草在上
    (0, 1, 0, 0): 37,  # 草在下
    (0, 0, 1, 0): 24,  # 草在左
    (0, 0, 0, 1): 26,  # 草在右
    (1, 0, 0, 1): 14,  # 草在上+右
    (1, 0, 1, 0): 12,  # 草在上+左
    (0, 1, 0, 1): 38,  # 草在下+右
    (0, 1, 1, 0): 36,  # 草在下+左
}
SAND_FILL = 25

# 路面中轴线（沿用 world.gd 原先的折线）
PATH_PTS = [(0, 820), (500, 780), (1000, 830), (1500, 760), (2000, 820), (2400, 780)]
PATH_SPUR = ((1180, 830), (1180, 1180))
PATH_HALF_W = 48.0   # 半宽 -> 路面约 96px = 6 格

POND = (1180.0, 900.0, 176.0, 100.0)
# 房屋地基（沙地铺装），与 world.gd 的 _obstacles 大致对齐
PLAZAS = [
    (420.0, 430.0, 250.0, 190.0),
    (700.0, 360.0, 210.0, 170.0),
    (1780.0, 520.0, 254.0, 194.0),
]


def load_tile(pack, index):
    return Image.open(os.path.join(pack, 'tile_%04d.png' % index)).convert('RGBA')


def seg_dist(px, py, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length = dx * dx + dy * dy
    if length == 0:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * dx + (py - ay) * dy) / length
    t = max(0.0, min(1.0, t))
    return math.hypot(px - (ax + dx * t), py - (ay + dy * t))


def path_dist(x, y):
    best = 1e9
    for i in range(len(PATH_PTS) - 1):
        best = min(best, seg_dist(x, y, PATH_PTS[i], PATH_PTS[i + 1]))
    return min(best, seg_dist(x, y, PATH_SPUR[0], PATH_SPUR[1]))


def in_pond(x, y, grow=0.0):
    cx, cy, rx, ry = POND
    return ((x - cx) / (rx + grow)) ** 2 + ((y - cy) / (ry + grow)) ** 2 <= 1.0


def in_plaza(x, y):
    for px_, py_, pw, ph in PLAZAS:
        if abs(x - px_) <= pw * 0.5 and abs(y - py_) <= ph * 0.5:
            return True
    return False


def blob_index(mask):
    """查 BLOB；缺 3 草角/1 格宽的极端形状时逐个放宽草边，最后退回纯沙。"""
    index = BLOB.get(mask)
    if index is not None:
        return index
    for drop in range(4):
        relaxed = list(mask)
        relaxed[drop] = 0
        index = BLOB.get(tuple(relaxed))
        if index is not None:
            return index
    return SAND_FILL


def main():
    rng = random.Random(SEED)

    # 1) 分格：草地 / 沙地 / 水面
    is_water = [[False] * COLS for _ in range(ROWS)]
    is_sand = [[False] * COLS for _ in range(ROWS)]
    for gy in range(ROWS):
        for gx in range(COLS):
            wx, wy = (gx + 0.5) * TILE, (gy + 0.5) * TILE
            if in_pond(wx, wy):
                is_water[gy][gx] = True
            elif path_dist(wx, wy) <= PATH_HALF_W:
                is_sand[gy][gx] = True
            elif in_plaza(wx, wy):
                is_sand[gy][gx] = True
            elif in_pond(wx, wy, TILE * 1.2):   # 池塘外圈一圈沙地当河岸
                is_sand[gy][gx] = True

    # 2) 拼图。判边时把水面也算作「非草」，这样水面外围会得到干净的沙岸。
    def open_at(gx, gy):
        if gx < 0 or gy < 0 or gx >= COLS or gy >= ROWS:
            return False
        return is_sand[gy][gx] or is_water[gy][gx]

    canvas = Image.new('RGBA', (COLS * TILE, ROWS * TILE), (0, 0, 0, 255))
    for gy in range(ROWS):
        for gx in range(COLS):
            x0, y0 = gx * TILE, gy * TILE
            if is_water[gy][gx]:
                canvas.alpha_composite(load_tile(BATTLE, WATER), (x0, y0))
                continue
            if not is_sand[gy][gx]:
                canvas.alpha_composite(load_tile(TOWN, GRASS_BULK), (x0, y0))
                if rng.random() < 0.16:
                    canvas.alpha_composite(load_tile(TOWN, GRASS_TUFT), (x0, y0))
                continue
            mask = (
                0 if open_at(gx, gy - 1) else 1,   # 上
                0 if open_at(gx, gy + 1) else 1,   # 下
                0 if open_at(gx - 1, gy) else 1,   # 左
                0 if open_at(gx + 1, gy) else 1,   # 右
            )
            canvas.alpha_composite(load_tile(TOWN, blob_index(mask)), (x0, y0))

    os.makedirs(OUT_DIR, exist_ok=True)
    out = os.path.join(OUT_DIR, 'ground_base.png')
    canvas.save(out)
    print('wrote %s (%dx%d)' % (out, canvas.size[0], canvas.size[1]))


if __name__ == '__main__':
    main()
