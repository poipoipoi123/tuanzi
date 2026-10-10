class_name Capture
extends RefCounted
## 收服成功率：纯函数，便于调参与测试。

const MIN_RATE := 0.05
const MAX_RATE := 0.98
const LOW_HP_BONUS := 2.2      # 残血加成强度

## hp_ratio: 目标当前血量比例(0..1)
## ball_power: 捕捉道具威力（1 基础 / 2 中级 / 3 高级）
## level_gap_bonus: 额外加成，来自等级差或状态
static func rate(hp_ratio: float, ball_power: int, level_gap_bonus: float) -> float:
    var low := clampf(hp_ratio, 0.0, 1.0)
    # 血量越低，加成越大（1.0 -> 0，0.0 -> LOW_HP_BONUS）
    var hp_factor := (1.0 - low) * LOW_HP_BONUS
    var base := 0.10 + hp_factor * 0.28
    var ball_factor := 1.0 + (maxf(1.0, float(ball_power)) - 1.0) * 0.45
    var r := base * ball_factor * (1.0 + maxf(0.0, level_gap_bonus))
    return clampf(r, MIN_RATE, MAX_RATE)

## 掷骰：roll 属于 [0,1)，小于成功率即收服成功。
static func attempt(hp_ratio: float, ball_power: int, level_gap_bonus: float,
        roll: float) -> bool:
    return roll < rate(hp_ratio, ball_power, level_gap_bonus)
