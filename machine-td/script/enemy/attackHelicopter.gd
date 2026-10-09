extends "res://script/enemy/enemy.gd"

# 攻击直升机：空中对抗型敌人

var bullet: PackedScene = preload("res://scene/bullet/enemy_bullet.tscn")
const ROTOR_SPIN_SPEED: float = 18.0

@onready var rotor: Sprite2D = $Rotor


func _ready() -> void:
	parent = get_parent() as PathFollow2D
	setupEnemyInfo()


func fire(towerTarget: Node2D) -> void:
	if not is_instance_valid(towerTarget):
		return
	if canShot:
		canShot = false
		var b = bullet.instantiate()
		# 用 get_muzzle_position()：本场景**没有 turret 节点**，
		# 直接写 turret.global_position 一开火就崩。没有炮塔时它退回机身前方。
		var muzzle: Vector2 = getMuzzlePosition()
		b.global_position = muzzle
		# 瞄着目标发射，而不是顺着炮塔当时的朝向（炮塔没转到位时那会打偏）
		b.angle = (towerTarget.global_position - muzzle).angle()
		b.damage = atk
		b.target = towerTarget
		Game.addObj(b)
		# 开火音：每个敌人一种，带音高抖动，连射时不会听着像复读
		SoundManage.playAt("mg_fire_b", muzzle, -8.0, randf_range(0.94, 1.08))
		delayTimer.start()


func _physics_process(delta: float) -> void:
	if points.size() == 0:
		return
	parent.progress += speed * delta
	if parent.progress_ratio >= 1:
		Game.enemyEscaped.emit(lossPoints)
		freeSelf()
	# 取最近的**有效**目标，并把炮塔转过去；到位了才开火。
	# 原来这里既不看最近、也不转炮塔，子弹顺着炮塔当时的朝向飞 —— 就是"胡乱攻击"。
	var temp = pickTarget()
	if temp != null and aimAt(temp, delta):
		fire(temp)


func _process(delta: float) -> void:
	rotor.rotation = wrapf(rotor.rotation + ROTOR_SPIN_SPEED * delta, 0.0, TAU)
