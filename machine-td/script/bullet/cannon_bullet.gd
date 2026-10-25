extends "res://script/bullet/bullet.gd"

## 伤害类型：physical 会被敌人的 armor 减免，energy 无视护甲。
## 破甲弹技能（加农炮 toggle 之外的 timed 技能）就是把它切到 energy。
@export var damageType: String = "physical"


func _ready() -> void:
	alignToAngle()
	lifetime = 3.0
	vec = Vector2(500, 0).rotated(angle)
	#damage = source_tower.atk if is_instance_valid(source_tower) else 30


func _physics_process(delta: float) -> void:
	timer += delta
	position += vec * delta
	if timer > lifetime:
		queue_free()
	var temp = get_overlapping_areas()
	if temp:
		for i in temp:
			if i.has_method("hurt"):
				# 带上发射者，敌人死亡时才能把经验算给这座塔
				i.hurt(damage, sourceTower, damageType)
		spawnHitEffect()
		queue_free()
