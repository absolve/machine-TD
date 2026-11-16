extends Node
## 场景过渡：整屏遮罩用 **Seamless Striped Flower** 动画覆盖，期间异步加载目标场景。
##
## 结构见 `scene/scene_transition.tscn`：
##   sceneTransition(Node, 本脚本)
##     └─ CanvasLayer(CanvasLayer, layer 100)
##          └─ overlay(ColorRect + transition.gdshader)
##
## 用法：`SceneTransition.changeScene("res://scene/welcome.tscn")`
##
## 着色器是 cashew-olddew/Universal-Transition-Shader（CC0，见 shader/transition.gdshader 头部注释）。
## 当前配方 = README 的 Seamless Striped Flower：Clock + invert + grid (5,5) + flip_frequency (2,2) + sectors 16。
##
## ⚠️ 不要假设 progress 的 0/1 就是"透明/盖满"：不同 transition_type 的公式方向都不一样，
##    连"盖满"落在哪个 progress 上都取决于 position。两个端点一律用 getProgressEnds() 现算，
##    下面的注释里有完整推导和实测数据。
## 换配方只改 scene_transition.tscn 的 ShaderMaterial，代码不用动。

const DEFAULT_DURATION := 0.6

# ---------- 两端 progress（配方无关） ----------
#
# ⚠️ 不要写死 "progress = 1 就是盖满"。四种 transition_type 的公式不一样，
#    "盖满 / 全透明"对应的 raw progress 方向、量级都不同：
#
#   Clock  smoothstep(0, f, p*k - angle)     k = 2π/sectors
#   Shape  smoothstep(p - f/2, p + f/2, radius/d)
#   Basic  smoothstep(p - f/2, p + f/2, max(|uv.x|,|uv.y|))
#   Mask   取决于外部黑白贴图，算不出阈值，按 Basic 保守处理
#
# 而且**同一配方里"盖满"的位置也取决于 position**：Fan 用的是 position (0,0)，
# 屏幕只占其中一个角，实际扫到的角度范围只有半个扇区，所以它比按整圆算出来的早得多就盖满了
# （实测 p≈0.5 就全盖住，而不是我以为的 p≈0）—— 早盖满意味着补间后半段白跑。
#
# 所以这里不套公式，改成**采样屏幕真实覆盖到的 uv 方块**，量出距离/角度的极值，
# 再反解出两个边界。镜像/翻转/网格只是把 uv 重排，不会超出这个方块，可以忽略。

const SAMPLE_N := 48
const END_EPS := 0.004


## 屏幕完全透明 / 完全盖满 两个 raw progress，返回 (clear, cover)
func getProgressEnds() -> Vector2:
	var f := _feather()
	var clock := _transitionType() == 3
	var pos: Vector2 = _param("position", Vector2.ZERO)
	var rot := deg_to_rad(float(_param("rotation_angle", 0.0)))
	var sector := 2.0 * PI / float(maxi(int(_param("sectors", 1)), 1))
	var edges := maxi(int(_param("edges", 6)), 3)
	var half := PI / float(edges)
	var poly := 2.0 * PI / float(edges)

	var lo := INF
	var hi := -INF
	# 格心采样（+0.5）：避开格子边界上 mod() 的跳变点（正好取到会得到一个假的 0）
	for i in SAMPLE_N:
		for j in SAMPLE_N:
			var t := Vector2((float(i) + 0.5) / float(SAMPLE_N), (float(j) + 0.5) / float(SAMPLE_N))
			var uv := (t - pos) * 2.0
			if not is_zero_approx(rot):
				uv = uv.rotated(rot)
			if clock:
				lo = minf(lo, fposmod(atan2(uv.y, uv.x) - sector * 0.5, sector))
				hi = maxf(hi, fposmod(atan2(uv.y, uv.x) - sector * 0.5, sector))
			elif _transitionType() == 2:
				var d := cos(half) / cos(fposmod(atan2(uv.y, uv.x) + half, poly) - half)
				lo = minf(lo, uv.length() / d)
				hi = maxf(hi, uv.length() / d)
			else:
				lo = minf(lo, maxf(absf(uv.x), absf(uv.y)))
				hi = maxf(hi, maxf(absf(uv.x), absf(uv.y)))

	# 换成 progress 的两个边界
	var p_low: float
	var p_high: float
	if clock:
		p_low = lo / sector                    # p <= 它 -> transition_progress 恒 0
		p_high = (hi + f) / sector             # p >= 它 -> transition_progress 恒 1
	else:
		p_low = lo - f * 0.5                   # p <= 它 -> transition_progress 恒 1
		p_high = hi + f * 0.5                  # p >= 它 -> transition_progress 恒 0

	# 谁"盖满"取决于类型和 invert 的组合：
	#   Clock !invert / Shape invert  -> p 大的那头盖满
	#   Clock  invert / Shape !invert -> p 小的那头盖满
	if clock != _inverted():
		return Vector2(p_low - END_EPS, p_high + END_EPS)
	return Vector2(p_high + END_EPS, p_low - END_EPS)


func _transitionType() -> int:
	return int(_param("transition_type", 0))


func _inverted() -> bool:
	return bool(_param("invert", false))


## 当前配方对应的软边宽度
func _feather() -> float:
	match _transitionType():
		2:
			return maxf(float(_param("shape_feather", 0.1)), 0.0)
		3:
			return maxf(float(_param("clock_feather", 0.0)), 0.0)
		_:
			return maxf(float(_param("basic_feather", 0.0)), 0.0)


func _param(key: String, fallback: Variant) -> Variant:
	if _material == null:
		return fallback
	var raw: Variant = _material.get_shader_parameter(key)
	return fallback if raw == null else raw

@onready var overlay: ColorRect = $CanvasLayer/overlay

var isTransitioning: bool = false
var pendingScenePath: String = ""
var pendingDuration: float = 0.0

var _material: ShaderMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = overlay.material as ShaderMaterial
	overlay.visible = false
	setProgress(getProgressEnds().x)


# 切换到指定场景：先擦入遮罩，后台加载场景，加载完后再擦出
func changeScene(path: String, duration: float = DEFAULT_DURATION) -> void:
	if isTransitioning:
		return
	isTransitioning = true
	pendingScenePath = path
	pendingDuration = duration

	var ends: Vector2 = getProgressEnds()
	overlay.visible = true
	setProgress(ends.x)

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(setProgress, ends.x, ends.y, maxf(duration * 0.5, 0.12))
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
	var ends: Vector2 = getProgressEnds()
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(setProgress, ends.y, ends.x, maxf(pendingDuration * 0.5, 0.12))
	tween.tween_callback(onFinished)


func onFinished() -> void:
	setProgress(getProgressEnds().x)
	overlay.visible = false
	pendingScenePath = ""
	pendingDuration = 0.0
	isTransitioning = false


func setProgress(value: float) -> void:
	if _material != null:
		_material.set_shader_parameter("progress", value)


# 过渡期间消费所有输入事件，防止点击穿透到下层场景
func _input(_event: InputEvent) -> void:
	if isTransitioning:
		get_viewport().set_input_as_handled()
