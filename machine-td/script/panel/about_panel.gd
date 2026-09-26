extends Control
## 关于面板。已从 PopupPanel 改为普通 Control，否则嵌入式子窗口会盖在场景切换遮罩之上。

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
