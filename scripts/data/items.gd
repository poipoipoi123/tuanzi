class_name ItemDB
extends RefCounted
## 道具表。

const ITEMS := {
    "berry": { "name": "甜浆果", "type": "heal", "power": 30, "price": 20,
        "desc": "野外常见的红浆果，恢复 30 点体力。" },
    "star_dust": { "name": "星尘", "type": "material", "power": 0, "price": 60,
        "desc": "夜里凝结的微光碎屑，强化装备用得上。" },
    "honey": { "name": "花蜜罐", "type": "buff", "power": 5, "price": 45,
        "desc": "战斗中使用，本场攻击 +5。" },
}

static func get_item(id: String) -> Dictionary:
    return ITEMS.get(id, {})
