extends PopupPanel

@onready var titleLabel: Label = $OuterMargin/PanelContainer/InnerMargin/VBoxContainer/titleLabel
@onready var contentLabel: RichTextLabel = $OuterMargin/PanelContainer/InnerMargin/VBoxContainer/contentLabel
@onready var closeButton: Button = $OuterMargin/PanelContainer/InnerMargin/VBoxContainer/HBoxContainer/btnClose


func _ready() -> void:
	titleLabel.text = tr("_About_Title")
	contentLabel.text = tr("_About_Text")
	closeButton.text = tr("_Close")
	closeButton.pressed.connect(hide)
