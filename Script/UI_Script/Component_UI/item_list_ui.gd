extends PanelContainer
class_name itemList

signal list_slot_pressed

@onready var slot_resource:PackedScene = load("uid://bmtyh6pxk6pjt")
@onready var slot_VB = $MarginContainer/ScrollContainer/slot_VB

var item_list:Array
var hiding:bool

##修改物品列表
func modify_items_list(items: Array):
	item_list = items
	clear()
	refresh_display()

##刷新显示
func refresh_display():
	show()
	for item in item_list:
		var slot:itemListslot = slot_resource.instantiate()
		slot_VB.add_child(slot)
		if slot.has_signal("slot_pressed"):
			slot.slot_pressed.connect(_on_slot_pressed)
		slot.modify_item_display(item)

	if item_list.is_empty() && hiding:
		hide()

func clear():
	for item in slot_VB.get_children():
		item.queue_free()

func _on_slot_pressed(itemConfig:Dictionary):
	list_slot_pressed.emit(itemConfig)

func hide_when_empty(varient: bool):
	hiding = varient
