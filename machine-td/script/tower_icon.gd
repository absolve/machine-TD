extends TextureRect

@export var type:int

signal infoShown
signal infoHidden
signal selected

func _on_mouse_entered():
	infoShown.emit(type)


func _on_mouse_exited():
	infoHidden.emit(type)



func _onGuiInput(_event):
	if Input.is_action_just_pressed("click"):
		selected.emit(type)
