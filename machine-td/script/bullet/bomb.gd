extends Area2D

var blastRadius: float = 90.0 # 爆炸范围
var explosionScale: float = 1.0 # 爆炸动画缩放，根据爆炸范围调整

## 动画贴图相对"1 单位 = blastRadius 90 时正好铺满"的换算系数。
##
## 现在用的是新素材 `sprite/fx/explo_big_*.png`（256px，来自 VFX Free Pack 的大爆炸），
## 而原来那套 `explosionSmoke*.png` 只有 ~60px。旧公式按"贴图 90px 宽"定的，
## 直接套到 256px 上会让爆炸大出四倍多 —— 所以这里补一个系数把它压回来。
## 想换帧序/改成别的爆炸时，只改这一个数即可（不必动下面的公式）。
const SHEET_SCALE := 0.22

var damage: int = 40 # 伤害
var sourceTower: Tower = null
var source: Node = null
var damageType: String = "physical"
var hasDamage: bool = false
var filterFlyingTargets: bool = false
var targetFlying: bool = false
var processedEnemies: Array[Enemy] = []
var processedTowers: Array[Tower] = []

@onready var aniNode: AnimatedSprite2D = $Ani
@onready var shapeNode: CollisionShape2D = $shape

# 由 collision_mask 决定爆炸能命中哪些对象。
# 例如：敌人通常在 layer 2，塔通常在 layer 1。
# 这样炸弹脚本不需要手写敌人/塔分支判定。
var targetMask: int = 0

func _ready() -> void:
	if shapeNode and shapeNode.shape is CircleShape2D:
		shapeNode.shape.radius = blastRadius
	if blastRadius > 0:
		explosionScale = clamp(blastRadius / 90.0, 0.7, 3.0)
	if aniNode:
		# SHEET_SCALE 把"按 blastRadius 算出的缩放"换算到实际贴图尺寸（见常量注释）
		aniNode.scale = Vector2.ONE * explosionScale * SHEET_SCALE
		# ★ bomb **显示自己的动画**作为爆炸视觉（现在是 sprite/fx/explo_big_*.png）。
		#   之前这里写过 `aniNode.visible = false`（那时视觉统一交给 ExplosionManage），
		#   现在改回由 bomb 自己显示 —— 所以**调用方不要再叠一次
		#   ExplosionManage.playExplosion()**，否则同一位置会同时出现两套爆炸。
		#   动画同时兼任"伤害生效的计时器"：onAniFrameChanged 在 frame>=1 时置 hasDamage。
		#aniNode.visible = true
	if source == null:
		source = sourceTower
	if targetMask != 0:
		collision_mask = targetMask
	aniNode.play("default")


func onAniFrameChanged() -> void:
	if not hasDamage and aniNode.frame >= 1:
		hasDamage = true


func onAniAnimationFinished() -> void:
	queue_free()


func _physics_process(_delta: float) -> void:
	if hasDamage:
		return

	var targets = get_overlapping_areas()
	for area in targets:
		if area is Enemy:
			if filterFlyingTargets and area.flying != targetFlying:
				continue
			if area in processedEnemies:
				continue
			processedEnemies.append(area)
			if collision_mask & (1 << 1):
				var distance = area.global_position.distance_to(global_position)
				if distance <= blastRadius:
					area.hurt(damage, source, damageType)
			continue
		if area is Tower:
			if area in processedTowers:
				continue
			processedTowers.append(area)
			if collision_mask & (1 << 0):
				var distance = area.global_position.distance_to(global_position)
				if distance <= blastRadius:
					area.hurt(damage, source, damageType)
