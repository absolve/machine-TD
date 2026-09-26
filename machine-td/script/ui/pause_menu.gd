extends Control
## 暂停菜单。已从 Window 改为普通 Control，否则嵌入式子窗口会盖在场景切换遮罩之上。

signal resumePressed
signal restartPressed
signal menuPressed

@onready var resumeButton = $PanelContainer/VBoxContainer/buttons/btnResume
@onready var restartButton = $PanelContainer/VBoxContainer/buttons/btnRestart
@onready var menuButton = $PanelContainer/VBoxContainer/buttons/btnMenu


func _ready():
	$PanelContainer/VBoxContainer/title.text = tr("_Pause")
	resumeButton.pressed.connect(func(): resumePressed.emit())
	restartButton.pressed.connect(func(): restartPressed.emit())
	menuButton.pressed.connect(func(): menuPressed.emit())
	
