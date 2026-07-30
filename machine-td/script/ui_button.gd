extends Button

@onready var click=$sound

func _ready() -> void:
	pass # Replace with function body.


func _on_pressed() -> void:
	click.play()
