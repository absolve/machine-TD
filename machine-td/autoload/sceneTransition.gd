extends Node

# 场景过渡动画全局管理器
# 动画分两段: 1.方块盖满 2.切换场景后方块消失

# 用法: SceneTransition.change_scene("res://scene/welcome.tscn")

const SHADER := preload("res://shader/scene_transition.gdshader")
const DEFAULT_DURATION := 0.8
const SCREEN_SIZE := Vector2(1920, 1080)

var canvas_layer: CanvasLayer
var color_rect: ColorRect
var shader_mat: ShaderMaterial
var is_transitioning := false


func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100 # 覆盖所有 UI 层
	add_child(canvas_layer)

	color_rect = ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.size = SCREEN_SIZE
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP # 过渡期间屏蔽鼠标输入
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = SHADER
	shader_mat.set_shader_parameter("progress", 0.0)
	color_rect.material = shader_mat
	color_rect.visible = false
	canvas_layer.add_child(color_rect)


# 切换到指定场景, 分两段播放过渡动画
func change_scene(path: String, duration: float = DEFAULT_DURATION) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	color_rect.visible = true
	shader_mat.set_shader_parameter("progress", 0.0)

	var half := duration * 0.5

	# 单个 Tween 串联两段动画, 避免 await 跨场景时序问题
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# 阶段1: 方块从底行翻转盖满 (progress 0 -> 0.5)
	tween.tween_method(_set_progress, 0.0, 0.5, half)
	# 在方块完全盖住屏幕时切换场景
	tween.tween_callback(_switch_scene.bind(path))
	# 等待新场景加载 (用 interval 而非 process_frame, 不受场景切换影响)
	tween.tween_interval(0.1)
	# 阶段2: 方块从底行收缩消失 (progress 0.5 -> 1.0)
	tween.tween_method(_set_progress, 0.5, 1.0, half)
	# 收尾
	tween.tween_callback(_on_finished)


# 过渡期间消费所有输入事件, 防止点击穿透到下层场景
func _input(_event: InputEvent) -> void:
	if is_transitioning:
		get_viewport().set_input_as_handled()


func _set_progress(value: float) -> void:
	shader_mat.set_shader_parameter("progress", value)


func _switch_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _on_finished() -> void:
	shader_mat.set_shader_parameter("progress", 0.0)
	color_rect.visible = false
	is_transitioning = false
