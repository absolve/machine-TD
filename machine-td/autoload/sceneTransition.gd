extends Node2D

# 场景过渡动画全局管理器
# 现在使用简单版: 黑色全屏淡入 -> 资源加载 -> 黑色全屏淡出

# 用法: SceneTransition.change_scene("res://scene/welcome.tscn")

const DEFAULT_DURATION := 0.6
const SCREEN_SIZE := Vector2(1920, 1080)

var canvas_layer: CanvasLayer
var color_rect: ColorRect
var is_transitioning := false
var pending_scene_path: String = ""
var pending_duration: float = 0.0

func _ready() -> void:
	z_index=999
	process_mode = Node.PROCESS_MODE_ALWAYS
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_layer)

	color_rect = ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.size = SCREEN_SIZE
	color_rect.position = Vector2.ZERO
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	color_rect.offset_left = 0
	color_rect.offset_top = 0
	color_rect.offset_right = 0
	color_rect.offset_bottom = 0
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	color_rect.modulate = Color(1, 1, 1, 0.0)
	color_rect.z_index = 100
	color_rect.visible = false
	canvas_layer.add_child(color_rect)

# 切换到指定场景: 先淡入黑屏，后台加载场景，加载完后再淡出黑屏
func change_scene(path: String, duration: float = DEFAULT_DURATION) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	pending_scene_path = path
	pending_duration = duration
	color_rect.visible = true
	color_rect.modulate = Color(1, 1, 1, 0.0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "modulate:a", 1.0, maxf(duration * 0.5, 0.12))
	tween.tween_callback(_start_scene_load)


# 过渡期间消费所有输入事件, 防止点击穿透到下层场景
func _input(_event: InputEvent) -> void:
	if is_transitioning:
		get_viewport().set_input_as_handled()

func _start_scene_load() -> void:
	var err := ResourceLoader.load_threaded_request(pending_scene_path)
	if err != OK:
		push_error("SceneTransition load failed: %s" % pending_scene_path)
		_on_finished()
		return
	call_deferred("_monitor_scene_load")

func _monitor_scene_load() -> void:
	while is_transitioning:
		var status := ResourceLoader.load_threaded_get_status(pending_scene_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene := ResourceLoader.load_threaded_get(pending_scene_path)
			if packed_scene is PackedScene:
				_switch_scene(packed_scene)
				_play_fade_out()
			else:
				push_error("SceneTransition loaded non-PackedScene: %s" % pending_scene_path)
				_on_finished()
			return
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("SceneTransition failed to load: %s" % pending_scene_path)
			_on_finished()
			return
		await get_tree().process_frame

func _switch_scene(scene: PackedScene) -> void:
	get_tree().change_scene_to_packed(scene)

func _play_fade_out() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(color_rect, "modulate:a", 0.0, maxf(pending_duration * 0.5, 0.12))
	tween.tween_callback(_on_finished)

func _on_finished() -> void:
	color_rect.modulate = Color(1, 1, 1, 0.0)
	color_rect.visible = false
	pending_scene_path = ""
	pending_duration = 0.0
	is_transitioning = false
