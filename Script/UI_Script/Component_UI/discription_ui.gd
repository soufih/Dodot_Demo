extends Control
class_name discriptionUI

@onready var Name = $PanelContainer/MarginContainer/VBoxContainer/Name
@onready var Description = $PanelContainer/MarginContainer/VBoxContainer/Description
@onready var Property = $PanelContainer/MarginContainer/VBoxContainer/Property

func modify_displayed_information(itemConfig:Dictionary):
	if !itemConfig:
		return
	
	Name.text = ResourceManager.get_item_name(itemConfig.id) 
	Description.text = ResourceManager.get_item_discription(itemConfig.id)


func _on_panel_gui_input(event: InputEvent) -> void:
	if event.as_text() == "Right Mouse Button":
		hide()
