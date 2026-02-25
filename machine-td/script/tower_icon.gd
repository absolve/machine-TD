extends TextureRect

@export var type:int

signal showInfo
signal hideInfo
signal select

func _on_mouse_entered():
	showInfo.emit(type)


func _on_mouse_exited():
	hideInfo.emit(type)



func _on_gui_input(_event):
	if Input.is_action_just_pressed("click"):
		select.emit(type)
