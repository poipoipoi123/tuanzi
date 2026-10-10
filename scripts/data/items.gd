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
    "capture_ball": { "name": "团子球", "type": "capture", "power": 1, "price": 30,
        "desc": "基础捕捉道具，对残血的团子兽效果更好。" },
    "capture_ball_good": { "name": "好团子球", "type": "capture", "power": 2, "price": 90,
        "desc": "成功率更高的捕捉道具。" },
    "capture_ball_great": { "name": "高级团子球", "type": "capture", "power": 3, "price": 240,
        "desc": "对稀有团子兽也相当可靠。" },
}

static func get_item(id: String) -> Dictionary:
    return ITEMS.get(id, {})
