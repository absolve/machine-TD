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

@export var marginRight: float = 24.0 # 停靠时距屏幕右边缘
@export var marginBottom: float = 80.0 # 停靠时距屏幕下边缘

@onready var icon: TextureRect = $HBox/iconCenter/icon
@onready var headerLabel: Label = $HBox/vbox/headerLabel
@onready var nameLabel: Label = $HBox/vbox/nameLabel
@onready var descLabel: Label = $HBox/vbox/descLabel

var queue: Array = [] # 待播放的成就队列
var busy: bool = false # 是否正在播放
var shownX: float = 0.0 # 停靠位置
var hiddenX: float = 0.0 # 屏幕外位置


func _ready() -> void:
	visible = false
	headerLabel.text = Game.t("_AchievementToast", "Achievement Unlocked")
	layout()
	get_viewport().size_changed.connect(layout)
	if AchievementManager:
		AchievementManager.achievementUnlocked.connect(onAchievementUnlocked)


# ---------- 队列 ----------

func onAchievementUnlocked(achievement_id: String, achievement: Dictionary) -> void:
	queue.append({"id": achievement_id, "achievement": achievement})
	if not busy:
		processQueue()


func processQueue() -> void:
	busy = true
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		await play(item)
	busy = false


# ---------- 播放 ----------

func play(item: Dictionary) -> void:
	var achievement: Dictionary = item.get("achievement", {})
	icon.texture = loadIcon(achievement)
	nameLabel.text = Game.t(str(achievement.get("name", "")), str(item.get("id", "")))
	descLabel.text = Game.t(str(achievement.get("description", "")), "")

	layout()
	visible = true
	var tw: Tween = create_tween()
	tw.tween_property(self, "position:x", shownX, SLIDE_IN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD_TIME)
	tw.tween_property(self, "position:x", hiddenX, SLIDE_OUT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	visible = false


# ---------- 位置 ----------

# 右下角停靠：滑入起点在屏幕右边缘之外，终点贴在 margin_right 处
func layout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var toastSize: Vector2 = Vector2(maxf(size.x, custom_minimum_size.x), maxf(size.y, custom_minimum_size.y))
	hiddenX = vp.x
	shownX = vp.x - toastSize.x - marginRight
	var y: float = vp.y - marginBottom - toastSize.y
	# 正在播放时不要打断动画，只更新终点位置
	position = Vector2(hiddenX if not visible else position.x, y)


# ---------- 工具 ----------

func loadIcon(achievement: Dictionary) -> Texture2D:
	var path: String = str(achievement.get("icon", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var tex: Resource = load(path)
		if tex is Texture2D:
			return tex
	return load("res://sprite/achievement.png") as Texture2D
