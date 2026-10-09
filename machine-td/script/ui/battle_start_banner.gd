extends Control
## 战斗开始横幅：关卡初次开打时闪一下「游戏开始 / 敌人即将到来」，然后自己消失。
##
## 独立场景，不依赖 map —— 谁想用就 `play()` 一下：
##     banner.play() # 用默认文案
##     banner.play("Game Start", "3 秒后开战") # 或自己给文字
##
## 动画分三段：淡入 + 从 0.86 放大到 1 → 停住 → 淡出 + 上移。放完自动 hide 并发 finished。
##
## ⚠️ process_mode 设为 ALWAYS：这个横幅可能在 get_tree().paused 的边沿被调用，
##    不设的话 Tween 会跟着暂停，横幅就卡在屏幕上了。

signal finished ## 播放结束（已经自动 hide）

## 各段时长（秒）。改这里是最省事的方式 —— 全局生效，不用动任何场景。
## 想给某一关单独调，可以在 map.tscn 里选中 battleStartBanner 改同名属性
## （那是实例覆盖，记得 Ctrl+S 存 map.tscn，否则不生效）。
@export var fadeInSec: float = 0.26
@export var holdSec: float = 1.15
@export var fadeOutSec: float = 0.45
## 入场时的起始缩放（1.0 = 不缩放）
@export var fromScale: float = 0.86
## 出场时上移的像素
@export var outOffsetY: float = -34.0

@onready var band: Control = $center/band
@onready var titleLabel: Label = $center/band/content/VBox/titleLabel
@onready var subLabel: Label = $center/band/content/VBox/subLabel

var tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# 文字走翻译；调用 play() 时可以覆盖
	titleLabel.text = Game.t("_BattleStart", "Battle Start")
	subLabel.text = Game.t("_EnemiesIncoming", "Enemies incoming")


## 播一遍。title / sub 留空就用翻译里的默认文案。
## hold_override >= 0 时用它的停留时长，否则用导出属性 hold_sec。
func play(title: String = "", sub: String = "", hold_override: float = -1.0) -> void:
	if not title.is_empty():
		titleLabel.text = title
	if not sub.is_empty():
		subLabel.text = sub
	var hold: float = holdSec if hold_override < 0.0 else hold_override
	print(hold)
	if tween != null and tween.is_valid():
		tween.kill()

	visible = true
	modulate.a = 0.0
	band.scale = Vector2(fromScale, fromScale)
	band.position.y = 0.0
	# pivot 取中心，缩放才是"从中间长出来"而不是从左上角
	band.pivot_offset = band.size * 0.5

	tween = create_tween()
	#tween.set_parallel(true)
	# 第一段：淡入 + 放大
	tween.tween_property(self, "modulate:a", 1.0, fadeInSec)
	tween.tween_property(band, "scale", Vector2.ONE, fadeInSec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 第二段：停住
	tween.chain().tween_interval(hold)
	# 第三段：淡出 + 上移
	#tween.chain().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, fadeOutSec)
	tween.tween_property(band, "position:y", outOffsetY, fadeOutSec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(onDone)
	await  tween.finished

func onDone() -> void:
	visible = false
	finished.emit()


## 想立刻收掉（比如玩家手快直接点了开始）
func skip() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	if visible:
		onDone()
