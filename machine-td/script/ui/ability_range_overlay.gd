extends Node2D
## Ability target radius preview, rendered above world units.


func _draw() -> void:
	if not AbilityManager.isSelectingPosition():
		return
	var radius: float = AbilityManager.getSelectingRadius()
	if radius <= 0.0:
		return
	var mousePos: Vector2 = get_local_mouse_position()
	var circleColor: Color = Palette.HAZARD_500
	draw_circle(mousePos, radius, Color(circleColor.r, circleColor.g, circleColor.b, 0.16))
	draw_arc(mousePos, radius, 0.0, TAU, 64,
		Color(circleColor.r, circleColor.g, circleColor.b, 0.9), 3.0)
	if AbilityManager.getSelectingId() == "bombard":
		drawBombardReticle(mousePos, radius, circleColor)


func drawBombardReticle(center: Vector2, radius: float, color: Color) -> void:
	var reticleColor := Color(color.r, color.g, color.b, 0.92)
	var innerGap: float = minf(14.0, radius * 0.14)
	var armStart: float = radius * 0.26
	var armEnd: float = radius * 0.88
	var tickRadius: float = radius * 0.6
	var tickHalfLength: float = 6.0

	for axis in 2:
		var direction: Vector2 = Vector2.RIGHT if axis == 0 else Vector2.DOWN
		var perpendicular: Vector2 = Vector2(-direction.y, direction.x)
		for side in [-1.0, 1.0]:
			var signedDirection: Vector2 = direction * side
			draw_line(
				center + signedDirection * innerGap,
				center + signedDirection * armStart,
				reticleColor,
				2.5,
				true
			)
			draw_line(
				center + signedDirection * armEnd,
				center + signedDirection * radius,
				reticleColor,
				2.5,
				true
			)
			var tickCenter: Vector2 = center + signedDirection * tickRadius
			draw_line(
				tickCenter - perpendicular * tickHalfLength,
				tickCenter + perpendicular * tickHalfLength,
				reticleColor,
				2.0,
				true
			)

	draw_arc(center, 9.0, 0.0, TAU, 32, reticleColor, 2.0, true)
	draw_circle(center, 2.5, reticleColor)
