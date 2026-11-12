extends Control
## 波间间歇倒计时 + 提前召唤按钮（feature_design.md §二十二 H）。
##
## 只负责显示与发一个 `callRequested` 信号；是否可召唤、奖励多少都由
## base_level.gd 的 getEarlyCallInfo() 决定，本脚本不持有任何战斗状态。

signal callRequested

## 普通波：安全黄（与顶栏金币同色系）
const NORMAL_ACCENT: Color = Palette.HAZARD_500
## Boss 波：警示红 —— "可以提前拉，但不给钱"
const BOSS_ACCENT: Color = Palette.ALERT_HOT

@onready var nextLabel: Label = $Panel/HBox/infoBox/nextLabel
@onready var rewardLabel: Label = $Panel/HBox/infoBox/rewardLabel
@onready var btnCall: Button = $Panel/HBox/btnCall


func _ready() -> void:
	visible = false
	btnCall.pressed.connect(onBtnCallPressed)


## 由 map 每帧调用（仅间歇期）。remaining 是游戏内秒数，向上取整显示。
func showState(remaining: float, reward: int, is_boss: bool) -> void:
	visible = true
	var seconds: int = maxi(0, int(ceil(remaining)))
	nextLabel.text = Game.t("_NextWaveCountdownFmt", "下一波 %ds") % seconds
	if is_boss:
		rewardLabel.text = Game.t("_EarlyCallBoss", "Boss 波：无金币奖励")
		rewardLabel.add_theme_color_override("font_color", BOSS_ACCENT)
		btnCall.text = Game.t("_EarlyCallBtnBoss", "召唤 Boss")
		btnCall.add_theme_color_override("font_color", BOSS_ACCENT)
	else:
		rewardLabel.text = Game.t("_EarlyCallRewardFmt", "提前 +%d 金币") % reward
		rewardLabel.add_theme_color_override("font_color", NORMAL_ACCENT)
		btnCall.text = Game.t("_EarlyCallBtn", "提前召唤")
		btnCall.add_theme_color_override("font_color", NORMAL_ACCENT)


func hidePanel() -> void:
	if visible:
		visible = false


func onBtnCallPressed() -> void:
	callRequested.emit()
