extends Area2D

@onready var shapNode = $shape

@export var color: Color = Color("d299b36b")
@export var isShow = false:
	set(value):
		isShow = value
		queue_redraw()
		
func _ready():
	print(shapNode.shape)
	pass


func _draw():
	if isShow && shapNode.shape != null:
		var rect = Rect2(-shapNode.shape.get_rect().size / 2,
		shapNode.shape.get_rect().size)
		print(rect)
		draw_rect(rect, color)
