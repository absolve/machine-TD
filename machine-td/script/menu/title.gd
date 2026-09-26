extends Control


@onready var waveLabel = $PanelContainer/hbox/hbox1/waveLabel
@onready var hpLabel = $PanelContainer/hbox/hbox2/hpLabel
@onready var moneyLabel = $PanelContainer/hbox/hbox3/moneyLabel
@onready var scoreLabel = $PanelContainer/hbox/hbox4/scoreLabel
@onready var scoreTitle = $PanelContainer/hbox/hbox4/Label
@onready var speedLabel = $PanelContainer/hbox/HBoxContainer3/btnFast/Label
@onready var btnSpeed = $PanelContainer/hbox/HBoxContainer3/btnFast
@onready var btnStart = $PanelContainer/hbox/HBoxContainer3/btnStart/MarginContainer/btnStart
@onready var btnSound = $PanelContainer/hbox/HBoxContainer3/btnSfx/MarginContainer/btnStart
@onready var btnMusic = $PanelContainer/hbox/HBoxContainer3/btnMusic
@onready var btnHome = $PanelContainer/hbox/HBoxContainer3/btnHome/MarginContainer/btnStart


signal start
signal pause
signal soundOn
signal soundOff
signal musicOn
signal musicOff
signal speedOn
signal speedOff
signal home

## 点击音由按钮自己播（见 menuBtn.tscn 的 menu_btn.gd / ui_button.tscn 的 ui_button.gd）。
## ⚠️ 这里**不要**再调 SoundManage.playXxx()，否则一次点击会响两声。


var hp = 0:
	set(value):
		hp = max(value, 0)
		hpLabel.text = str(value)

var currentWave: int = 0:
	set(value):
		currentWave = value
		waveLabel.text = str(currentWave) + "/" + str(wave)
		
		
var wave = 1:
	set(value):
		wave = value
		waveLabel.text = str(currentWave) + "/" + str(wave)
		
var money = 0:
	set(value):
		money = value
		moneyLabel.text = str(value)
		
var score = 0:
	set(value):
		score = value
		scoreLabel.text = str(value)


## ▶/⏸ 是 toggle_mode 按钮，两种状态的语义：
##   button_pressed = true  → 显示 ⏸（暂停图）→ 意思是「正在运行，点我暂停」
##   button_pressed = false → 显示 ▶（播放图）→ 意思是「已暂停，点我继续」
## 所以状态同步是 set_playing(正在运行)。
##
## ⚠️ 必须用 set_pressed_no_signal —— 直接写 button_pressed 会触发 toggled，
##    反过来又发一次 start / pause，声音和状态都会错乱。
## 开始按钮的呼吸提示循环（见 prompt_start）
var _prompt_tween: Tween


func set_playing(playing: bool) -> void:
	if btnStart and btnStart.button_pressed != playing:
		btnStart.set_pressed_no_signal(playing)


## 开始按钮的呼吸提示：还在等玩家开打时，让 ▶ 一闪一闪。
## 关卡情报弹窗一关就调它；玩家点了开始再 stop_prompt()。
func prompt_start() -> void:
	stop_prompt()
	if btnStart == null:
		return
	btnStart.pivot_offset = btnStart.size * 0.5
	# ⚠️ 用 parallel() 只让「紧跟的那一条」并行。
	#    别用 set_parallel(true) —— 那会让后面**所有** tweener 都并行，
	#    "变亮"和"变暗"、"放大"和"缩小"同时跑，互相抵消，scale 会永远停在 1.0（这里踩过）。
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(btnStart, "modulate", Color(1.9, 1.8, 1.25), 0.45).set_trans(Tween.TRANS_SINE)
	_prompt_tween.parallel().tween_property(btnStart, "scale", Vector2(1.14, 1.14), 0.45).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(btnStart, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	_prompt_tween.parallel().tween_property(btnStart, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func stop_prompt() -> void:
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	_prompt_tween = null
	if btnStart != null:
		btnStart.modulate = Color.WHITE
		btnStart.scale = Vector2.ONE


func _on_texture_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		# 刚按下 → 现在显示 ⏸ → 意思是开始 / 继续
		start.emit()
	else:
		# 刚弹起 → 现在显示 ▶ → 意思是暂停
		pause.emit()


func _on_btn_speed_toggled(toggled_on: bool) -> void:
	if toggled_on:
		speedOn.emit()
		speedLabel.text = str("2X")
	else:
		speedOff.emit()
		speedLabel.text = str("1X")


func _on_btn_sound_toggled(toggled_on: bool) -> void:
	if toggled_on:
		soundOff.emit()
	else:
		soundOn.emit()

func _on_btn_music_toggled(toggled_on: bool) -> void:
	if toggled_on:
		musicOff.emit()
	else:
		musicOn.emit()


func _on_btn_home_pressed() -> void:
	home.emit()


func _ready() -> void:
	# 顶栏「得分:」之前是场景里硬编码的英文，这里走翻译
	scoreTitle.text = tr("_Score")
