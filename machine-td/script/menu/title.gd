extends Control


@onready var waveLabel = $PanelContainer/hbox/hbox1/waveLabel
@onready var hpLabel = $PanelContainer/hbox/hbox2/hpLabel
@onready var moneyLabel = $PanelContainer/hbox/hbox3/moneyLabel
@onready var gemLabel = $PanelContainer/hbox/hboxGem/gemLabel
@onready var gemIcon = $PanelContainer/hbox/hboxGem/gemIcon
@onready var scoreLabel = $PanelContainer/hbox/spacerRight/hbox4/scoreLabel
@onready var scoreTitle = $PanelContainer/hbox/spacerRight/hbox4/Label
## 顶栏最左侧的关卡名（数字关卡显示"第 N 关"，教程关显示"教程"）。
## ⚠️ hbox4（score）已从 hbox 直接子节点挪进 spacerRight，路径要跟着改。
@onready var levelLabel = $hboxLevel/levelLabel
## 关卡名右边那个"模式徽章"（只有挑战模式才出现）。**由代码创建**，
## 不改 title.tscn —— 它只是一块带底色的文字，没有需要在 Inspector 里调的东西。
var modeChip: PanelContainer = null
var modeLabel: Label = null
## 悬停提示（自定义，不用 Control.tooltip_text —— 原生 tooltip 有 0.5 秒延迟且无层次）
var modeTip: PanelContainer = null
var modeTipTitle: Label = null
var modeTipBody: Label = null
@onready var btnSpeed = $hboxButton/btnFast
@onready var btnStart = $hboxButton/btnStart/MarginContainer/btnStart
@onready var btnSound = $hboxButton/btnSfx/MarginContainer/btnStart
@onready var btnMusic = $hboxButton/btnMusic
@onready var btnHome = $hboxButton/btnHome/MarginContainer/btnStart


signal started
signal paused
signal soundOnPressed
signal soundOffPressed
signal musicOnPressed
signal musicOffPressed
signal speedOnPressed
signal speedOffPressed
signal homePressed

## 点击音由按钮自己播（见 menuBtn.tscn 的 menu_btn.gd / ui_button.tscn 的 ui_button.gd）。
## ⚠️ 这里**不要**再调 SoundManage.playXxx()，否则一次点击会响两声。


var hp = 0:
	set(value):
		hp = max(value, 0)
		hpLabel.text = str(value)

var currentWave: int = 0:
	set(value):
		currentWave = value
		refreshWaveLabel()
		
		
var wave = 1:
	set(value):
		wave = value
		refreshWaveLabel()
		
## 波次文本：普通关卡 "3/8"；无尽模式没有总波数，总波数显示成 "-"。
func refreshWaveLabel() -> void:
	if Game.endlessMode:
		waveLabel.text = str(currentWave) + "/-"
	else:
		waveLabel.text = str(currentWave) + "/" + str(wave)


var money = 0:
	set(value):
		money = value
		moneyLabel.text = str(value)

## 宝石数量。技能要花宝石，所以顶栏必须常驻显示，玩家才知道还能放几次。
## 技能消耗时由 AbilityManager 发 gem_changed → map 转给这里刷新。
var gem = 0:
	set(value):
		gem = maxi(value, 0)
		if gemLabel != null:
			gemLabel.text = str(gem)
		# 一颗都没有时压暗，和"还有得用"在视觉上区分开
		if gemIcon != null:
			gemIcon.modulate = Color(1, 1, 1, 1) if gem > 0 else Color(1, 1, 1, 0.45)
			gemLabel.modulate = gemIcon.modulate

var score = 0:
	set(value):
		score = value
		scoreLabel.text = str(value)


## 顶栏最左侧的关卡名。文案规则见 StageData.getLevelDisplayName()
## （数字关卡 → "第 N 关"；具名关卡如 Tutorial → 同名翻译键），
## 与关卡情报弹窗共用一份实现，避免两处各写一套判断。
##
## ⚠️ setter 里**不直接写 label**，只存值 + 调 refreshLevelLabel()。
##    原因：map.gd 是在**它自己的 `_ready()` 里**给这个属性赋值的，那时 HUD 下的
##    本节点还没进入场景树，`@onready var levelLabel` 仍是 null ——
##    直接在 setter 里写 label 会静默丢掉（踩过：赋值成功但顶栏一片空白）。
##    存值 + 在 `_ready()` 里套用，两条路径都能生效。
var levelName: String = "":
	set(value):
		levelName = value
		refreshLevelLabel()


func refreshLevelLabel() -> void:
	if levelLabel != null:
		levelLabel.text = levelName


