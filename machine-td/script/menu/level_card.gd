extends PanelContainer

## 关卡卡片。
##
## 三种状态各有一套配色（角铁 / 数字 / 底部行）：
##   · **未解锁** —— 暗灰角铁 + 压暗数字 + 「未解锁」小牌
##   · **可玩**   —— 亮银角铁 + 主文字数字 + 三颗空星
##   · **已通关** —— 安全黄角铁 + 主文字数字 + 点亮的金星
##
## 悬停：底色抬高一档 + 亮黄描边 + 角铁转黄高光（art_style.md §4「悬停：底升亮、边框转 #FFC61A」）。
##
## 布局要点（这三条是改版前的老毛病，别改回去）：
##   · 数字不与「未解锁」重叠 —— 两者分属上下两行；
##   · 两位数关卡号自动降一档字号，不会顶到角铁；
##   · 星级行有固定高度、星星按 30px 缩放，不会溢出卡片。

class_name LevelCard

signal clicked

# ── 配色（art_style.md §3.2 色阶 / §3.3 安全黄）──
const ACCENT_CLEARED := Palette.HAZARD_500  # 已通关 = 安全黄
const ACCENT_OPEN := Palette.UI_400     # 可玩 = 亮银
const ACCENT_LOCKED := Palette.UI_720   # 未解锁 = 暗灰
const ACCENT_HOVER := Palette.HAZARD_300     # 悬停 = 黄高光
const NUM_TEXT := Palette.UI_050        # 主文字
const NUM_TEXT_LOCKED := Palette.UI_300 # 压暗文字（禁用态）
const NUM_TEXT_NEXT := Palette.HAZARD_500   # 「下一关」= 安全黄
const NUM_TEXT_HOVER := Palette.UI_000  # 最亮
const PLATE_EDGE := Palette.UI_720      # 底板描边
const PLATE_BG := Palette.UI_600        # 卡片底（ui_600）
const PLATE_BG_HOVER := Palette.UI_500  # 悬停时底色抬高一档（ui_500）

# 数字字号：一位数 / 两位数 / 具名关卡
const NUM_FONT_ONE := 80
const NUM_FONT_TWO := 58
const NUM_FONT_NAME := 34

## 同一个卡片在这个间隔内只认一次点击（与 ui_button.gd 同一套防抖）
const CLICK_GUARD_MSEC := 120

@export var level: String = "1" # 关卡号（"1" / "15"；具名关卡就是名字本身）
@export var rating: int = 0 # 评分（0~3 星）
@export var description: String = "" # 关卡描述
@export var isLock: bool = true
@export var levelId: int = 1 # 关卡id
@export var isNext: bool = false # 「下一关」（已解锁但还没拿到星的那张）

@onready var num: Label = $Margin/VBox/numArea/num
@onready var levelRating: LevelRating = $Margin/VBox/bottom/levelRating
@onready var lockChip: PanelContainer = $Margin/VBox/bottom/lockChip
@onready var lockText: Label = $Margin/VBox/bottom/lockChip/row/lockText
@onready var frame: LevelCardFrame = $Frame

## 底板样式每张卡各存一份 —— 直接改 theme 里的资源会一次改掉所有卡片
var plate: StyleBoxFlat = null
var lastClickMsec: int = -100000


func _ready() -> void:
	plate = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", plate)
	num.text = str(level)
	applyNumberFont()
	lockText.text = tr("_LevelLocked")
	levelRating.rating = rating
	refreshState()


## 关卡号用数字就按位数选字号，具名关卡（"Tutorial"）单独一档。
func applyNumberFont() -> void:
	var text := str(level)
	if not text.is_valid_int():
		num.add_theme_font_size_override("font_size", NUM_FONT_NAME)
		return
	var size: int = NUM_FONT_ONE if text.length() <= 1 else NUM_FONT_TWO
	num.add_theme_font_size_override("font_size", size)


## 按当前状态刷新外观。悬停退出时也调它，用来把悬停态退回去。
func refreshState() -> void:
	plate.bg_color = Color(PLATE_BG.r, PLATE_BG.g, PLATE_BG.b, 0.97)
	plate.set_border_width_all(2)
	plate.shadow_size = 14
	if isLock:
		frame.accent = ACCENT_LOCKED
		num.add_theme_color_override("font_color", NUM_TEXT_LOCKED)
		levelRating.visible = false
		lockChip.visible = true
		plate.border_color = Color(PLATE_EDGE.r, PLATE_EDGE.g, PLATE_EDGE.b, 0.35)
	else:
		levelRating.visible = true
		lockChip.visible = false
		num.add_theme_color_override("font_color", NUM_TEXT_NEXT if isNext else NUM_TEXT)
		frame.accent = ACCENT_CLEARED if rating > 0 else ACCENT_OPEN
		plate.border_color = Color(PLATE_EDGE.r, PLATE_EDGE.g, PLATE_EDGE.b, 0.47)


func onMouseEntered() -> void:
	if isLock:
		return
	# 「点亮」：底色抬高一档 + 亮黄描边 + 角铁转黄高光（art_style §4 按钮悬停规范）。
	# 底色这一手是关键 —— 已通关的卡片角铁本来就是黄的，光靠角铁换色区分不出来。
	frame.accent = ACCENT_HOVER
	num.add_theme_color_override("font_color", NUM_TEXT_HOVER)
	plate.bg_color = Color(PLATE_BG_HOVER.r, PLATE_BG_HOVER.g, PLATE_BG_HOVER.b, 0.97)
	plate.set_border_width_all(3)
	plate.border_color = Color(ACCENT_CLEARED.r, ACCENT_CLEARED.g, ACCENT_CLEARED.b, 0.85)
	plate.shadow_size = 20
	# 轻轻抬起一点（纯视觉，容器布局仍按原尺寸算）
	pivot_offset = size * 0.5
	scale = Vector2(1.03, 1.03)
	SoundManage.playHover()


func onMouseExited() -> void:
	if isLock:
		return
	scale = Vector2.ONE
	refreshState()


func onGuiInput(event: InputEvent) -> void:
	if isLock:
		return
	if not (event is InputEventMouseButton and event.is_action_pressed("click")):
		return
	var now: int = Time.get_ticks_msec()
	if now - lastClickMsec < CLICK_GUARD_MSEC:
		return
	lastClickMsec = now
	SoundManage.playEffect()
	clicked.emit(levelId)
