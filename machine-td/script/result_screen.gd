extends Window

@onready var levelRating = $PanelContainer/VBoxContainer3/MarginContainer/vbox/levelRating
@onready var resultLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/resultLabel
@onready var waveLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/waveLabel
@onready var btnRestart:Button=$PanelContainer/VBoxContainer3/MarginContainer2/hbox/btnRestart
@onready var btnNextLevel:Button=$PanelContainer/VBoxContainer3/MarginContainer2/hbox/btnNextLevel
@onready var btnMenu:Button=$PanelContainer/VBoxContainer3/MarginContainer2/hbox/btnMenu

@export var isFailed = false  # 是否失败


func _ready():
	#levelRating.rating = 1
	# setResult(true)
	
	pass

# 设置结果
func setResult(_isFailed: bool):
	isFailed = _isFailed
	if isFailed:
		resultLabel.text = tr("_LevelFailed")
	else:
		resultLabel.text = tr("_LevelCompleted")


func _on_btn_restart_pressed():
	pass # Replace with function body.