## ── 战斗模式徽章（挑战模式才显示）──
##
## 需求：左上角能看到当前模式；**正常模式不写**（否则每个关卡都挂一个"正常"，噪音）；
## 鼠标放上去要有说明。
##
## 为什么由代码创建而不是放进 title.tscn：
##   它只是"一块带底色的文字 + tooltip"，没有任何需要在 Inspector 里调的静态属性；
##   而且只有挑战模式才存在，挂空节点在场景里反而会让编辑器里看不出它的用途。
func setBattleMode(modeId: String) -> void:
	var isChallenge: bool = modeId != "" and modeId != "normal" and Game.battleModeDefs.has(modeId)
	if not isChallenge:
		if modeChip != null:
			modeChip.visible = false
		hideModeTip()
		return
	ensureModeChip()
	modeChip.visible = true
	modeLabel.text = Game.getBattleModeName(modeId)
	# 提示内容在 showModeTip() 里现算，这里只保证隐藏时不会残留
	if modeTip != null and modeTip.visible:
		refreshModeTipText()


func ensureModeChip() -> void:
	if modeChip != null:
		return
	var chip: PanelContainer = PanelContainer.new()
	chip.name = "modeChip"
	# 挑战模式用锈红底 + 橙红描边（敌方色系），和"这是更难的规则"语义一致
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.42, 0.14, 0.10, 0.88)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.77, 0.33, 0.21, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override("panel", sb)
	# 必须能收鼠标事件，否则悬停不会触发（IGNORE 的控件不参与 hover）
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var label: Label = Label.new()
	label.name = "modeLabel"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.86, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)

	# 自定义悬停提示（不用 Control.tooltip_text 的原因：原生 tooltip 有 0.5 秒延迟、
	# 字体和颜色跟随全局主题、没法做标题+正文的层次；鼠标在徽章上稍微划一下就不出现，
	# 玩家会以为"没有提示"。这里改成 mouse_entered 立刻弹一块自己的面板。）
	chip.mouse_entered.connect(showModeTip)
	chip.mouse_exited.connect(hideModeTip)

	$hboxLevel.add_child(chip)
	modeChip = chip
	modeLabel = label

	buildModeTip()


## 悬停提示面板：标题（模式名）+ 正文（规则 + 不记星级/成就）。
func buildModeTip() -> void:
	if modeTip != null:
		return
	var tip: PanelContainer = PanelContainer.new()
	tip.name = "modeTip"
	tip.visible = false
	# 提示只是"看"的，不要抢鼠标 —— 否则移上去会触发自身 mouse_exited 造成闪烁
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.16, 0.97)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.77, 0.33, 0.21, 1.0)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	tip.add_theme_stylebox_override("panel", sb)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)

	modeTipTitle = Label.new()
	modeTipTitle.name = "title"
	modeTipTitle.add_theme_font_size_override("font_size", 30)
	modeTipTitle.add_theme_color_override("font_color", Color(1.0, 0.78, 0.56, 1.0))
	modeTipTitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(modeTipTitle)

	modeTipBody = Label.new()
	modeTipBody.name = "body"
	modeTipBody.add_theme_font_size_override("font_size", 26)
	modeTipBody.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0, 1.0))
	modeTipBody.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modeTipBody.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	modeTipBody.custom_minimum_size = Vector2(560, 0)
	box.add_child(modeTipBody)

	tip.add_child(box)
	# 挂在 title 根节点上（不是 hboxLevel）—— 否则会被 HBox 当成第三个兄弟节点参与排版
	add_child(tip)
	modeTip = tip


func refreshModeTipText() -> void:
	if modeTipTitle == null or modeTipBody == null:
		return
	var modeId: String = Game.battleMode
	modeTipTitle.text = Game.getBattleModeName(modeId)
	modeTipBody.text = "%s%s" % [
		Game.getBattleModeDesc(modeId),
		Game.t("_ModeChallengeNote", " (no stars / achievements)"),
	]


func showModeTip() -> void:
	if modeChip == null or not modeChip.visible:
		return
	ensureModeChip()
	refreshModeTipText()
	modeTip.visible = true
	modeTip.reset_size()
	# 贴在徽章正下方；右侧越界就改为右对齐
	var local_chip: Vector2 = modeChip.global_position - global_position
	var pos: Vector2 = local_chip + Vector2(0, modeChip.size.y + 8)
	var limit: float = size.x - modeTip.size.x - 12.0
	if limit > 0.0:
		pos.x = clampf(pos.x, 12.0, limit)
	modeTip.position = pos


func hideModeTip() -> void:
	if modeTip != null:
		modeTip.visible = false


## ▶/⏸ 是 toggle_mode 按钮，两种状态的语义：
##   button_pressed = true  → 显示 ⏸（暂停图）→ 意思是「正在运行，点我暂停」
##   button_pressed = false → 显示 ▶（播放图）→ 意思是「已暂停，点我继续」
## 所以状态同步是 set_playing(正在运行)。
##
## ⚠️ 必须用 set_pressed_no_signal —— 直接写 button_pressed 会触发 toggled，
##    反过来又发一次 start / pause，声音和状态都会错乱。
## 开始按钮的呼吸提示循环（见 prompt_start）
var promptTween: Tween


