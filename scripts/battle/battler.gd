class_name Battler
extends RefCounted
## 战斗单位逻辑：纯数据 + 伤害计算，不涉及绘制，便于单独测试。

var data: Dictionary
var side: int        # 0 = 我方, 1 = 敌方

func _init(pet_id: String, level: int, p_side: int) -> void:
    data = PetDB.make_battler(pet_id, level)
    side = p_side

func is_alive() -> bool:
    return int(data["hp"]) > 0

func hp_ratio() -> float:
    var mx := maxi(1, int(data["max_hp"]))
    return clampf(float(data["hp"]) / float(mx), 0.0, 1.0)

func take_damage(amount: int) -> int:
    var dmg := maxi(1, amount)
    data["hp"] = maxi(0, int(data["hp"]) - dmg)
    return dmg

func heal(amount: int) -> int:
    var before := int(data["hp"])
    data["hp"] = mini(int(data["max_hp"]), before + maxi(0, amount))
    return int(data["hp"]) - before

## 伤害公式：攻防差 + 等级修正 + 技能威力，带 ±12% 随机浮动。
static func compute_damage(attacker: Dictionary, defender: Dictionary,
        skill: Dictionary, rng_value: float) -> int:
    var atk := float(attacker.get("atk", 10))
    var dfn := float(defender.get("def", 10))
    var power := float(skill.get("power", 10))
    var lv := float(attacker.get("level", 1))
    var base := (power + atk * 1.25 + lv * 0.9) - dfn * 0.85
    base = maxf(4.0, base)
    var variance := 0.88 + clampf(rng_value, 0.0, 1.0) * 0.24
    return maxi(1, int(round(base * variance)))

func skill_ids() -> Array:
    var s: Variant = data.get("skills", [])
    if typeof(s) != TYPE_ARRAY:
        return ["tackle"]
    return s
