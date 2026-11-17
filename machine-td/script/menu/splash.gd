extends Control

const WELCOME_SCENE := "res://scene/welcome.tscn"
const FALL_DURATION := 0.75
const TRAIL_POINT_DISTANCE := 3.0
const TRAIL_MAX_POINTS := 22

@onready var logoContainer: Node2D = $LogoContainer
@onready var ball: Panel = $LogoContainer/Ball
@onready var logo: TextureRect = $LogoContainer/Logo
@onready var trail: Line2D = $Trail

var trailPoints: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	var center: Vector2 = get_viewport_rect().size * 0.5
	logoContainer.position = center + Vector2(0.0, minf(size.y * 0.65, 700.0))
	logoContainer.scale = Vector2(0.5, 0.5)
	logo.modulate = Color(0.12, 0.15, 0.2, 1.0)
	trail.clear_points()

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(logoContainer, "position", center, FALL_DURATION)
	tween.parallel().tween_property(logoContainer, "scale", Vector2.ONE, FALL_DURATION)
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
	var position: Vector2 = logoContainer.position
	if not trailPoints.is_empty() and trailPoints[-1].distance_to(position) < TRAIL_POINT_DISTANCE:
		return

	trailPoints.append(position)
	if trailPoints.size() > TRAIL_MAX_POINTS:
		trailPoints.remove_at(0)
	trail.points = trailPoints


func openWelcome() -> void:
	SceneTransition.changeScene(WELCOME_SCENE, 0.5)
