extends BaseUI
class_name warehouseUI

@onready var item_selector_ui:itemSelector = $VBoxContainer/item_selector_ui
@onready var item_list_ui: itemList = $VBoxContainer/item_list_ui
@onready var discription_ui:discriptionUI = $DesriptionContainer/discription_ui
@onready var warehouse:Array[Dictionary] = WarehouseSystem.get_warehouse()


func _ready() -> void:
	super.begin()
	connect("visibility_changed", _on_self_visibility_changed)
	WarehouseSystem.warehouse_changed.connect(refresh_display)
	
	refresh_display()
	discription_ui.hide()


func refresh_display():
	var displayed_items = item_selector_ui.selector(warehouse)
	item_list_ui.modify_items_list(displayed_items)


func _on_self_visibility_changed() -> void:
	if !visible:
		discription_ui.hide()


func _on_item_list_ui_list_slot_pressed(item:Dictionary) -> void:
	discription_ui.modify_displayed_information(item)
	discription_ui.show()


func _on_item_selector_ui_selector_button_pressed(type:ENUM.ItemType) -> void:
	refresh_display()


func _on_item_list_ui_gui_input(event: InputEvent) -> void:
	if event.as_text() == "Left Mouse Button" && event.is_pressed():
		var tmp_slot = UIManager.tmp_slot.get_tmp_item()
		if WarehouseSystem.add_item_to_warehouse(tmp_slot.x, tmp_slot.y):
			UIManager.tmp_slot.set_tmp_item(-1, 0)
			UIManager.tmp_slot.refresh()
