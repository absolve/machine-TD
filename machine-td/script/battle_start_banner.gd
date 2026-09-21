extends Control
## 战斗开始横幅：关卡初次开打时闪一下「游戏开始 / 敌人即将到来」，然后自己消失。
##
## 独立场景，不依赖 map —— 谁想用就 `play()` 一下：
##     banner.play()                       # 用默认文案
##     banner.play("Game Start", "3 秒后开战")   # 或自己给文字
##
## 动画分三段：淡入 + 从 0.86 放大到 1 → 停住 → 淡出 + 上移。放完自动 hide 并发 finished。
##
## ⚠️ process_mode 设为 ALWAYS：这个横幅可能在 get_tree().paused 的边沿被调用，
##    不设的话 Tween 会跟着暂停，横幅就卡在屏幕上了。

signal finished ## 播放结束（已经自动 hide）

## 各段时长（秒）。改这里是最省事的方式 —— 全局生效，不用动任何场景。
## 想给某一关单独调，可以在 map.tscn 里选中 battleStartBanner 改同名属性
## （那是实例覆盖，记得 Ctrl+S 存 map.tscn，否则不生效）。
@export var fade_in_sec := 0.26
@export var hold_sec := 1.15
@export var fade_out_sec := 0.45
## 入场时的起始缩放（1.0 = 不缩放）
@export var from_scale := 0.86
## 出场时上移的像素
@export var out_offset_y := -34.0

@onready var band: Control = $center/band
@onready var title_label: Label = $center/band/content/VBox/titleLabel
@onready var sub_label: Label = $center/band/content/VBox/subLabel

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# 文字走翻译；调用 play() 时可以覆盖
	title_label.text = _t("_BattleStart", "Battle Start")
	sub_label.text = _t("_EnemiesIncoming", "Enemies incoming")


## 播一遍。title / sub 留空就用翻译里的默认文案。
## hold_override >= 0 时用它的停留时长，否则用导出属性 hold_sec。
func play(title: String = "", sub: String = "", hold_override: float = -1.0) -> void:
	if not title.is_empty():
		title_label.text = title
	if not sub.is_empty():
		sub_label.text = sub
	var hold := hold_sec if hold_override < 0.0 else hold_override
	print(hold)
	if _tween != null and _tween.is_valid():
		_tween.kill()

	visible = true
	modulate.a = 0.0
	band.scale = Vector2(from_scale, from_scale)
	band.position.y = 0.0
	# pivot 取中心，缩放才是"从中间长出来"而不是从左上角
	band.pivot_offset = band.size * 0.5

	_tween = create_tween()
	#_tween.set_parallel(true)
	# 第一段：淡入 + 放大
	_tween.tween_property(self, "modulate:a", 1.0, fade_in_sec)
	_tween.tween_property(band, "scale", Vector2.ONE, fade_in_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 第二段：停住
	_tween.chain().tween_interval(hold)
	# 第三段：淡出 + 上移
	#_tween.chain().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, fade_out_sec)
	_tween.tween_property(band, "position:y", out_offset_y, fade_out_sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(_on_done)


func _on_done() -> void:
	visible = false
	finished.emit()


## 想立刻收掉（比如玩家手快直接点了开始）
func skip() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if visible:
		_on_done()


func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
