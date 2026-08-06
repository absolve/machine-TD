extends Window

@onready var levelRating = $PanelContainer/VBoxContainer3/MarginContainer/vbox/levelRating
@onready var resultLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/resultLabel
@onready var waveLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/waveLabel


@export var isFailed = false  # 是否失败


func _ready():
	levelRating.rating = 1
	# setResult(true)
	pass

# 设置结果
func setResult(_isFailed: bool):
	isFailed = _isFailed
	if isFailed:
		resultLabel.text = tr("_LevelFailed")
	else:
		resultLabel.text = tr("_LevelCompleted")
