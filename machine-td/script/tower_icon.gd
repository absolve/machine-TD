extends TextureRect

@export var type:int

signal infoShown
signal infoHidden
signal selected

func onMouseEntered():
	infoShown.emit(type)


func onMouseExited():
	infoHidden.emit(type)



func onGuiInput(_event):
	if Input.is_action_just_pressed("click"):
		selected.emit(type)
