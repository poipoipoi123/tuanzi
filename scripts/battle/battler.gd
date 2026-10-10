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

## 伤害公式：威力 + 攻击 + 等级 - 防御，乘属性克制，再乘随机浮动。
static func compute_damage(attacker: Dictionary, defender: Dictionary,
        skill: Dictionary, rng_value: float) -> int:
    var atk := float(attacker.get("atk", 10))
    var dfn := float(defender.get("def", 10))
    var power := float(skill.get("power", 10))
    var lv := float(attacker.get("level", 1))
    var base := (power + atk * 1.25 + lv * 0.9) - dfn * 0.85
    base = maxf(4.0, base)
    var elem := ElementDB.effectiveness(
        String(attacker.get("element", "")), String(defender.get("element", "")))
    var variance := 0.88 + clampf(rng_value, 0.0, 1.0) * 0.24
    return maxi(1, int(round(base * elem * variance)))

const CRIT_MULTIPLIER := 1.6
const CRIT_BASE_RATE := 0.06        # 基础暴击率
const CRIT_SPD_BONUS := 0.0015      # 每点速度增加的暴击率
const DODGE_BASE := 0.03            # 基础闪避率
const DODGE_SPD_FACTOR := 0.0022    # 速度差对闪避的影响

## 暴击率：基础 + 自身速度加成，上限 0.6。
static func crit_chance(attacker: Dictionary) -> float:
    var spd := float(attacker.get("spd", 10))
    return minf(0.6, CRIT_BASE_RATE + spd * CRIT_SPD_BONUS)

## 闪避率：基础 + 双方速度差，限制在 0.02..0.45。
static func dodge_chance(attacker: Dictionary, defender: Dictionary) -> float:
    var diff := float(defender.get("spd", 10)) - float(attacker.get("spd", 10))
    return clampf(DODGE_BASE + diff * DODGE_SPD_FACTOR, 0.02, 0.45)

## 完整一次攻击结算：命中判定 -> 伤害 -> 暴击判定。
## 三个随机数分开传入，便于测试确定性。
static func resolve_attack(attacker: Dictionary, defender: Dictionary, skill: Dictionary,
        rng_value: float, hit_roll: float, crit_roll: float) -> Dictionary:
    if hit_roll < dodge_chance(attacker, defender):
        return { "hit": false, "crit": false, "damage": 0 }
    var dmg := compute_damage(attacker, defender, skill, rng_value)
    var is_crit := crit_roll < crit_chance(attacker)
    if is_crit:
        dmg = maxi(1, int(round(dmg * CRIT_MULTIPLIER)))
    return { "hit": true, "crit": is_crit, "damage": dmg }

func skill_ids() -> Array:
    var s: Variant = data.get("skills", [])
    if typeof(s) != TYPE_ARRAY:
        return ["tackle"]
    return s