func setPlaying(playing: bool) -> void:
	if btnStart and btnStart.button_pressed != playing:
		btnStart.set_pressed_no_signal(playing)


## 开始按钮的呼吸提示：还在等玩家开打时，让 ▶ 一闪一闪。
## 关卡情报弹窗一关就调它；玩家点了开始再 stop_prompt()。
func promptStart() -> void:
	stopPrompt()
	if btnStart == null:
		return
	btnStart.pivot_offset = btnStart.size * 0.5
	# ⚠️ 用 parallel() 只让「紧跟的那一条」并行。
	#    别用 set_parallel(true) —— 那会让后面**所有** tweener 都并行，
	#    "变亮"和"变暗"、"放大"和"缩小"同时跑，互相抵消，scale 会永远停在 1.0（这里踩过）。
	promptTween = create_tween().set_loops()
	promptTween.tween_property(btnStart, "modulate", Color(1.9, 1.8, 1.25), 0.45).set_trans(Tween.TRANS_SINE)
	promptTween.parallel().tween_property(btnStart, "scale", Vector2(1.14, 1.14), 0.45).set_trans(Tween.TRANS_SINE)
	promptTween.tween_property(btnStart, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
	promptTween.parallel().tween_property(btnStart, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


func stopPrompt() -> void:
	if promptTween != null and promptTween.is_valid():
		promptTween.kill()
	promptTween = null
	if btnStart != null:
		btnStart.modulate = Color.WHITE
		btnStart.scale = Vector2.ONE


func onTextureButtonToggled(toggled_on: bool) -> void:
	if toggled_on:
		# 刚按下 → 现在显示 ⏸ → 意思是开始 / 继续
		started.emit()
	else:
		# 刚弹起 → 现在显示 ▶ → 意思是暂停
		paused.emit()


## 倍速按钮（1X / 2X）。
##
## 按钮本身是 toggle_mode 的 Button：按下 = 2 倍速，弹起 = 正常速度。
## 文案和颜色都在这里改，因为"现在是不是加速中"必须一眼看得出来 ——
## 只换文字在 70px 的小方块里太不显眼，所以加速时额外染成安全黄。
##
## ⚠️ 真正的加速在 map.gd::onSpeedOnPressed / onSpeedOffPressed 里做（改 Engine.time_scale），
##    而且**必须在离开关卡时复位**，否则会漏到菜单等其它场景 —— 见 map.gd::resetGameSpeed()。
const SPEED_TEXT_NORMAL := "1X"
const SPEED_TEXT_FAST := "2X"
const SPEED_COLOR_NORMAL := Color(1, 1, 1, 1)
const SPEED_COLOR_FAST := Color(1, 0.7764706, 0.101960786, 1)

func onBtnSpeedToggled(toggled_on: bool) -> void:
	applySpeedVisual(toggled_on)
	if toggled_on:
		speedOnPressed.emit()
	else:
		speedOffPressed.emit()


## 只负责按钮自己的外观（文字 + 颜色），不碰引擎状态
func applySpeedVisual(fast: bool) -> void:
	if btnSpeed == null:
		return
	btnSpeed.text = SPEED_TEXT_FAST if fast else SPEED_TEXT_NORMAL
	btnSpeed.modulate = SPEED_COLOR_FAST if fast else SPEED_COLOR_NORMAL


## 外部（map.gd）复位加速时调用，把按钮一起掰回 1X。
## 用 set_pressed_no_signal：直接写 button_pressed 会再触发一次 toggled。
func resetSpeedButton() -> void:
	if btnSpeed == null:
		return
	btnSpeed.set_pressed_no_signal(false)
	applySpeedVisual(false)


func onBtnSoundToggled(toggled_on: bool) -> void:
	if toggled_on:
		soundOffPressed.emit()
	else:
		soundOnPressed.emit()

func onBtnMusicToggled(toggled_on: bool) -> void:
	if toggled_on:
		musicOffPressed.emit()
	else:
		musicOnPressed.emit()


func onBtnHomePressed() -> void:
	homePressed.emit()


func _ready() -> void:
	# 顶栏「得分:」之前是场景里硬编码的英文，这里走翻译
	scoreTitle.text = tr("_Score")
	# 宝石数来自存档（技能消耗的就是它），进关卡先同步一次
	gem = UserData.gem
	# 关卡名靠左对齐。静态属性代码里设一次就够（code_design.md §6.3）——
	# Label 默认居中，会让名字在左侧空出一大块，看着像没对齐。
	if levelLabel != null:
		levelLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# map.gd 可能已经在它自己的 _ready() 里赋过关卡名（那时本节点还没进树，
	# @onready 未求值）—— 这里补写一次，保证名字一定显示出来。
	refreshLevelLabel()
