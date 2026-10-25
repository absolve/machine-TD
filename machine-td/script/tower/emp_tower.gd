extends "res://script/tower/tower.gd"

const EMP_COLOR := Color(0.2, 0.85, 1.0, 1.0) # 电磁主题色(青色)

#func _physics_process(delta: float) -> void:
	#super._physics_process(delta)

func _ready() -> void:
	rader.area_entered.connect(onRadarAreaEntered)
	rader.area_exited.connect(onRadarAreaExited)
	super._ready()

func onRadarAreaEntered(area: Area2D) -> void:
	if area is Enemy and not area.flying and not target.has(area):
		target.append(area)
		# 停摆期间进来的敌人先不减速，等停摆结束由 _physics_process 统一补上
		if not isDisabled():
			applySlow(area, true)
			slowApplied = true

func onRadarAreaExited(area: Area2D) -> void:
	target.erase(area)
	if area is Enemy and is_instance_valid(area):
		applySlow(area, false)
	if target.is_empty():
		slowApplied = false

## 本塔的减速强度：`atk` 当百分比用（atk=20 → 慢 20%）。
## EMP 在 TowerUpgradeManager 的 NON_UPGRADABLE 里，所以这个值在一局内不会变。
func slowRatio() -> float:
	# 强磁过载：生效期间减速强度 ×2（敌人那边会按"最强的一条"合并，不会和其他 EMP 叠加）
	var mul: float = float(skillDef.get("slowMul", 1.0)) if isSkillActive() else 1.0
	return clampf(float(atk) / 100.0 * mul, 0.0, 1.0)


## 减速**不再直接改 enemy.speed**，而是把"我是其中一个来源"登记到敌人身上。
##
## ⚠️ 这是本文件最关键的一处改动。旧实现是：
##     `enemy.speed = round(enemy.speed * (1 - ratio))`（进入）/ 再除回去（离开）。
##     两座 EMP 射程重叠时会连乘两次，离开时按各自比例除回 —— 只要两座塔的强度不同
##     或整数取整有误差，除回来就对不上原速，敌人速度会漂移。
##     现在敌人自己维护来源表、取**最强的一条**生效（见 enemy.gd::refreshSpeed），
##     所以「同一个敌人只会受到一座 EMP 塔的限制」，两座重叠也不会叠加。
## 停摆（强磁过载结束后 3 秒）期间本塔不提供减速。
## 用这个标志记住"当前有没有登记减速"，避免每帧重复 addSlow / removeSlow。
var slowApplied: bool = false

## 把减速**登记/注销**到范围内的所有敌人（技能强度变化、停摆进出都要重来一遍）。
func applySlowAll() -> void:
	for e in target:
		if is_instance_valid(e) and e is Enemy:
			e.addSlow(self, slowRatio())
	slowApplied = true


func releaseSlowAll() -> void:
	for e in target:
		if is_instance_valid(e) and e is Enemy:
			e.removeSlow(self)
	slowApplied = false


func applySlow(enemy: Enemy, enabled: bool) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enabled:
		enemy.addSlow(self, slowRatio())
	else:
		enemy.removeSlow(self)


## 技能强度变了（强磁过载开始/结束）：把新强度重新登记到所有在范围内的敌人身上。
## addSlow 对同一来源是覆盖语义，所以不用先 remove。
func onSkillModeChanged() -> void:
	super.onSkillModeChanged()
	if slowApplied and not isDisabled():
		applySlowAll()


## 停摆进出时同步减速：停摆中一个都不该被减速，结束后要补回来。
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if isDisabled():
		if slowApplied:
			releaseSlowAll()
	elif not slowApplied and not target.is_empty():
		applySlowAll()


func _exit_tree() -> void:
	# 塔被卖掉 / 场景卸载：必须把自己这个来源注销掉，否则敌人会一直背着这条减速
	for enemy in target:
		if is_instance_valid(enemy) and enemy is Enemy:
			enemy.removeSlow(self)


func _draw():
	# 未选中时保留原来的范围显示
	if not selected:
		draw_circle(Vector2.ZERO, radarScope, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.1))
		draw_arc(Vector2.ZERO, radarScope, 0, TAU, 64, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.1), 1.0)
		return
	# 选中时沿用父类的统一雷达扫描效果
	super._draw()
