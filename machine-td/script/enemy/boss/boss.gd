extends "res://script/enemy/enemy.gd"
## Boss 基类（设计见 feature_design.md §十九）。
##
## 公共部分：
##   · 从 enemyInfo 读 Boss 专属字段（tier / 光环颜色 / 光环半径）
##   · 地面画一圈本类型颜色的**脉冲光环** —— 在没有专属美术之前，
##     这是"一眼认出这是 boss"的主要手段（零额外资源，复用范围圈的画法）
##   · 召唤 / 分裂用的路线工具（在自己当前位置或稍后方生成敌人）
##
## ⚠️ 子类 `_ready()` 必须调 `super._ready()`，否则 parent 与数值都不会初始化。

## bossTier 由 enemy.gd 声明（setupEnemyInfo 里从 enemyInfo 读），这里不能重复声明
var bossAuraColor: Color = Color(0.95, 0.55, 0.25, 1.0)
var auraRadius: float = 96.0
var auraPhase: float = 0.0
## 免疫减速（只有大 boss 的二阶段用）
var immuneSlow: bool = false


func _ready() -> void:
	parent = get_parent() as PathFollow2D
	setupEnemyInfo()
	readBossInfo()


func readBossInfo() -> void:
	var info: Dictionary = Game.enemyInfo.get(enemyType, {})
	bossAuraColor = info.get("bossAuraColor", bossAuraColor)
	auraRadius = float(info.get("scope", 0.0))
	if auraRadius <= 0.0:
		auraRadius = 96.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	auraPhase = fmod(auraPhase + delta * 1.6, TAU)
	# Boss 不显示头顶血条：它的血条是顶部那一条大血条（§19.7 第 6 条）。
	# 每帧压一次 —— hurt() 里的 flashFor() 会把 lifeBar 重新显示出来。
	if lifeBar != null and lifeBar.visible:
		lifeBar.visible = false
	queue_redraw()


func _draw() -> void:
	# 基类只在"被选中"时画攻击范围圈；光环是 Boss 的**常驻**标识，不受选中影响
	super._draw()
	if auraRadius <= 0.0:
		return
	var pulse: float = 0.5 + 0.5 * sin(auraPhase)
	var fill: Color = Color(bossAuraColor.r, bossAuraColor.g, bossAuraColor.b,
		0.07 + 0.05 * pulse)
	var edge: Color = Color(bossAuraColor.r, bossAuraColor.g, bossAuraColor.b,
		0.45 + 0.25 * pulse)
	draw_circle(Vector2.ZERO, auraRadius, fill)
	draw_arc(Vector2.ZERO, auraRadius, 0.0, TAU, 64, edge, 3.0)
	draw_arc(Vector2.ZERO, auraRadius * 0.55, 0.0, TAU, 48,
		Color(edge.r, edge.g, edge.b, edge.a * 0.6), 2.0)


## 免疫减速时直接吞掉"登记减速"这一步。
## 不走"把 ratio 设 0"的做法：那样敌人身上会留一条假记录，恢复时又得处理。
func addSlow(source: Object, ratio: float) -> void:
	if immuneSlow:
		return
	super.addSlow(source, ratio)


func currentRoute() -> Path2D:
	if parent != null and parent.get_parent() is Path2D:
		return parent.get_parent() as Path2D
	return null


func routeIndex() -> int:
	var route: Path2D = currentRoute()
	var level = Game.map.level if Game.map != null else null
	if route == null or level == null or not ("routes" in level):
		return 1
	var i: int = level.routes.find(route)
	return i + 1 if i >= 0 else 1


## 在自己**稍后方**生成一个敌人（召唤 / 分裂用）。
## `back` > 0 表示落后多少像素 —— 不落后就会和本体完全重叠。
func summonAt(enemyKind: int, back: float, hpScale: float = 1.0,
		props: Dictionary = {}, lateral: float = 0.0) -> void:
	var level = Game.map.level if Game.map != null else null
	if level == null or not level.has_method("spawnEnemy"):
		return
	var info: Dictionary = {"type": enemyKind, "route": routeIndex()}
	if parent is PathFollow2D:
		info["progress"] = maxf(0.0, (parent as PathFollow2D).progress - back)
	# 横向错开：只靠 progress 前后错开会挤成一条线，弯道上尤其明显
	if not is_zero_approx(lateral):
		info["offset"] = lateral
	if not is_equal_approx(hpScale, 1.0):
		info["hpScale"] = hpScale
	if not props.is_empty():
		info["props"] = props
	level.call("spawnEnemy", info)


## 射击型 Boss 的通用开火：先瞄准，到位才打（否则子弹会顺着旧朝向飞出去）
func tickShooter(delta: float) -> void:
	var tower: Tower = pickTowerTarget()
	if tower == null:
		return
	if aimAt(tower, delta) and canShot:
		attackTower(tower)


## 同屏敌人数量（召唤前查，避免把画面挤爆）
func aliveEnemyCount() -> int:
	return get_tree().get_nodes_in_group("enemy").size()
