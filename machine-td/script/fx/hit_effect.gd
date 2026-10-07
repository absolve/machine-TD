extends Node2D
## 子弹命中特效（**基场景**脚本）—— 粒子实现，**走对象池复用**。
##
## ⚠️ 它**不会 queue_free 自己**：播完只把 busy 置回 false，等池子下次取用。
##    子弹一秒能打十几发，每发都 new + free 一个节点很浪费。
##
## ⚠️⚠️ 位置问题（这里反复踩过）：
##   池子里的节点**带着上一次命中的坐标**。如果它在空闲时还能被渲染到，
##   就会看到"先闪在旧位置、再跳过来"。
##   现在的两条保险：
##     1) 空闲时 visible = false（唯一需要的手段）
##     2) play_at() 里严格按 藏 -> 定位 -> 起粒子 -> 显形 的顺序
##
##   ★ 曾经还有第三条"空闲时把节点挪到屏幕外（OFFSCREEN = -100000,-100000）"，
##     那条**已经被删掉**，因为它自己成了 bug 的源头 —— 玩家报告
##     "有个东西飞快地往左上角过去"：
##     回池的那一帧，节点在"可见、位于命中点"的状态下直接被瞬移到屏幕外，
##     同一帧里位置和可见性一起变，就被画成了一条射向左上角的高速拖影。
##     实测逐帧追踪命中节点：一次跑动抓到 298 次 ~141500 px 的位置瞬移，
##     全部发生在"命中点 <-> 屏幕外停放点"之间，方向恒为左上。
##     删掉挪动之后，节点回池时位置**原地不动**、只是隐藏 ——
##     既然已经不可见，停在旧坐标不构成任何风险，同帧瞬移也就不存在了。
##
## 贴图、颜色、数量全部配在场景里（或由派生场景覆盖导出变量），脚本不 load 贴图。

@export var particleTexture: Texture2D
@export var hitColor: Color = Color(1.0, 0.9, 0.7, 1.0)
@export var hitAmount: int = 10
@export var hitScale: float = 0.7
@export var hitDuration: float = 0.5

## 池子用：true 表示正忙，不能借出去
var busy: bool = false

@onready var _particles: CPUParticles2D = $Particles

var _cd: float = 0.0


func _ready() -> void:
	z_index = 7
	_apply()
	_idle()


## 池子借出时调用：定位、重播粒子、开始计时
func playAt(pos: Vector2) -> void:
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
	_cd = hitDuration
	visible = true
	set_process(true)


func _idle() -> void:
	# ⚠️ 这里**只隐藏，不要移动节点**。
	#    以前这里还有一句 `global_position = OFFSCREEN`，结果回池那一帧节点在
	#    "可见 + 位于命中点"的状态下被瞬移到 (-100000,-100000)，
	#    位置和可见性同帧一起变 → 画出一条射向左上角的高速拖影。
	#    已经隐藏了，停在旧坐标是安全的（下次 playAt() 会先藏、再重新定位）。
	visible = false
	busy = false
	if _particles != null:
		_particles.emitting = false
	set_process(false)


## 把导出变量应用到粒子节点上（派生场景改了导出值，这里统一落下去）
func _apply() -> void:
	if _particles == null:
		return
	if particleTexture != null:
		_particles.texture = particleTexture
	_particles.amount = hitAmount
	_particles.color = hitColor
	# local_coords = true 表示粒子坐标相对本节点 —— 必须这样，
	# 否则 restart() 可能按旧的全局坐标发射，位置就错到上一次的命中点去了
	_particles.local_coords = true
	scale = Vector2.ONE * hitScale


func _process(delta: float) -> void:
	_cd -= delta
	if _cd <= 0.0:
		_idle()


## 回池：藏起来、停粒子（但**不销毁**，也不移动 —— 见 _idle() 的注释）
