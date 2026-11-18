extends Node2D
## Reusable skill VFX: animated procedural marks, optional particles, and an optional 2D sound.

@export var effectStyle: String = "pulse"
@export var effectColor: Color = Color(0.35, 0.85, 1.0, 1.0)
@export var effectDuration: float = 1.2
@export var persistent: bool = false
@export_file("*.ogg", "*.wav", "*.mp3") var soundPath: String = ""

@onready var particles: CPUParticles2D = $Particles
@onready var soundPlayer: AudioStreamPlayer2D = $SkillSound
@onready var lifeTimer: Timer = $LifeTimer

var elapsed: float = 0.0


func _ready() -> void:
	z_index = 12
	particles.color = effectColor
	particles.emitting = true
	particles.restart()
	if not soundPath.is_empty():
		if not ResourceLoader.exists(soundPath):
			push_error("Tower skill effect sound not found: " + soundPath)
		else:
			var sound: Resource = load(soundPath)
			if sound is AudioStream:
				soundPlayer.stream = sound
				soundPlayer.play()
			else:
				push_error("Tower skill effect sound is not an AudioStream: " + soundPath)
	if not persistent:
		lifeTimer.wait_time = maxf(effectDuration, 0.1)
		lifeTimer.start()


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var phase: float = elapsed * (1.8 if persistent else 2.4)
	var pulse: float = 0.5 + 0.5 * sin(phase)
	var radius: float = 34.0 + pulse * 8.0
	var alpha: float = 0.58 + pulse * 0.22
	var color: Color = Color(effectColor.r, effectColor.g, effectColor.b, alpha)
	draw_circle(Vector2.ZERO, radius, Color(effectColor.r, effectColor.g, effectColor.b, 0.055 + pulse * 0.04))

	match effectStyle:
		"overheat":
			_drawRotatingArcs(radius, color, phase, 4)
			for i in 4:
				var x: float = -18.0 + float(i) * 12.0
				var heat: float = sin(phase * 2.0 + float(i)) * 5.0
				draw_line(Vector2(x, -25.0 + heat), Vector2(x + 4.0, -39.0 + heat), color, 2.5, true)
		"pierce":
			_drawSpokes(radius, color, phase, 6)
			for i in 4:
				var angle: float = phase + TAU * float(i) / 4.0
				var point: Vector2 = Vector2.from_angle(angle) * radius
				draw_circle(point, 3.0, color)
		"missile":
			_drawRotatingArcs(radius, color, -phase, 2)
			for i in 2:
				var angle: float = phase + TAU * float(i) / 2.0
				var point: Vector2 = Vector2.from_angle(angle) * radius
				draw_line(point, point - Vector2.from_angle(angle) * 15.0, color, 3.0, true)
				draw_circle(point, 3.5, color)
		"overload":
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 2.5, true)
			draw_arc(Vector2.ZERO, radius - 9.0, phase, phase + PI * 1.5, 36, color, 2.0, true)
			_drawSpokes(radius, color, -phase * 0.7, 8)
		"singular":
			var inner_radius: float = 12.0 + pulse * 12.0
			draw_arc(Vector2.ZERO, inner_radius, phase, phase + TAU * 0.78, 48, color, 3.0, true)
			draw_arc(Vector2.ZERO, radius, -phase, -phase + TAU * 0.56, 48, color, 1.8, true)
			draw_circle(Vector2.ZERO, 4.0 + pulse * 2.0, color)
		"chain":
			_drawRotatingArcs(radius, color, phase, 3)
			for i in 4:
				var angle: float = phase + TAU * float(i) / 4.0
				var start: Vector2 = Vector2.from_angle(angle) * (radius - 8.0)
				var finish: Vector2 = Vector2.from_angle(angle + 0.38) * (radius + 4.0)
				var middle: Vector2 = start.lerp(finish, 0.5) + Vector2.from_angle(angle + PI * 0.5) * 5.0
				draw_line(start, middle, color, 2.0, true)
				draw_line(middle, finish, color, 2.0, true)
		"scramble":
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 1.7, true)
			for i in 3:
				var angle: float = phase + TAU * float(i) / 3.0
				var point: Vector2 = Vector2.from_angle(angle) * radius
				draw_circle(point, 4.0, color)
				draw_arc(point, 7.0, phase, phase + PI, 16, color, 1.2, true)
		"armor":
			_drawPolygon(radius, color, 6, phase * 0.35)
			_drawPolygon(radius - 7.0, Color(effectColor.r, effectColor.g, effectColor.b, alpha * 0.45), 6, phase * 0.35)
		"invincible":
			_drawRotatingArcs(radius + 8.0, color, -phase * 0.45, 3)
			_drawShield(color, phase * 0.12)
			draw_circle(Vector2.ZERO, 4.0 + pulse * 2.0, color)
		"repair":
			draw_arc(Vector2.ZERO, radius, phase, phase + TAU * 0.72, 48, color, 2.5, true)
			draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), color, 3.0, true)
			draw_line(Vector2(0.0, -9.0), Vector2(0.0, 9.0), color, 3.0, true)
		_:
			_drawRotatingArcs(radius, color, phase, 3)


func _drawRotatingArcs(radius: float, color: Color, phase: float, count: int) -> void:
	for i in count:
		var start: float = phase + TAU * float(i) / float(count)
		draw_arc(Vector2.ZERO, radius, start, start + TAU * 0.2, 24, color, 2.5, true)


func _drawSpokes(radius: float, color: Color, phase: float, count: int) -> void:
	for i in count:
		var angle: float = phase + TAU * float(i) / float(count)
		draw_line(
			Vector2.from_angle(angle) * (radius - 10.0),
			Vector2.from_angle(angle) * (radius + 1.0),
			color,
			2.0,
			true
		)


func _drawPolygon(radius: float, color: Color, sides: int, rotation: float) -> void:
	var points := PackedVector2Array()
	for i in sides + 1:
		var angle: float = rotation + TAU * float(i) / float(sides)
		points.append(Vector2.from_angle(angle) * radius)
	draw_polyline(points, color, 2.0, true)


func _drawShield(color: Color, rotation: float) -> void:
	var points := PackedVector2Array([
		Vector2(0.0, -46.0),
		Vector2(34.0, -32.0),
		Vector2(30.0, 12.0),
		Vector2(0.0, 42.0),
		Vector2(-30.0, 12.0),
		Vector2(-34.0, -32.0),
		Vector2(0.0, -46.0),
	])
	for i in points.size():
		points[i] = points[i].rotated(rotation)
	draw_polyline(points, color, 3.0, true)
	draw_line(
		Vector2(-12.0, 0.0).rotated(rotation),
		Vector2(-3.0, 9.0).rotated(rotation),
		color,
		2.5,
		true
	)
	draw_line(
		Vector2(-3.0, 9.0).rotated(rotation),
		Vector2(15.0, -13.0).rotated(rotation),
		color,
		2.5,
		true
	)


func _on_life_timer_timeout() -> void:
	particles.emitting = false
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.24)
	fade.tween_callback(queue_free)
