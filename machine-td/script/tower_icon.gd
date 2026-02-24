extends TextureRect

@export var type:String

signal showInfo
signal hideInfo

func _on_mouse_entered():
	showInfo.emit(type)


func _on_mouse_exited():
	hideInfo.emit(type)
