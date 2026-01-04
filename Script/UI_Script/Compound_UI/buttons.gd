extends BaseUI

@onready var intensify_ui = $PanelContainer/VBoxContainer/PanelContainer2/intensify_margincontainer
@onready var compound_ui = $PanelContainer/VBoxContainer/PanelContainer2/compound_margincontainer
@onready var equipment_enhancement_ui = $"."

func _ready() -> void:
	begin()

func _on_intensify_button_button_down() -> void:
	intensify_ui.show()
	compound_ui.hide()

func _on_compound_button_button_down() -> void:
	compound_ui.show()
	intensify_ui.hide()


func _on_exit_button_button_down() -> void:
	equipment_enhancement_ui.hide()
