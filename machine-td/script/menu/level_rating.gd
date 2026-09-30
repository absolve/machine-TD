extends HBoxContainer
## 关卡星级评价。三颗星按 rating 点亮，rating 超出 0~3 会被夹紧。
class_name LevelRating

const STAR_FULL: Texture2D = preload("res://sprite/star-4.png")
const STAR_EMPTY: Texture2D = preload("res://sprite/star-2.png")

var ratingValue: int = 0

var rating: int:
	set(value):
		ratingValue = clampi(value, 0, 3)
		updateRating()
	get:
		return ratingValue

@onready var star1: TextureRect = $Star1
@onready var star2: TextureRect = $Star2
@onready var star3: TextureRect = $Star3


func _ready() -> void:
	pass


# 更新评分显示
func updateRating() -> void:
	star1.texture = STAR_EMPTY
	star2.texture = STAR_EMPTY
	star3.texture = STAR_EMPTY
	if rating == 1:
		star1.texture = STAR_FULL
	if rating == 2:
		star1.texture = STAR_FULL
		star2.texture = STAR_FULL
	if rating == 3:
		star1.texture = STAR_FULL
		star2.texture = STAR_FULL
		star3.texture = STAR_FULL
