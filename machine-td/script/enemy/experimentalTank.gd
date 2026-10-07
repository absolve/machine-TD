extends "res://script/enemy/enemy.gd"
## 实验坦克：搭载 **4 座独立炮塔** 的重装地面单位。
##
## 车体本身不参战 —— 4 座子炮塔（[BaseTurret]，`ownerType = ENEMY`）各自索敌、转向、开火；
## 车体只负责沿路径推进与承受伤害，所以这里**不需要**覆写 `fire()` 或 `_physics_process()`，
## 移动 / 逃脱结算全部沿用基类 [Enemy] 的实现。
##
## ⚠️ `Game.enemyInfo` 里该敌人的 atk / shootDelay / scope 是**单座炮塔**的数值，
##    整车理论火力 = 4 倍；4 座炮塔的实际数值在场景 Inspector 里设置。


func _ready() -> void:
	parent = get_parent() as PathFollow2D
	setupEnemyInfo()
