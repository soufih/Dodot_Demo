extends PanelContainer
class_name itemListslot

signal slot_pressed

@onready var icon:TextureRect = $MarginContainer/item_icon_true
@onready var itemName: Label = $MarginContainer/HBoxContainer/item_name
@onready var amount: Label = $MarginContainer/HBoxContainer/item_amount

var id: int


func modify_item_display(itemConfig:Dictionary):
	id = itemConfig.id
	icon.texture = ResourceManager.get_item_icon(itemConfig.id)
	itemName.text = ResourceManager.get_item_name(itemConfig.id)
	amount.text = str(itemConfig.amount) 


func _on_button_button_down() -> void:
	emit_signal("slot_pressed", {
		"id": id,
		"itemName": itemName.text,
		"amount": int(amount.text),
	})
