extends Node2D
## Selected and hovered tower radar, drawn above the tower sprites.

@onready var tower: Tower = get_parent() as Tower


func _draw() -> void:
	if not tower.selected and not tower.hovered:
		return
	var radarColor: Color = Color(0.25, 0.75, 1.0, 1.0)
	var scopeNow: float = tower.effectiveScope()
	var sweepAngle: float = tower.radarSweepAngle
	draw_circle(Vector2.ZERO, scopeNow, Color(radarColor.r, radarColor.g, radarColor.b, 0.12))
	draw_arc(Vector2.ZERO, scopeNow, 0.0, TAU, 64,
		Color(radarColor.r, radarColor.g, radarColor.b, 0.8), 2.0)
	for i in range(1, 4):
		var radius: float = scopeNow * (float(i) / 4.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64,
			Color(radarColor.r, radarColor.g, radarColor.b, 0.15), 1.0)
	var segments: int = 24
	var tailSpan: float = PI / 3.0
	for segment in range(segments):
		var t: float = float(segment) / float(segments)
		var angle: float = sweepAngle - tailSpan * t
		var alpha: float = (1.0 - t) * 0.5
		var nextAngle: float = sweepAngle - tailSpan * (float(segment + 1) / float(segments))
		var p1: Vector2 = Vector2(cos(angle), sin(angle)) * scopeNow
		var p2: Vector2 = Vector2(cos(nextAngle), sin(nextAngle)) * scopeNow
		draw_polygon(
			PackedVector2Array([Vector2.ZERO, p1, p2]),
			PackedColorArray([
				Color(radarColor.r, radarColor.g, radarColor.b, alpha),
				Color(radarColor.r, radarColor.g, radarColor.b, alpha),
				Color(radarColor.r, radarColor.g, radarColor.b, 0.0)
			])
		)
	draw_line(
		Vector2.ZERO,
		Vector2(cos(sweepAngle), sin(sweepAngle)) * scopeNow,
		Color(radarColor.r, radarColor.g, radarColor.b, 1.0),
		2.0
	)
