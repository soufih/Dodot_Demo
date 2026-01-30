extends PanelContainer
class_name itemListslot

signal slot_pressed
signal slot_mouse_entered
signal slot_mouse_exited
signal slot_gui_input

@onready var icon:TextureRect = $MarginContainer/item_icon
@onready var itemName: Label = $MarginContainer/HBoxContainer/item_name
@onready var amount: Label = $MarginContainer/HBoxContainer/item_amount

var id: int

##修改物品属性
func modify_item_display(itemConfig:Dictionary):
	id = itemConfig.id
	icon.texture = ResourceManager.get_item_icon(itemConfig.id)
	itemName.text = ResourceManager.get_item_name(itemConfig.id)

	amount.text = str(itemConfig.amount)

	if !icon.texture:
		icon.hide()
	if !itemName.text:
		itemName.hide()
	if !amount.text:
		amount.hide()

##物品框被点击时释放
func _on_button_button_down() -> void:
	emit_signal("slot_pressed", {
		"id": id,
		"itemName": itemName.text,
		"amount": int(amount.text),
	})

##鼠标进入物品框时释放
func _on_mouse_entered() -> void:
	emit_signal("slot_mouse_entered", {
		"id": id,
		"itemName": itemName.text,
		"amount": int(amount.text),
	})

##鼠标离开物品框时释放
func _on_mouse_exited() -> void:
	emit_signal("slot_mouse_exited")


func _on_gui_input(event: InputEvent) -> void:
	emit_signal("slot_gui_input")
