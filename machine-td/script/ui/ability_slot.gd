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

signal slot_clicked(ability_id: String)
signal slot_hovered(ability_id: String, slot: Control)
signal slot_unhovered

# 槽背景：常态 / 高亮（正在等待选择目标）
const STYLE_NORMAL := preload("res://theme/style/btn_normal.tres")
const STYLE_ACTIVE := preload("res://theme/style/btn_hover.tres")

const COLOR_READY := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_COOLING := Color(0.72, 0.76, 0.80, 1.0)
## 宝石不够：压得比冷却更暗，一眼能看出"这个现在放不了"
const COLOR_POOR := Color(0.48, 0.50, 0.55, 1.0)

@onready var bg: Panel = $bg
@onready var icon: TextureRect = $icon
@onready var cooldown_rect: ColorRect = $cooldown
@onready var cooldown_label: Label = $cooldownLabel
@onready var cooldown_timer: Timer = $Timer
@onready var cost_label: Label = $costBox/costLabel
@onready var cost_box: HBoxContainer = $costBox

var ability_id: String = ""
## 宝石够不够放这个技能（由 refresh_affordable 更新）
var _affordable: bool = true


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	# 没有冷却时不需要逐帧刷新
	set_process(false)


# 绑定技能 id 并初始化显示
func setup(id: String) -> void:
	ability_id = id
	icon.texture = AbilityManager.get_icon(id)
	cooldown_timer.stop()
	cooldown_timer.wait_time = maxf(AbilityManager.get_cooldown_total(id), 0.1)
	# 宝石成本角标：没配置成本（cost <= 0）就整块藏掉
	var cost := AbilityManager.get_gem_cost(id)
	cost_label.text = str(cost)
	cost_box.visible = cost > 0
	set_highlighted(false)
	refresh_affordable()
	_refresh(0.0)


## 刷新"宝石够不够"状态。技能消耗宝石后由技能条调用。
func refresh_affordable() -> void:
	if ability_id.is_empty():
		return
	_affordable = AbilityManager.can_afford(ability_id)
	# 成本数字也跟着变色：买不起时变红
	if cost_label != null:
		cost_label.modulate = Color(1, 1, 1, 1) if _affordable else Color(1, 0.45, 0.45, 1)
	# 立刻按"当前冷却进度"重算一次配色，不等下一帧
	var total := cooldown_timer.wait_time
	_refresh(cooldown_timer.time_left / total if total > 0.0 else 0.0)


# 冷却是否进行中
func is_cooling() -> bool:
	return cooldown_timer.time_left > 0.0


# 开始冷却（技能确认生效后由技能条调用）
func start_cooldown() -> void:
	if cooldown_timer.wait_time <= 0.0:
		return
	cooldown_timer.start()
	_refresh(1.0)
	set_process(true)


# 高亮开关（等待选择目标时点亮）
func set_highlighted(on: bool) -> void:
	bg.add_theme_stylebox_override("panel", STYLE_ACTIVE if on else STYLE_NORMAL)


func _process(_delta: float) -> void:
	var total := cooldown_timer.wait_time
	if total <= 0.0:
		set_process(false)
		return
	_refresh(cooldown_timer.time_left / total)


func _on_cooldown_timeout() -> void:
	_refresh(0.0)
	set_process(false)


# 更新冷却遮罩（着色器 progress）与剩余秒数
func _refresh(ratio: float) -> void:
	var clamped := clampf(ratio, 0.0, 1.0)
	var mat := cooldown_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", clamped)
	cooldown_rect.visible = clamped > 0.001

	var left := cooldown_timer.time_left
	cooldown_label.visible = left > 0.0
	if left > 0.0:
		cooldown_label.text = str(int(ceil(left)))

	# 配色优先级：宝石不够 > 冷却中 > 可用
	# （"买不起"比"冷却中"更该被看见 —— 冷却等一会就有，宝石不够得去打通关）
	if not _affordable:
		modulate = COLOR_POOR
	elif clamped > 0.001:
		modulate = COLOR_COOLING
	else:
		modulate = COLOR_READY


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(ability_id)
		accept_event()


func _on_mouse_entered() -> void:
	slot_hovered.emit(ability_id, self)


func _on_mouse_exited() -> void:
	slot_unhovered.emit()
