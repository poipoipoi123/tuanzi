class_name SkillDB
extends RefCounted
## 技能数值表：纯数据，便于调参。

const SKILLS := {
    "tackle": {
        "name": "团子撞击", "type": "attack", "power": 14, "cost": 0,
        "desc": "用软软的身体撞过去，稳定可靠。",
    },
    "bubble": {
        "name": "泡泡弹", "type": "attack", "power": 20, "cost": 4,
        "desc": "吐出一串水泡，威力更胜一筹。",
    },
    "spark": {
        "name": "星尘火花", "type": "attack", "power": 26, "cost": 8,
        "desc": "凝聚星尘迸发，消耗较大。",
    },
    "heal": {
        "name": "暖暖舔舐", "type": "heal", "power": 24, "cost": 6,
        "desc": "舔舔伤口，恢复少量体力。",
    },
}

static func get_skill(id: String) -> Dictionary:
    return SKILLS.get(id, SKILLS["tackle"])
