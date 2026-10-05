extends Area2D

var blastRadius: float = 90.0 # 爆炸范围
var explosionScale: float = 1.0 # 爆炸动画缩放，根据爆炸范围调整
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
		aniNode.scale = Vector2.ONE * explosionScale
		# 只留它当"伤害生效的计时器"，不再显示 —— 爆炸的视觉统一由
		# ExplosionManage.playExplosion() 负责（动画+粒子+音效三件套）。
		# 不隐藏的话会和新的爆炸叠成两层，看着又乱又是旧素材。
		aniNode.visible = false
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
