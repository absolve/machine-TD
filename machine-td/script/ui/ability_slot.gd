extends Control
## 通用技能槽（所有技能共用这个场景）
##
## 只负责单个技能图标的显示与交互：
##   - 图标（素材来自 AbilityManager，可替换）
##   - 槽内 Timer 计时作为冷却时间（冷却的唯一来源）
##   - 冷却遮罩用 shader/ability_cooldown.gdshader 做扇形扫描
##   - 剩余秒数
##
## 技能条通过 setup() 传入技能 id，并监听三个信号与技能管理器对接。

signal slotClicked(abilityId: String)
signal slotHovered(abilityId: String, slot: Control)
signal slotUnhovered

# 槽背景：常态 / 高亮（正在等待选择目标）
const STYLE_NORMAL := preload("res://theme/style/btn_normal.tres")
const STYLE_ACTIVE := preload("res://theme/style/btn_hover.tres")

const COLOR_READY := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_COOLING := Color(0.72, 0.76, 0.80, 1.0)
## 宝石不够：压得比冷却更暗，一眼能看出"这个现在放不了"
const COLOR_POOR := Color(0.48, 0.50, 0.55, 1.0)

@onready var bg: Panel = $bg
@onready var icon: TextureRect = $icon
@onready var cooldownRect: ColorRect = $Cooldown
@onready var cooldownLabel: Label = $CooldownLabel
@onready var cooldownTimer: Timer = $Timer
@onready var costLabel: Label = $CostBox/costLabel
@onready var costBox: HBoxContainer = $CostBox

var abilityId: String = ""
## 宝石够不够放这个技能（由 refresh_affordable 更新）
var _affordable: bool = true


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cooldownTimer.timeout.connect(_onCooldownTimeout)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 没有冷却时不需要逐帧刷新
	set_process(false)


# 绑定技能 id 并初始化显示
func setup(id: String) -> void:
	abilityId = id
	icon.texture = AbilityManager.getIcon(id)
	cooldownTimer.stop()
	cooldownTimer.wait_time = maxf(AbilityManager.getCooldownTotal(id), 0.1)
	# 宝石成本角标：没配置成本（cost <= 0）就整块藏掉
	var cost: int = AbilityManager.getGemCost(id)
	costLabel.text = str(cost)
	costBox.visible = cost > 0
	setHighlighted(false)
	refreshAffordable()
	_refresh(0.0)


## 刷新"宝石够不够"状态。技能消耗宝石后由技能条调用。
func refreshAffordable() -> void:
	if abilityId.is_empty():
		return
	_affordable = AbilityManager.canAfford(abilityId)
	# 成本数字也跟着变色：买不起时变红
	if costLabel != null:
		costLabel.modulate = Color(1, 1, 1, 1) if _affordable else Color(1, 0.45, 0.45, 1)
	# 立刻按"当前冷却进度"重算一次配色，不等下一帧
	var total: float = cooldownTimer.wait_time
	_refresh(cooldownTimer.time_left / total if total > 0.0 else 0.0)


# 冷却是否进行中
func isCooling() -> bool:
	return cooldownTimer.time_left > 0.0


# 开始冷却（技能确认生效后由技能条调用）
func startCooldown() -> void:
	if cooldownTimer.wait_time <= 0.0:
		return
	cooldownTimer.start()
	_refresh(1.0)
	set_process(true)


# 高亮开关（等待选择目标时点亮）
func setHighlighted(on: bool) -> void:
	bg.add_theme_stylebox_override("panel", STYLE_ACTIVE if on else STYLE_NORMAL)


func _onCooldownTimeout() -> void:
	_refresh(0.0)
	set_process(false)


# 更新冷却遮罩（着色器 progress）与剩余秒数
func _refresh(ratio: float) -> void:
	var clamped: float = clampf(ratio, 0.0, 1.0)
	var mat: ShaderMaterial = cooldownRect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", clamped)
	cooldownRect.visible = clamped > 0.001

	var left: float = cooldownTimer.time_left
	cooldownLabel.visible = left > 0.0
	if left > 0.0:
		cooldownLabel.text = str(int(ceil(left)))

	# 配色优先级：宝石不够 > 冷却中 > 可用
	# （"买不起"比"冷却中"更该被看见 —— 冷却等一会就有，宝石不够得去打通关）
	if not _affordable:
		modulate = COLOR_POOR
	elif clamped > 0.001:
		modulate = COLOR_COOLING
	else:
		modulate = COLOR_READY


func _on_mouse_entered() -> void:
	slotHovered.emit(abilityId, self)


func _on_mouse_exited() -> void:
	slotUnhovered.emit()


func _process(_delta: float) -> void:
	var total: float = cooldownTimer.wait_time
	if total <= 0.0:
		set_process(false)
		return
	_refresh(cooldownTimer.time_left / total)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slotClicked.emit(abilityId)
		accept_event()
