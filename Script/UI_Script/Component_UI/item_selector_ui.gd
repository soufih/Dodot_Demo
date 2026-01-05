extends PanelContainer
class_name itemSelector

var resistence:ENUM.ItemType = ENUM.ItemType.None

func _on_button_button_down() -> void:
	resistence = ENUM.ItemType.None
	EventBus.emit_signal("selector_button_pressed", ENUM.ItemType.None)


func _on_button_2_button_down() -> void:
	resistence = ENUM.ItemType.Weapon
	EventBus.emit_signal("selector_button_pressed", ENUM.ItemType.Weapon)


func _on_button_3_button_down() -> void:
	resistence = ENUM.ItemType.Materials
	EventBus.emit_signal("selector_button_pressed", ENUM.ItemType.Materials)


func _on_button_4_button_down() -> void:
	resistence = ENUM.ItemType.Relic
	EventBus.emit_signal("selector_button_pressed", ENUM.ItemType.Relic)


func _on_button_5_button_down() -> void:
	resistence = ENUM.ItemType.Equipment
	EventBus.emit_signal("selector_button_pressed", ENUM.ItemType.Equipment)

##重置筛选器
func _on_visibility_changed() -> void:
	if !visible:
		resistence = ENUM.ItemType.None

##筛选物品
func selector(items:Array[Dictionary])->Array:
	if resistence == ENUM.ItemType.None:
		return items
	var selected_items:Array
	for item in items:
		if ResourceManager.get_item_main_item_type(item.id) == resistence:
			selected_items.append(item)

	return selected_items
