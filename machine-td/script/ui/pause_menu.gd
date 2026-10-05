extends Control
## 暂停菜单。已从 Window 改为普通 Control，否则嵌入式子窗口会盖在场景切换遮罩之上。

signal resumePressed
signal restartPressed
signal menuPressed
## 无尽模式专用：主动结束本局（认输）。普通关卡里这个按钮是隐藏的。
signal giveUpPressed

@onready var resumeButton = $PanelContainer/VBoxContainer/buttons/btnResume
@onready var restartButton = $PanelContainer/VBoxContainer/buttons/btnRestart
@onready var menuButton = $PanelContainer/VBoxContainer/buttons/btnMenu
@onready var giveUpButton = $PanelContainer/VBoxContainer/buttons/btnGiveUp


func _ready():
	$PanelContainer/VBoxContainer/title.text = tr("_Pause")
	resumeButton.pressed.connect(func(): resumePressed.emit())
	restartButton.pressed.connect(func(): restartPressed.emit())
	menuButton.pressed.connect(func(): menuPressed.emit())
	giveUpButton.pressed.connect(func(): giveUpPressed.emit())
	giveUpButton.visible = false


## 「结束本局」只在无尽模式出现（map 每次暂停时同步一次）
func showGiveUp(visibleFlag: bool) -> void:
	giveUpButton.visible = visibleFlag
	
