class_name Growth
extends RefCounted
## 小团子四维属性成长：纯逻辑，可测。

const ATTRS := ["str", "vit", "agi", "int"]
const POINTS_PER_LEVEL := 3
const HP_PER_VIT := 4
const ATK_PER_STR := 1.5

## 到 level 级时累计应得点数（不含已花费）。
static func points_for_level(level: int) -> int:
    return maxi(0, (maxi(1, level) - 1) * POINTS_PER_LEVEL)

## 分配 count 点到 attr。返回新的 { attrs, points }。
## 点数不足时只分配剩余部分。
##
## available 是「当前可用点数上限」：
##   available >= 0：受上限约束，只加 min(count, available) 点，
##                  返回的 points 是分配后剩余的可用点数。
##   available < 0 ：不限点数，count 全部加上，返回的 points 回显 count（即本次用掉的点数）。
##
## 偏离说明：阶段二计划任务 5 给出的原始实现体恒返回 points = 0，
## 且其自检对同一入参同时要求 points == 2 与 points == 0，自相矛盾。
## 这里改为「显式传入点数上限」的契约，使「剩余点数」与「本次花费」都可被断言。
static func spend(attrs: Dictionary, attr: String, count: int, available: int = -1) -> Dictionary:
    var a: Dictionary = attrs.duplicate(true)
    if not a.has(attr):
        return { "attrs": a, "points": maxi(0, available) if available >= 0 else maxi(0, count) }
    var want := maxi(0, count)
    var take := want if available < 0 else mini(want, maxi(0, available))
    a[attr] = int(a[attr]) + take
    var left: int = (maxi(0, available) - take) if available >= 0 else want
    return { "attrs": a, "points": maxi(0, left) }

## 属性点带来的派生收益。
static func stat_bonus(points: int, attr: String) -> int:
    var p := maxi(0, points)
    match attr:
        "str": return int(round(p * ATK_PER_STR))
        "vit": return p * HP_PER_VIT
        "agi": return int(round(p * 0.8))
        "int": return int(round(p * 1.1))
    return 0

## 升级带来的固定成长（与 GameState.gain_exp 的增量一致）：
## 每级 攻+2 防+2 速+1 上限+8。1 级时与 derive(attrs) 的基准完全相同。
const ATK_PER_LEVEL := 2
const DEF_PER_LEVEL := 2
const SPD_PER_LEVEL := 1
const HP_PER_LEVEL := 8

## 从四维属性 + 等级推导战斗数值。
## 偏离说明：计划只给出 derive(attrs)（等价于 1 级），若直接用它覆盖 player，
## 会在每次加点时抹掉 gain_exp 累积的等级成长。故另加本函数把等级层叠回去，
## 同时保留计划原样的 derive(attrs)。
static func derive_at(attrs: Dictionary, level: int) -> Dictionary:
    var d: Dictionary = derive(attrs)
    var up: int = maxi(0, maxi(1, level) - 1)
    return {
        "atk": int(d["atk"]) + up * ATK_PER_LEVEL,
        "max_hp": int(d["max_hp"]) + up * HP_PER_LEVEL,
        "spd": int(d["spd"]) + up * SPD_PER_LEVEL,
        "def": int(d["def"]) + up * DEF_PER_LEVEL,
    }

## 从四维属性推导战斗数值。
static func derive(attrs: Dictionary) -> Dictionary:
    return {
        "atk": 12 + stat_bonus(int(attrs.get("str", 0)), "str"),
        "max_hp": 60 + stat_bonus(int(attrs.get("vit", 0)), "vit"),
        "spd": 10 + stat_bonus(int(attrs.get("agi", 0)), "agi"),
        "def": 10 + stat_bonus(int(attrs.get("int", 0)), "int"),
    }
