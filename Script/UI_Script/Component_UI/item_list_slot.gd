extends PanelContainer
class_name itemListslot

@onready var icon:TextureRect = $MarginContainer/HBoxContainer/item_icon
@onready var itemName: Label = $MarginContainer/HBoxContainer/item_name
@onready var amount: Label = $MarginContainer/HBoxContainer/item_amount

var id: int


func modify_item_display(itemConfig:Dictionary):
	id = itemConfig.id
	icon.texture = ResourceManager.get_item_icon(itemConfig.id)
	itemName.text = ResourceManager.get_item_name(itemConfig.id)
	amount.text = str(itemConfig.amount) 


func _on_button_button_down() -> void:
	EventBus.emit_signal("slot_pressed", {
		"id": id,
		"itemName": itemName.text,
		"amount": amount.text,
	})
