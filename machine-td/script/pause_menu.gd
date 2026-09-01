extends Window

signal resumePressed
signal restartPressed
signal menuPressed

@onready var resumeButton = $PanelContainer/VBoxContainer/buttons/btnResume
@onready var restartButton = $PanelContainer/VBoxContainer/buttons/btnRestart
@onready var menuButton = $PanelContainer/VBoxContainer/buttons/btnMenu


func _ready():
	resumeButton.pressed.connect(func(): resumePressed.emit())
	restartButton.pressed.connect(func(): restartPressed.emit())
	menuButton.pressed.connect(func(): menuPressed.emit())
	
