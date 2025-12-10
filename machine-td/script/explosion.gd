extends AnimatedSprite2D


func _ready():
	play("default")
	scale=Vector2(2,2)
	await animation_finished
	queue_free()
