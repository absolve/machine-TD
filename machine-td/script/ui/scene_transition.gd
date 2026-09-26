extends Node
## 场景过渡：整屏遮罩沿渐变方向擦除覆盖，期间异步加载目标场景。
##
## 结构见 `scene/scene_transition.tscn`：
##   sceneTransition(Node, 本脚本)
##     └─ canvasLayer(CanvasLayer, layer 100)
##          └─ overlay(ColorRect + transition.gdshader)
##
## 用法：`SceneTransition.change_scene("res://scene/welcome.tscn")`
##
## 着色器 `factor` 的语义：**0 = 完全透明，1 = 完全覆盖**。
## 所以进场是把 factor 从 0 补间到 1（遮罩盖住屏幕），加载完再补间回 0（露出新场景）。
## 擦除方向、软边、颜色都在场景里的 ShaderMaterial 上，不用改代码。

const DEFAULT_DURATION := 0.6

@onready var overlay: ColorRect = $canvasLayer/overlay

var is_transitioning := false
var pending_scene_path: String = ""
var pending_duration: float = 0.0

var _material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = overlay.material as ShaderMaterial
	overlay.visible = false
	_set_factor(0.0)
	_sync_resolution()
	get_viewport().size_changed.connect(_sync_resolution)


# 切换到指定场景：先擦入遮罩，后台加载场景，加载完后再擦出
func change_scene(path: String, duration: float = DEFAULT_DURATION) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	pending_scene_path = path
	pending_duration = duration

	overlay.visible = true
	_set_factor(0.0)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_factor, 0.0, 1.0, maxf(duration * 0.5, 0.12))
	tween.tween_callback(_start_scene_load)


# 过渡期间消费所有输入事件，防止点击穿透到下层场景
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
				get_tree().change_scene_to_packed(packed_scene)
				_play_wipe_out()
			else:
				push_error("SceneTransition loaded non-PackedScene: %s" % pending_scene_path)
				_on_finished()
			return
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("SceneTransition failed to load: %s" % pending_scene_path)
			_on_finished()
			return
		await get_tree().process_frame


func _play_wipe_out() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_factor, 1.0, 0.0, maxf(pending_duration * 0.5, 0.12))
	tween.tween_callback(_on_finished)


func _on_finished() -> void:
	_set_factor(0.0)
	overlay.visible = false
	pending_scene_path = ""
	pending_duration = 0.0
	is_transitioning = false


# 着色器用它做宽高比校正
func _sync_resolution() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("node_resolution", get_viewport().get_visible_rect().size)


func _set_factor(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("factor", value)
