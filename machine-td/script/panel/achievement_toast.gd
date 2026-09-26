extends PanelContainer
## 成就获得提示：从屏幕右侧滑入，停留片刻后缓缓滑回右侧消失。
##
## 挂在 map 场景的 hud 层，监听 AchievementManager.achievement_unlocked。
## 同一帧解锁多个成就（例如通关同时达成「初次防守」+「零损防线」）时排队逐个播放。
##
## 位置：默认停在屏幕右下角的空白区（详情面板下方、波次进度条上方），
##       不遮挡右侧的塔/敌人信息面板，可用 margin_right / margin_bottom 微调。

const SLIDE_IN_TIME := 0.45 # 滑入时长
const HOLD_TIME := 2.6 # 停留时长
const SLIDE_OUT_TIME := 0.8 # 滑出时长（"缓缓"消失）

@export var margin_right: float = 24.0 # 停靠时距屏幕右边缘
@export var margin_bottom: float = 80.0 # 停靠时距屏幕下边缘

@onready var icon: TextureRect = $HBox/iconCenter/icon
@onready var header_label: Label = $HBox/vbox/headerLabel
@onready var name_label: Label = $HBox/vbox/nameLabel
@onready var desc_label: Label = $HBox/vbox/descLabel

var _queue: Array = [] # 待播放的成就队列
var _busy := false # 是否正在播放
var _shown_x := 0.0 # 停靠位置
var _hidden_x := 0.0 # 屏幕外位置


func _ready() -> void:
	visible = false
	header_label.text = _t("_AchievementToast", "Achievement Unlocked")
	_layout()
	get_viewport().size_changed.connect(_layout)
	if AchievementManager:
		AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)


# ---------- 队列 ----------

func _on_achievement_unlocked(achievement_id: String, achievement: Dictionary) -> void:
	_queue.append({"id": achievement_id, "achievement": achievement})
	if not _busy:
		_process_queue()


func _process_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		await _play(item)
	_busy = false


# ---------- 播放 ----------

func _play(item: Dictionary) -> void:
	var achievement: Dictionary = item.get("achievement", {})
	icon.texture = _load_icon(achievement)
	name_label.text = _t(str(achievement.get("name", "")), str(item.get("id", "")))
	desc_label.text = _t(str(achievement.get("description", "")), "")

	_layout()
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "position:x", _shown_x, SLIDE_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(self, "position:x", _hidden_x, SLIDE_OUT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	visible = false


# ---------- 位置 ----------

# 右下角停靠：滑入起点在屏幕右边缘之外，终点贴在 margin_right 处
func _layout() -> void:
	var vp := get_viewport_rect().size
	var toast_size := Vector2(maxf(size.x, custom_minimum_size.x), maxf(size.y, custom_minimum_size.y))
	_hidden_x = vp.x
	_shown_x = vp.x - toast_size.x - margin_right
	var y := vp.y - margin_bottom - toast_size.y
	# 正在播放时不要打断动画，只更新终点位置
	position = Vector2(_hidden_x if not visible else position.x, y)


# ---------- 工具 ----------

func _load_icon(achievement: Dictionary) -> Texture2D:
	var path := str(achievement.get("icon", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var tex := load(path)
		if tex is Texture2D:
			return tex
	return load("res://sprite/achievement.png") as Texture2D


# 取翻译；未找到对应 key（语言文件未导入）时回退到默认文本
func _t(key: String, fallback: String) -> String:
	if key.is_empty():
		return fallback
	var translated := tr(key)
	return fallback if translated == key else translated
