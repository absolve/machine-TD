extends "res://script/tower.gd"


var drone = preload("res://scene/drone.tscn")

const DRONE_COUNT := 3 # 无人机数量
var drones: Array = [] # 已生成的无人机


func _ready():
	# 给雷达添加检测形状和信号(代码中完成,不重构场景)
	if not raderShape.shape:
		raderShape.shape = CircleShape2D.new()
	rader.area_entered.connect(_on_radar_area_entered)
	rader.area_exited.connect(_on_radar_area_exited)
	super._ready()
	

func init():
	super.init()
	_spawn_drones()


# 生成3架无人机围绕基地飞行
func _spawn_drones():
	for i in range(DRONE_COUNT):
		var d = drone.instantiate()
		Game.addObj(d)
		d.home_base = self
		d.orbit_angle = TAU * i / DRONE_COUNT # 均匀分布起始角度
		drones.append(d)


func _on_radar_area_entered(area):
	target.push_back(area)


func _on_radar_area_exited(area):
	target.erase(area)


func _on_btn_sell_pressed():
	# 出售时清除所有无人机
	for d in drones:
		if is_instance_valid(d):
			d.queue_free()
	drones.clear()
	super._on_btn_sell_pressed()
