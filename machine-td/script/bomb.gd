extends Area2D

@onready var aniNode = $ani
@onready var shapeNode = $shape

var blastRadius: float = 90.0 # 爆炸范围
var explosionScale: float = 1.0 # 爆炸动画缩放，根据爆炸范围调整
var damage: int = 40 # 伤害
var source_tower: Tower = null
var source: Node = null
var damage_type: String = "physical"
var hasDamage: bool = false
var processed_enemies: Array[Enemy] = []
var processed_towers: Array[Tower] = []

# 由 collision_mask 决定爆炸能命中哪些对象。
# 例如：敌人通常在 layer 2，塔通常在 layer 1。
# 这样炸弹脚本不需要手写敌人/塔分支判定。
var target_mask: int = 0

func _ready():
	if shapeNode and shapeNode.shape is CircleShape2D:
		shapeNode.shape.radius = blastRadius
	if blastRadius > 0:
		explosionScale = clamp(blastRadius / 90.0, 0.7, 3.0)
	if aniNode:
		aniNode.scale = Vector2.ONE * explosionScale
	if source == null:
		source = source_tower
	if target_mask != 0:
		collision_mask = target_mask
	aniNode.play("default")

func _physics_process(_delta):
	if hasDamage:
		return

	var targets = get_overlapping_areas()
	for area in targets:
		if area is Enemy:
			if area in processed_enemies:
				continue
			processed_enemies.append(area)
			if collision_mask & (1 << 1):
				var distance = area.global_position.distance_to(global_position)
				if distance <= blastRadius:
					area.hurt(damage, source, damage_type)
			continue
		if area is Tower:
			if area in processed_towers:
				continue
			processed_towers.append(area)
			if collision_mask & (1 << 0):
				var distance = area.global_position.distance_to(global_position)
				if distance <= blastRadius:
					area.hurt(damage, source, damage_type)

func _on_ani_frame_changed():
	if not hasDamage and aniNode.frame >= 1:
		hasDamage = true

func _on_ani_animation_finished():
	queue_free()
