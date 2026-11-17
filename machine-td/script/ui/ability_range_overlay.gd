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
