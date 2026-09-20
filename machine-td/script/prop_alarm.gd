extends "res://script/prop.gd"
## 路径末尾的警报器。
##
## 用 **Area2D 感应圈**判断敌人是否靠近：`detect` 是个圆形 Area2D，
##   · collision_layer = 0（自己不参与任何碰撞）
##   · collision_mask  = 2（只关心敌人那一层）
## 敌人（enemy.tscn 的根就是 Area2D，layer 2、在 "enemy" 组）一进圈就 area_entered。
##
## 比每帧扫 "enemy" 组便宜 —— 没敌人的时候引擎什么都不用做；
## 也不会因为场景里敌人多而变慢。
##
## 计数而不是布尔：多批敌人同时进出时不会算错。

## 感应圈半径（像素）。运行时会被同步到 detect/shape 上，改这里就行。
@export var trigger_radius := 280.0
## 敌人离开后再保持报警这么久（秒），免得刚打完一闪一闪
@export var release_delay := 1.2

## 当前圈里有几个敌人
var _inside := 0
## 还要维持报警多久
var _hot := 0.0

@onready var detect: Area2D = get_node_or_null("detect")


func _ready() -> void:
	super._ready()
	if detect != null:
		_apply_radius()
		detect.area_entered.connect(_on_entered)
		detect.area_exited.connect(_on_exited)
	_play("idle")


func _process(delta: float) -> void:
	if _inside > 0:
		_hot = release_delay
	elif _hot > 0.0:
		_hot = maxf(0.0, _hot - delta)
	var want := "alarm" if _hot > 0.0 else "idle"
	if anim != null and anim.animation != want:
		_play(want)


## 把 export 的半径同步到 CollisionShape2D —— 改半径不用去动场景
func _apply_radius() -> void:
	var cs := detect.get_node_or_null("shape") as CollisionShape2D
	if cs == null:
		return
	var circle := cs.shape as CircleShape2D
	if circle == null:
		return
	# 复制一份：同一个 .tscn 的实例默认共享 sub_resource，
	# 直接改会把所有警报器的形状一起改掉
	var c := circle.duplicate() as CircleShape2D
	c.radius = trigger_radius
	cs.shape = c


func _on_entered(a: Area2D) -> void:
	if a != null and a.is_in_group("enemy"):
		_inside += 1


func _on_exited(a: Area2D) -> void:
	if a != null and a.is_in_group("enemy"):
		_inside = maxi(0, _inside - 1)


# ⚠️ 参数别叫 name —— Node 自己就有 name 属性，会被遮蔽
func _play(anim_name: String) -> void:
	if anim == null or anim.sprite_frames == null:
		return
	if not anim.sprite_frames.has_animation(anim_name):
		return
	anim.play(anim_name)
