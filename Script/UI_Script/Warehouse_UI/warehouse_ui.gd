extends BaseUI
class_name warehouseUI

@onready var item_selector_ui:itemSelector = $warehouse_hbox_contaniner/warehouse_vbox_contaniner/item_selector_ui
@onready var item_list_ui: itemList = $warehouse_hbox_contaniner/warehouse_vbox_contaniner/item_list_ui
@onready var discription_ui:discriptionUI = $disription_container/discription_ui
@onready var disription_container:PanelContainer = $disription_container
@onready var warehouse:Array[Dictionary] = WarehouseSystem.get_warehouse()


func _ready() -> void:
	super.begin()
	WarehouseSystem.warehouse_changed.connect(refresh_display)
	refresh_display()


func refresh_display():
	var displayed_items = item_selector_ui.selector(warehouse)
	item_list_ui.modify_items_list(displayed_items)

##仓库界面接受到输入时
func _on_item_list_ui_gui_input(event: InputEvent) -> void:
	if event.as_text() == "Left Mouse Button" && event.is_pressed():
		add_item()

##物品槽被按下时
func _on_item_list_ui_list_slot_pressed(item:Dictionary) -> void:
	if exchange_item(item):
		return
	if add_item():
		return
	remove_item(item)

func exchange_item(item:Dictionary)->bool:
	var tmp_slot = UIManager.tmp_slot.get_tmp_item()
	if tmp_slot.x == -1:
		return false
	add_item()
	remove_item(item)

	return true

##从仓库中移出物品
func remove_item(item:Dictionary)->bool:
	var tmp_slot = UIManager.tmp_slot.get_tmp_item()
	if tmp_slot.x != -1:
		return false
	var max_stack = ResourceManager.get_item_max_stack(item.id)
	var got = min(WarehouseSystem.get_item_amount(item.id), max_stack)
	if WarehouseSystem.remove_item_from_warehouse(item.id, got):
		UIManager.tmp_slot.set_tmp_item(item.id, got)
		UIManager.tmp_slot.refresh()
	return true

##向仓库中添加物品
func add_item()->bool:
	var tmp_slot = UIManager.tmp_slot.get_tmp_item()
	if tmp_slot.x == -1:
		return false
	if WarehouseSystem.add_item_to_warehouse(tmp_slot.x, tmp_slot.y):
		UIManager.tmp_slot.set_tmp_item(-1, 0)
		UIManager.tmp_slot.refresh()
	return true

func _on_item_selector_ui_selector_button_pressed(type:ENUM.ItemType) -> void:
	refresh_display()


func _on_item_list_ui_list_slot_mouse_enter(item:Dictionary) -> void:
	discription_ui.modify_displayed_information(item)


func _on_item_list_ui_list_slot_gui_input() -> void:
	var mouse_pos:Vector2 = get_global_mouse_position()
	disription_container.global_position = Vector2(mouse_pos.x-260, mouse_pos.y)
	discription_ui.show()


func _on_item_list_ui_list_slot_mouse_exit() -> void:
	discription_ui.hide()
