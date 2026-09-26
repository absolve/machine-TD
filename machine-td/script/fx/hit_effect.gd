extends Node2D
## 子弹命中特效（**基场景**脚本）—— 粒子实现，**走对象池复用**。
##
## ⚠️ 它**不会 queue_free 自己**：播完只把 busy 置回 false，等池子下次取用。
##    子弹一秒能打十几发，每发都 new + free 一个节点很浪费。
##
## ⚠️⚠️ 位置问题（这里反复踩过，最后用三重保险堵死）：
##   池子里的节点**带着上一次命中的坐标**。如果它在空闲时还能被渲染到，
##   就会看到"先闪在旧位置、再跳过来"。
##   三重保险：
##     1) 空闲时 visible = false
##     2) 空闲时把节点挪到屏幕外（OFFSCREEN）—— 就算前两条都失效也看不见
##     3) play_at() 里严格按 藏 -> 定位 -> 起粒子 -> 显形 的顺序
##
## 贴图、颜色、数量全部配在场景里（或由派生场景覆盖导出变量），脚本不 load 贴图。

## 空闲时把节点扔到这个坐标（远在屏幕外）
const OFFSCREEN := Vector2(-100000, -100000)

@export var particle_texture: Texture2D
@export var hit_color := Color(1.0, 0.9, 0.7, 1.0)
@export var hit_amount := 10
@export var hit_scale := 0.7
@export var hit_duration := 0.5

## 池子用：true 表示正忙，不能借出去
var busy := false

@onready var _particles: CPUParticles2D = $particles

var _cd := 0.0


func _ready() -> void:
	z_index = 7
	visible = false
	set_process(false)
	global_position = OFFSCREEN
	_apply()
	_idle()


## 池子借出时调用：定位、重播粒子、开始计时
func play_at(pos: Vector2) -> void:
	# 1) 先藏 + 停粒子 —— 池子里的节点还带着上次的坐标，这一步保证不会闪在旧位置
	visible = false
	_particles.emitting = false
	# 2) 定位
	position = pos
	global_position = pos
	rotation = randf() * TAU
	# 3) 起粒子（restart 会清掉上一轮残留的粒子，按新位置重新发射）
	_particles.restart()
	_particles.emitting = true
	# 4) 全部就位了才显形
	busy = true
	_cd = hit_duration
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_cd -= delta
	if _cd <= 0.0:
		_idle()


## 回池：藏起来、停粒子、挪到屏幕外（但**不销毁**）
func _idle() -> void:
	visible = false
	busy = false
	if _particles != null:
		_particles.emitting = false
	global_position = OFFSCREEN
	set_process(false)


## 把导出变量应用到粒子节点上（派生场景改了导出值，这里统一落下去）
func _apply() -> void:
	if _particles == null:
		return
	if particle_texture != null:
		_particles.texture = particle_texture
	_particles.amount = hit_amount
	_particles.color = hit_color
	# local_coords = true 表示粒子坐标相对本节点 —— 必须这样，
	# 否则 restart() 可能按旧的全局坐标发射，位置就错到上一次的命中点去了
	_particles.local_coords = true
	scale = Vector2.ONE * hit_scale
