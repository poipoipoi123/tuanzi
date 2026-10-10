class_name WorldArt
extends RefCounted
## 场景美术资源表：全部指向 Kenney CC0 开源素材包。
##
## 地面/土路/水面不再程序化绘制，而是由 tools/gen_ground.py 用 tiny_town +
## tiny_battle 的瓦片预合成成 assets/generated/ground_base.png，
## 由 WorldArt.ground_texture() 返回整张底图。
##
## 树/房/栅栏/路灯等立起来的装饰是 16px 的独立瓦片（不是 autotile），
## 用 WorldArt.deco_texture(kind, variant) 取图。
##
## 下面每个索引都是对着 tilemap_16x16.png 逐块核对出来的（12 列 x 11 行，
## index = 行 * 12 + 列）；改动前请先用 .tmp/ 下的对照脚本复核。

const TILE_PX := 16

## 素材包路径（Kenney, CC0 1.0）
const TOWN_TILES := "res://assets/tiles/kenney_tiny_town/tiles/tile_"
const BATTLE_TILES := "res://assets/tiles/kenney_tiny_battle/tiles/tile_"
const GROUND_IMAGE := "res://assets/generated/ground_base.png"
const TILE_NAMES := ["grass", "path", "water", "house", "tree", "stone", "fence", "lamp"]

## 树是两段式：上半截树冠 + 下半截树干。
## 配对依据 = 接缝要对得上：树冠底边实心段必须是 (4,11)，树干顶边也必须
## 是 (4,11)，否则两截之间会裂开一条缝。实测只有树冠 3/4/7/10 满足
## 底边 (4,11)；15/16/31/33 是同色系的树干。
const TREE_PAIRS := {
    0: [4, 16],    # 绿松树：绿冠 + 绿干
    1: [3, 15],    # 黄松树：秋冠 + 秋干
    2: [7, 31],    # 浅绿树
    3: [10, 33],   # 浅黄树
}

## 房屋是 5 格宽 x 3 格高的拼图，每排 5 块都写死，避免中段被重复贴成
## "三个一模一样的窗户/门"。两套配色：0 = 青石板顶 + 石墙，1 = 红瓦顶 + 砖墙。
## 中间一格留窗（63/67 是拱窗），地基中间一格留门（89/85 带门楣、实心不漏底；
## 74/78 是镂空的门洞，会把地面透出来，不能用）。
const HOUSE_ROOFS := {
    0: [48, 49, 49, 49, 50],   # 48 左封边 / 49 瓦面 / 50 右封边
    1: [52, 53, 53, 53, 54],
}
const HOUSE_WALLS := {
    0: [60, 61, 63, 61, 62],   # 60 左封边 / 61 墙面 / 63 拱窗 / 62 右封边
    1: [64, 65, 67, 65, 66],
}
const HOUSE_BASES := {
    0: [76, 77, 89, 77, 79],   # 76 左 / 77 石基 / 89 门 / 79 右
    1: [72, 73, 85, 73, 75],   # 72 左 / 73 砖基 / 85 门 / 75 右
}

## 单块用途的墙体 / 门。
## 注意 84 是"砖墙 + 窗"，不能当纯墙用；纯墙用 73（纯砖红填充）。
const HOUSE_WALL := 73
const HOUSE_DOOR := 85      # 居中的门（86/87 是左右偏的门）
const HOUSE_TRIM := 96      # 灰石墙

## 小道具
const PROP_TUFT := 1        # 草地上的草簇
const PROP_BUSH := 17       # 灌木（独立描边物件，立"在"草地上）
const PROP_STONE := 43      # 草地 + 石头
const PROP_FLOWER := 2      # 草地 + 黄花（29 是红蘑菇，不是花）

## 栅栏：45 = 两侧都出横栏的连续段；44/46 = 单侧出栏的收头；47 = 光立柱。
const FENCE_RAIL := 45
const FENCE_END_R := 44     # 横栏向右出
const FENCE_END_L := 46     # 横栏向左出
const FENCE_POST := 47

## 路灯（火焰灯柱）
const PROP_LAMP := 95

## 兼容旧调用：返回瓦片所在包的单张瓦片图。
static func tile_path(name: String) -> String:
    match name:
        "water":
            return BATTLE_TILES + "0037.png"
        "grass":
            return TOWN_TILES + "0000.png"
        "path":
            return TOWN_TILES + "0025.png"
        "stone":
            return TOWN_TILES + "0096.png"
        "tree", "house", "fence", "lamp":
            return deco_texture(name, 0)
    return ""

## 返回当前缺失的素材名列表（空数组表示素材齐备）。
static func missing_tiles() -> Array:
    var out: Array = []
    for n in TILE_NAMES:
        if SpriteLib.load_tex(tile_path(n)) == null:
            out.append(n)
    if SpriteLib.load_tex(GROUND_IMAGE) == null:
        out.append("ground")
    return out

## 整张地面底图（草地 + 土路 + 池塘），world 用它当背景。
static func ground_texture() -> Texture2D:
    return SpriteLib.load_tex(GROUND_IMAGE)

## 取 tiny_town 里第 index 号瓦片。
static func town_tile(index: int) -> Texture2D:
    return SpriteLib.load_tex(TOWN_TILES + "%04d.png" % index)

## 取 tiny_battle 里第 index 号瓦片（只有水面用得到）。
static func battle_tile(index: int) -> Texture2D:
    return SpriteLib.load_tex(BATTLE_TILES + "%04d.png" % index)

## 树：返回 [树冠, 树干] 两张瓦片（从上到下）。
static func tree_tiles(variant: int) -> Array:
    var keys := TREE_PAIRS.keys()
    var pair: Array = TREE_PAIRS[keys[variant % keys.size()]]
    return [town_tile(pair[0]), town_tile(pair[1])]

## 房屋：返回 [屋顶5块, 墙体5块, 地基5块]，每排从左到右，直接照抄即可。
static func house_tiles(variant: int) -> Array:
    var keys := HOUSE_ROOFS.keys()
    var v = keys[variant % keys.size()]
    return [HOUSE_ROOFS[v], HOUSE_WALLS[v], HOUSE_BASES[v]]

## 装饰贴图：house/tree/fence/lamp 的主图。
static func deco_texture(kind: String, variant: int) -> String:
    var index := 0
    match kind:
        "house":
            index = HOUSE_WALL
        "tree":
            var keys := TREE_PAIRS.keys()
            index = TREE_PAIRS[keys[variant % keys.size()]][1]
        "fence":
            index = FENCE_RAIL
        "lamp":
            index = PROP_LAMP
        _:
            return ""
    return TOWN_TILES + "%04d.png" % index
