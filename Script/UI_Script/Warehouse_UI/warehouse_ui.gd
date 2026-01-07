extends BaseUI
class_name warehouseUI

@onready var item_selector_ui:itemSelector = $VBoxContainer/item_selector_ui
@onready var item_list_ui: itemList = $VBoxContainer/item_list_ui
@onready var discription_ui:discriptionUI = $discription_ui
@onready var warehouse:Array[Dictionary] = WarehouseSystem.get_warehouse()


func _ready() -> void:
	super.begin()
	connect("visibility_changed", _on_self_visibility_changed)
	EventBus.slot_pressed.connect(_on_slot_pressed)
	EventBus.selector_button_pressed.connect(_on_selector_button_pressed)
	WarehouseSystem.warehouse_changed.connect(refresh_display)
	
	refresh_display()
	discription_ui.hide()

func refresh_display():
	var displayed_items = item_selector_ui.selector(warehouse)
	item_list_ui.modify_items_list(displayed_items)

func _on_self_visibility_changed() -> void:
	if visible:
		print("connect signal now")
		EventBus.slot_pressed.connect(_on_slot_pressed)
		EventBus.selector_button_pressed.connect(_on_selector_button_pressed)
	else:
		print("disconnect signal now")
		EventBus.slot_pressed.disconnect(_on_slot_pressed)
		EventBus.selector_button_pressed.disconnect(_on_selector_button_pressed)
		discription_ui.hide()


func _on_slot_pressed(item:Dictionary):
	discription_ui.modify_displayed_information(item)
	discription_ui.show()

func _on_selector_button_pressed(type:ENUM.ItemType):
	refresh_display()
