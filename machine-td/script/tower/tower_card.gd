extends PanelContainer


@onready var img = $VBoxContainer/MarginContainer2/img
@onready var costLabel = $VBoxContainer/MarginContainer/HBoxContainer/costLabel
@onready var selected = $selected

@export var type: Game.towerType = Game.towerType.machineGunTower

## 本关是否禁用了这座塔。由 tower_ui 按 StageData.getTowers() 设置。
var locked := false

signal click
signal lockedClick   # 点了被禁用的塔（用来弹一句提示，而不是静默失败）
signal showInfo


func setImg(obj):
	img.texture = obj


func setCost(cost):
	costLabel.text = str(cost)


# 本关不可建造：整张卡片变灰、点不下去、也不显示选中框
func setLocked(value: bool) -> void:
	locked = value
	modulate = Color(1, 1, 1, 0.3) if value else Color(1, 1, 1, 1)
	if value:
		selected.visible = false


func _gui_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("click"):
		if locked:
			lockedClick.emit(type)
			return
		click.emit(type)


func _on_mouse_entered() -> void:
	if locked:
		return
	selected.visible = true
	showInfo.emit(type)


func _on_mouse_exited() -> void:
	selected.visible = false
