extends PanelContainer
class_name itemList


@onready var slot_resource:PackedScene = load("uid://bmtyh6pxk6pjt")
@onready var slot_VB = $MarginContainer/ScrollContainer/slot_VB

var item_list:Array

##修改物品列表
func modify_items_list(items: Array):
	item_list = items
	clear()
	refresh_display()

##刷新显示
func refresh_display():
	for item in item_list:
		var slot:itemListslot = slot_resource.instantiate()
		slot_VB.add_child(slot)
		slot.modify_item_display(item)

func clear():
	for item in slot_VB.get_children():
		item.queue_free()
