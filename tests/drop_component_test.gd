extends Node

func _ready() -> void:
	var character := Node2D.new()
	character.position = Vector2(120, 80)
	add_child(character)
	var component := DropComponent.new()
	component.position = Vector2(5, -10)
	component.show_pickup_mentions = true
	character.add_child(component)
	assert(DebugTool.get_service(&"dropped_items") == component)
	var drop_parent: Node = get_tree().current_scene
	if drop_parent == null:
		drop_parent = get_tree().root
	var before := drop_parent.get_child_count()
	component.drop()
	assert(drop_parent.get_child_count() == before)

	var guaranteed := droppedItemConfig.new()
	guaranteed.id = 20
	guaranteed.range_x = 3
	guaranteed.range_y = 3
	guaranteed.possbility = 100.0
	var excluded := droppedItemConfig.new()
	excluded.id = 23
	excluded.range_x = 1
	excluded.range_y = 1
	excluded.possbility = 0.0
	component.items = [guaranteed, excluded]
	component.drop()
	assert(drop_parent.get_child_count() == before + 1)
	var dropped := drop_parent.get_child(before) as DroppedItem
	assert(dropped != null)
	assert(dropped.global_position == component.global_position)
	assert(dropped.get_items() == [{"id": 20, "amount": 3}])
	var hint_count := UIManager.UILayer.get_child_count()
	SignalBus.items_picked_up.emit({"id": 20, "amount": 3})
	SignalBus.items_picked_up.emit({"id": 23, "amount": 1})
	assert(UIManager.UILayer.get_child_count() == hint_count + 1)
	var first_hint: Node = UIManager.UILayer.get_child(hint_count)
	await get_tree().create_timer(1.3).timeout
	assert(UIManager.UILayer.get_child_count() == hint_count + 2)
	var second_hint: Node = UIManager.UILayer.get_child(hint_count + 1)
	first_hint.free()
	second_hint.free()
	character.free()
	assert(DebugTool.get_service(&"dropped_items") == null)
	assert(is_instance_valid(dropped))
	assert(dropped.get_parent() == drop_parent)
	dropped.free()
	print("drop_component_test: PASS")
	get_tree().quit()
