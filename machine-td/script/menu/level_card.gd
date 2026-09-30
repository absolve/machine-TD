extends PanelContainer

signal clicked

@export var level: int = 1 # 关卡名字
@export var rating: int = 0 # 评分
@export var description: String = "" # 关卡描述
@export var isLock: bool = true
@export var levelId: int = 1 # 关卡id

@onready var num: Label = $VBoxContainer/num
@onready var levelRating: LevelRating = $VBoxContainer/MarginContainer/levelRating
@onready var selected: TextureRect = $Selected
@onready var lockLabel: Label = $LockLabel


func _ready() -> void:
	num.text = str(level)
	# 锁标文本原本是场景里硬编码的英文 "LOCKED"，这里走翻译
	lockLabel.text = tr("_LevelLocked")
	levelRating.rating = rating
	levelRating.visible = true
	levelRating.modulate.a = 1.0 if rating > 0 else 0.0
	if isLock:
		modulate = Color(0.45, 0.45, 0.45, 0.75)
		lockLabel.visible = true
	else:
		lockLabel.visible = false


func onMouseEntered() -> void:
	selected.visible = not isLock
	# 悬停时把卡片自己的边框提亮。
	# 用 self_modulate（只影响本节点自己的绘制）而不是 modulate ——
	# modulate 在和"未解锁灰化"抢同一个属性，会打架。
	if not isLock:
		self_modulate = Color(1.35, 1.35, 1.35)


func onMouseExited() -> void:
	selected.visible = false
	self_modulate = Color.WHITE


func onGuiInput(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_action_pressed("click"):
		if not isLock:
			clicked.emit(levelId)
