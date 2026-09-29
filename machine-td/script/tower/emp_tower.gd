extends "res://script/tower/tower.gd"

const EMP_COLOR := Color(0.2, 0.85, 1.0, 1.0) # 电磁主题色(青色)

#func _physics_process(delta: float) -> void:
	#super._physics_process(delta)

func _ready() -> void:
	rader.area_entered.connect(_onRadarAreaEntered)
	rader.area_exited.connect(_onRadarAreaExited)
	super._ready()

func _onRadarAreaEntered(area: Area2D) -> void:
	if area is Enemy and not area.flying and not target.has(area):
		target.append(area)
		_applySlow(area, true)

func _onRadarAreaExited(area: Area2D) -> void:
	target.erase(area)
	if area is Enemy and is_instance_valid(area):
		_applySlow(area, false)

func _applySlow(enemy: Enemy, enabled: bool) -> void:
	var slowRatio: float = clampf(float(atk) / 100.0, 0.0, 1.0)
	if enabled:
		enemy.speed = int(round(enemy.speed * (1.0 - slowRatio)))
	elif slowRatio < 1.0:
		enemy.speed = int(round(enemy.speed / (1.0 - slowRatio)))


func _exit_tree() -> void:
	for enemy in target:
		if is_instance_valid(enemy) and enemy is Enemy:
			_applySlow(enemy, false)


func _draw():
	# 未选中时保留原来的范围显示
	if not selected:
		draw_circle(Vector2.ZERO, radarScope, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.1))
		draw_arc(Vector2.ZERO, radarScope, 0, TAU, 64, Color(EMP_COLOR.r, EMP_COLOR.g, EMP_COLOR.b, 0.1), 1.0)
		return
	# 选中时沿用父类的统一雷达扫描效果
	super._draw()
