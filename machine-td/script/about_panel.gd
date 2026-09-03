extends PopupPanel

@onready var titleLabel: Label = $OuterMargin/PanelContainer/InnerMargin/VBoxContainer/titleLabel
@onready var contentLabel: RichTextLabel = $OuterMargin/PanelContainer/InnerMargin/VBoxContainer/contentLabel
@onready var closeButton: Button = $OuterMargin/PanelContainer/InnerMargin/VBoxContainer/HBoxContainer/btnClose


func _ready() -> void:
	#TranslationServer.translation_changed.connect(_refresh_text)
	#_refresh_text()
	closeButton.pressed.connect(hide)


#func _refresh_text() -> void:
	#titleLabel.text = tr("_About_Title")
	#contentLabel.text = tr("_About_Text")
	#closeButton.text = tr("_Close")
