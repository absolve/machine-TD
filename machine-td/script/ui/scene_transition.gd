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

@onready var overlay: ColorRect = $CanvasLayer/overlay

var isTransitioning: bool = false
var pendingScenePath: String = ""
var pendingDuration: float = 0.0

var _material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = overlay.material as ShaderMaterial
	overlay.visible = false
	setFactor(0.0)
	syncResolution()
	get_viewport().size_changed.connect(syncResolution)


# 切换到指定场景：先擦入遮罩，后台加载场景，加载完后再擦出
func changeScene(path: String, duration: float = DEFAULT_DURATION) -> void:
	if isTransitioning:
		return
	isTransitioning = true
	pendingScenePath = path
	pendingDuration = duration

	overlay.visible = true
	setFactor(0.0)

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(setFactor, 0.0, 1.0, maxf(duration * 0.5, 0.12))
	tween.tween_callback(startSceneLoad)


func startSceneLoad() -> void:
	var err: int = ResourceLoader.load_threaded_request(pendingScenePath)
	if err != OK:
		push_error("SceneTransition load failed: %s" % pendingScenePath)
		onFinished()
		return
	call_deferred("monitorSceneLoad")


func monitorSceneLoad() -> void:
	while isTransitioning:
		var status: int = ResourceLoader.load_threaded_get_status(pendingScenePath)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packedScene: Resource = ResourceLoader.load_threaded_get(pendingScenePath)
			if packedScene is PackedScene:
				get_tree().change_scene_to_packed(packedScene)
				playWipeOut()
			else:
				push_error("SceneTransition loaded non-PackedScene: %s" % pendingScenePath)
				onFinished()
			return
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("SceneTransition failed to load: %s" % pendingScenePath)
			onFinished()
			return
		await get_tree().process_frame


func playWipeOut() -> void:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(setFactor, 1.0, 0.0, maxf(pendingDuration * 0.5, 0.12))
	tween.tween_callback(onFinished)


func onFinished() -> void:
	setFactor(0.0)
	overlay.visible = false
	pendingScenePath = ""
	pendingDuration = 0.0
	isTransitioning = false


# 着色器用它做宽高比校正
func syncResolution() -> void:
	if _material == null:
		return
	_material.set_shader_parameter("node_resolution", get_viewport().get_visible_rect().size)


func setFactor(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("factor", value)


# 过渡期间消费所有输入事件，防止点击穿透到下层场景
func _input(_event: InputEvent) -> void:
	if isTransitioning:
		get_viewport().set_input_as_handled()
