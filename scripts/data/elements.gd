class_name ElementDB
extends RefCounted
## 属性克制表：纯数据 + 查表，改平衡只需改 STRONG。

const ELEMENTS := ["草", "水", "星"]

## 攻击方 -> 被克制的属性集合（造成 2 倍伤害）
const STRONG := {
    "草": ["水"],
    "水": ["星"],
    "星": ["草"],
}

## 返回伤害倍率：2.0 克制 / 0.5 被抗 / 1.0 中性。
static func effectiveness(attacker: String, defender: String) -> float:
    if not STRONG.has(attacker):
        return 1.0
    var beats: Array = STRONG[attacker]
    if beats.has(defender):
        return 2.0
    # 反向：若防守方克制攻击方，则攻击方吃 0.5 倍
    if STRONG.has(defender) and (STRONG[defender] as Array).has(attacker):
        return 0.5
    return 1.0
