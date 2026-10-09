extends PanelContainer
## 图鉴里的一张单位卡片：**只有一张单位图，不显示名字**，
## 名字靠悬停提示和下方详情栏看（卡片本身只认条目字典里的 icon）。
##
## 图片是**可替换的** —— 外部只要调 set_icon() 换一张 Texture2D 就行，
## 卡片本身完全不认识「敌人 / 防御塔」的区别。
## 以后想换成动图，把场景里的 icon 节点换成 AnimatedSprite2D 即可，其余代码不用动。
##
## 三种外观：普通 / 鼠标悬停 / 已选中，样式由面板统一传进来（共享 StyleBox，不每个卡片一份）。

signal picked(entry: Dictionary)   ## 点了左键 —— 面板据此「锁定」选中项
signal hovered(entry: Dictionary)  ## 鼠标移入 —— 面板据此临时预览
signal unhovered                   ## 鼠标移出

@onready var icon: TextureRect = $VBox/Center/icon

## 这张卡对应的条目字典（面板在 setup 时塞进来）
var entry: Dictionary = {}

var sbNormal: StyleBox
var sbHover: StyleBox
var sbActive: StyleBox
var _selected: bool = false
var pendingIcon: Texture2D ## setup() 可能早于入树，这时 @onready 还没生效，先记下来


func _ready() -> void:
	mouse_entered.connect(onEnter)
	mouse_exited.connect(onExit)
	gui_input.connect(onInput)
	# 入树后把之前塞进来的图补上
	if pendingIcon != null and icon != null:
		icon.texture = pendingIcon


## 由面板调用：绑定条目 + 三种状态的样式
func setup(e: Dictionary, sb_normal: StyleBox, sb_hover: StyleBox, sb_active: StyleBox) -> void:
	entry = e
	sbNormal = sb_normal
	sbHover = sb_hover
	sbActive = sb_active
	tooltip_text = str(e.get("name", ""))
	setIcon(e.get("icon"))
	apply(false)


## ★ 换图就这一行 —— 想替换卡面上的图片直接调它
func setIcon(texture: Texture2D) -> void:
	pendingIcon = texture
	if icon != null:
		icon.texture = texture


func setSelected(value: bool) -> void:
	_selected = value
	apply(false)


func isSelected() -> bool:
	return _selected


func onEnter() -> void:
	apply(true)
	hovered.emit(entry)


func onExit() -> void:
	apply(false)
	unhovered.emit()


func onInput(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(entry)
		accept_event()


func apply(hover: bool) -> void:
	var sb: StyleBox = sbActive if _selected else (sbHover if hover else sbNormal)
	if sb != null:
		add_theme_stylebox_override("panel", sb)
