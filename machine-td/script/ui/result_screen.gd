extends Control
## 通关 / 失败结算面板。已从 Window 改为普通 Control，否则嵌入式子窗口会盖在场景切换遮罩之上。

@onready var levelRating = $PanelContainer/VBoxContainer3/MarginContainer/vbox/levelRating
@onready var resultLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/resultLabel
@onready var waveLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/waveLabel
@onready var gemRewardRow = $PanelContainer/VBoxContainer3/MarginContainer/vbox/gemRewardRow
@onready var gemRewardLabel = $PanelContainer/VBoxContainer3/MarginContainer/vbox/gemRewardRow/gemRewardLabel
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
		gemRewardRow.visible = false
		# 失败时没有下一关可去
		btnNextLevel.visible = false
	else:
		resultLabel.text = tr("_LevelCompleted")
		btnNextLevel.visible = true

## 设置宝石奖励并显示。
##
## ⚠️ 旧实现是 `gemRewardRow.visible = amount > 0`，而宝石**只在首次通关发放**
##    （见 userData.recordStageCompletion），所以重复打同一关时 amount 恒为 0，
##    整行直接被隐藏 —— 看起来就是"结束菜单上没有奖励宝石"。
## 现在：通关时**始终显示这一行**，amount 为 0 就明确写"本关宝石已领取过"，
## 让玩家知道不是漏发了，而是这一关的宝石已经拿过。
func setGemReward(amount: int) -> void:
	if amount > 0:
		gemRewardLabel.text = tr("_GemReward") % amount
		gemRewardRow.modulate = Color(1, 1, 1, 1)
	else:
		gemRewardLabel.text = tr("_GemRewardNone")
		# 压暗一档，和"真拿到宝石"在视觉上区分开
		gemRewardRow.modulate = Color(1, 1, 1, 0.55)
	gemRewardRow.visible = true


func _onBtnRestartPressed():
	pass # Replace with function body.
