class_name PetDB
extends RefCounted
## 团子兽图鉴：原创物种，全程序化绘制。

const PETS := {
    "grass": {
        "name": "草团子兽", "element": "草",
        "hp": 52, "atk": 13, "def": 9, "spd": 11,
        "body": "8fd67a", "edge": "6aa858", "horn": "5b9448",
        "skills": ["tackle", "bubble"],
        "desc": "在草地上打滚长大的小兽，头顶嫩芽。",
    },
    "water": {
        "name": "水团子兽", "element": "水",
        "hp": 58, "atk": 11, "def": 11, "spd": 9,
        "body": "8fd3e8", "edge": "66a8c4", "horn": "5a9ec0",
        "skills": ["tackle", "bubble", "heal"],
        "desc": "住在池塘边，身上总是湿漉漉的。",
    },
    "spark": {
        "name": "星团子兽", "element": "星",
        "hp": 46, "atk": 16, "def": 7, "spd": 14,
        "body": "f7d98a", "edge": "d9b24e", "horn": "e0a83c",
        "skills": ["tackle", "spark"],
        "desc": "夜里会微微发光，据说是星尘变的。",
    },
}

const WILD_POOL := ["grass", "water", "spark"]

static func get_pet(id: String) -> Dictionary:
    return PETS.get(id, PETS["grass"])

static func make_battler(id: String, level: int) -> Dictionary:
    var base: Dictionary = get_pet(id)
    var lv := maxi(1, level)
    var max_hp: int = int(base["hp"]) + lv * 6
    return {
        "id": id,
        "name": base["name"],
        "element": base["element"],
        "level": lv,
        "max_hp": max_hp,
        "hp": max_hp,
        "atk": int(base["atk"]) + int(lv * 1.6),
        "def": int(base["def"]) + int(lv * 1.1),
        "spd": int(base["spd"]) + int(lv * 0.8),
        "body": base["body"], "edge": base["edge"], "horn": base["horn"],
        "skills": base["skills"],
        "desc": base["desc"],
    }
