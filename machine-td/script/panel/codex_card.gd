extends PanelContainer
## 图鉴里的一张单位卡片：上面是图片，下面是名字。
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
@onready var name_label: Label = $VBox/nameLabel

## 这张卡对应的条目字典（面板在 setup 时塞进来）
var entry: Dictionary = {}

var _sb_normal: StyleBox
var _sb_hover: StyleBox
var _sb_active: StyleBox
var _selected := false
var _pending_icon: Texture2D ## setup() 可能早于入树，这时 @onready 还没生效，先记下来


func _ready() -> void:
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	gui_input.connect(_on_input)
	# 入树后把之前塞进来的图补上
	if _pending_icon != null and icon != null:
		icon.texture = _pending_icon


## 由面板调用：绑定条目 + 三种状态的样式
func setup(e: Dictionary, sb_normal: StyleBox, sb_hover: StyleBox, sb_active: StyleBox) -> void:
	entry = e
	_sb_normal = sb_normal
	_sb_hover = sb_hover
	_sb_active = sb_active
	name_label.text = str(e.get("name", ""))
	tooltip_text = str(e.get("name", ""))
	set_icon(e.get("icon"))
	_apply(false)


## ★ 换图就这一行 —— 想替换卡面上的图片直接调它
func set_icon(texture: Texture2D) -> void:
	_pending_icon = texture
	if icon != null:
		icon.texture = texture


func set_selected(value: bool) -> void:
	_selected = value
	_apply(false)


func is_selected() -> bool:
	return _selected


func _on_enter() -> void:
	_apply(true)
	hovered.emit(entry)


func _on_exit() -> void:
	_apply(false)
	unhovered.emit()


func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		picked.emit(entry)
		accept_event()


func _apply(hover: bool) -> void:
	var sb := _sb_active if _selected else (_sb_hover if hover else _sb_normal)
	if sb != null:
		add_theme_stylebox_override("panel", sb)
