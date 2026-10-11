extends Node2D
## 单个击杀金币飘字：`+N` 向上飘一段后淡出，然后回池。
##
## 生命周期由 playAt() 驱动，动画用 Tween；播完发 `finished` 让池子收回去。
## 池化节点**销毁在池子那边**，这里只负责"播"和"通知播完了"。

## 播完（已经淡出）——池子收到后把 busy 置 false
signal finished

## true = 正忙，池子不能借出去
var busy: bool = false

## 压在敌人与特效之上，保证数字不被挡住。
## （敌人 z_index=2、命中特效 z_index=7；取 40 留足余量。）
const Z_ABOVE_FX: int = 40

## 上飘距离（像素）。给得比字号大一点，飘完刚好离开原位一段看得清的距离。
const RISE_PX: float = 44.0
const POP_SEC: float = 0.10
const RISE_SEC: float = 0.55
const FADE_SEC: float = 0.25

@onready var label: Label = $Label

var _tween: Tween


## 在 pos 播一次 "+amount"。
##
## ⚠️ 顺序：先藏起来再摆位置，最后才显形。
##    池子借出来的节点还带着上一次的坐标，若先显形再定位，那一帧会闪在旧位置。
##    （命中特效那边踩过同款问题，见 explosion_manage.gd 的 acquireHit 注释。）
func playAt(pos: Vector2, amount: int) -> void:
	z_index = Z_ABOVE_FX
	visible = false
	global_position = pos
	# 同一帧多只敌人死亡时错开一点，否则数字叠成一坨看不清
	position += Vector2(randf_range(-14.0, 14.0), randf_range(-6.0, 6.0))
	if label != null:
		label.text = "+%d" % amount
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(0.6, 0.6)
	visible = true
	busy = true

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	# 弹出：带一点回弹，读作"跳出来"
	_tween.tween_property(self, "scale", Vector2.ONE, POP_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 上飘与淡出并行：先快后慢地升，同时淡掉
	_tween.parallel().tween_property(self, "position:y", position.y - RISE_PX, RISE_SEC + FADE_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, FADE_SEC).set_delay(RISE_SEC)
	_tween.finished.connect(onTweenFinished)


func onTweenFinished() -> void:
	visible = false
	busy = false
	finished.emit()
