extends PanelContainer
class_name itemList

signal list_slot_pressed
signal list_slot_mouse_enter
signal list_slot_mouse_exit
signal list_slot_gui_input

@onready var slot_resource:PackedScene = load(Path.ITEM_LIST_SLOT_SCENE)
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

		#连接物品框信号
		slot.slot_pressed.connect(_on_slot_pressed)
		slot.slot_mouse_entered.connect(_on_mouse_enter_slot)
		slot.slot_mouse_exited.connect(_on_mouse_exit_slot)
		slot.slot_gui_input.connect(_on_slot_gui_input)

		slot.modify_item_display(item)

	if item_list.is_empty() && hiding:
		hide()

func clear():
	for item in slot_VB.get_children():
		item.queue_free()

##处理物品框被点击的信号
func _on_slot_pressed(itemConfig:Dictionary):
	list_slot_pressed.emit(itemConfig)

##处理鼠标进入物品框的信号
func _on_mouse_enter_slot(itemConfig:Dictionary):
	list_slot_mouse_enter.emit(itemConfig)

func _on_mouse_exit_slot():
	list_slot_mouse_exit.emit()

func _on_slot_gui_input():
	list_slot_gui_input.emit()

func hide_when_empty(varient: bool):
	hiding = varient
