extends HBoxContainer


@onready var star1 = $star1
@onready var star2 = $star2
@onready var star3 = $star3

var starFull = preload("res://sprite/star-4.png")
var starEmpty = preload("res://sprite/star-2.png")

var _rating: int = 0
var rating: int:
	set(val):
		_rating = clampi(val, 0, 3)
		updateRating()
	get:
		return _rating

func _ready() -> void:
	pass

#更新评分显示
func updateRating():
	star1.texture = starEmpty
	star2.texture = starEmpty
	star3.texture = starEmpty
	if rating == 1:
		star1.texture = starFull
	if rating == 2:
		star1.texture = starFull
		star2.texture = starFull
	if rating == 3:
		star1.texture = starFull
		star2.texture = starFull
		star3.texture = starFull
		
