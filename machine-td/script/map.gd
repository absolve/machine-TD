extends Node2D


@onready var path=$Path2D
@onready var enemy=$enemy

var points=[]

func _ready():
	Game.map=self
	points=path.curve.get_baked_points()
	#print(points)
	enemy.points=points
