extends HBoxContainer
## 关卡星级评价。三颗星按 rating 点亮，rating 超出 0~3 会被夹紧。
class_name LevelRating

const STAR_FULL: Texture2D = preload("res://sprite/star-4.png")
const STAR_EMPTY: Texture2D = preload("res://sprite/star-2.png")

## 两张星图都是白色描边 / 白色实心，空星压成灰蓝，
## 否则「还没打过的关卡」看上去和「三颗星」一样满。
const TINT_FULL := Color(1, 1, 1, 1)
const TINT_EMPTY := Color(Palette.UI_720, 0.85)

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
	# 卡片在 _ready 里写 rating，那是在子节点 _ready 之后，所以这里先铺一遍默认态，
	# 免得星星节点在赋值之前是空的。
	updateRating()


# 更新评分显示
func updateRating() -> void:
	var stars: Array[TextureRect] = [star1, star2, star3]
	for i in stars.size():
		var lit: bool = i < rating
		stars[i].texture = STAR_FULL if lit else STAR_EMPTY
		stars[i].modulate = TINT_FULL if lit else TINT_EMPTY
