extends Control

const WELCOME_SCENE := "res://scene/welcome.tscn"
const FALL_DURATION := 0.75
const TRAIL_POINT_DISTANCE := 3.0
const TRAIL_MAX_POINTS := 50

## 开场那个小球：从**屏幕下方外面**出现，一边往上走一边长大到正常大小。
## 原来是 0.5 倍、从屏幕外面升上来，几乎看不出"由小变大"；现在压到 0.15。
const START_SCALE := 0.15
## 起点：屏幕**底边再往下**这么多像素。用加号（view.y + …），不是减号 ——
## 减号是往屏幕上边挪，小球会留在画面里。
## 半径 160 * 0.15 = 24px，这里留 120，所以一开始整颗球都在画面外、完全看不见。
const START_BELOW_SCREEN := 120.0

@onready var logoContainer: Node2D = $LogoContainer
@onready var ball: Panel = $LogoContainer/Ball
@onready var logo: TextureRect = $LogoContainer/Logo
@onready var trail: Line2D = $Trail

var trailPoints: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	var view: Vector2 = get_viewport_rect().size
	var center: Vector2 = view * 0.5
	# 起点：水平居中、在屏幕**底边下方外面**
	logoContainer.position = Vector2(center.x, view.y + START_BELOW_SCREEN)
	logoContainer.scale = Vector2(START_SCALE, START_SCALE)
	logo.modulate = Color(0.12, 0.15, 0.2, 1.0)
	trail.clear_points()

	var tween: Tween = create_tween()
	tween.tween_interval(1.3)
	# ⚠️ 这里**不要**用 TRANS_BACK：它在前 7% 的时间里就走了将近 80%，
	#    小球会"啪"一下弹到正常大小，"逐渐变大"根本看不出来（实测 t=0.05s 时缩放已经 0.81）。
	#    改成 SINE/EASE_OUT，慢慢升、慢慢长，落地的弹跳交给后面那几步。
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(logoContainer, "position", center, FALL_DURATION)
	tween.parallel().tween_property(logoContainer, "scale", Vector2.ONE, FALL_DURATION)
	# 落地这一小跳保持原来的 BACK 手感（只改上升那一段的曲线）
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(logoContainer, "position:y", center.y - 42.0, 0.16)
	tween.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(logoContainer, "position:y", center.y, 0.24)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(logoContainer, "scale", Vector2.ONE, 0.16)
	tween.tween_property(ball, "modulate:a", 0.0, 0.36)
	tween.parallel().tween_property(logo, "modulate", Color.WHITE, 0.36)
	tween.parallel().tween_property(logoContainer, "scale", Vector2(1.12, 1.12), 0.36)
	tween.parallel().tween_property(trail, "modulate:a", 0.0, 0.36)
	tween.tween_interval(0.55)
	tween.tween_callback(openWelcome)


func _process(_delta: float) -> void:
	var pos: Vector2 = logoContainer.position
	if not trailPoints.is_empty() and trailPoints[-1].distance_to(pos) < TRAIL_POINT_DISTANCE:
		return

	trailPoints.append(pos)
	if trailPoints.size() > TRAIL_MAX_POINTS:
		trailPoints.remove_at(0)
	trail.points = trailPoints


func openWelcome() -> void:
	SceneTransition.changeScene(WELCOME_SCENE, 0.5)
