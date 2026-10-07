extends Control

@onready var current_item_container = $current_item_container
@onready var next_item_container = $next_item_container
@onready var current_item = $current_item_container/current_item
@onready var next_item = $next_item_container/next_item
var completed:bool = true
var is_banned:bool = false

func _ready() -> void:
	SignalBus.weapon_switch.connect(_on_weapon_switch)
	EquipmentSlotSystem.equipment_slot_changed.connect(_on_equipment_slot_changed)
	refresh_display()


func _exit_tree() -> void:
	EquipmentSlotSystem.equipment_slot_changed.disconnect(_on_equipment_slot_changed)


func _on_weapon_switch() -> void:
	if completed && EquipmentSlotSystem.get_next_weapon() != -1:
		switch_item()


func _on_equipment_slot_changed():
	refresh_display()


func refresh_display():
	var weapon_id = EquipmentSlotSystem.get_current_weapon()
	current_item.texture = ResourceManager.get_item_icon(weapon_id)
	var next_id = EquipmentSlotSystem.get_next_weapon()
	next_item.texture = ResourceManager.get_item_icon(next_id)

func switch_item():
	completed = false
	var tween:Tween = create_tween()

	#记录当前武器容器状态
	var original_position = current_item_container.global_position
	var original_size = current_item_container.size
	var original_modulate = current_item_container.modulate

	#记录下一个武器容器状态
	var next_original_position = next_item_container.global_position
	var next_original_size = next_item_container.size
	var next_original_modulate = next_item_container.modulate

	#当前武器容器同时向左移动放大淡出
	tween.tween_property(current_item_container, "global_position:x", 0, 0.1)
	tween.set_parallel()
	tween.tween_property(current_item_container, "size", Vector2(90, 90), 0.1)
	tween.set_parallel()
	tween.tween_property(current_item_container, "modulate:a", 0, 0.1)

	#下一个武器向左移动至当前武器的武器并放大
	tween.tween_property(next_item_container, "global_position:x", original_position.x, 0.25)
	tween.set_parallel()
	tween.tween_property(next_item_container, "size", original_size, 0.25)
	tween.set_parallel()

	#交换当前武器和下一个武器
	tween.tween_callback((func() -> void:
		var temp = current_item.texture
		current_item.texture = next_item.texture
		next_item.texture = temp

		#恢复当前武器容器到初始状态
		current_item_container.global_position = original_position
		current_item_container.size = original_size
		current_item_container.modulate.a = original_modulate.a

		#将下一个武器容器移出屏幕右侧并缩小透明
		next_item_container.global_position = next_original_position
		next_item_container.size = next_original_size
		next_item_container.modulate.a = 1
		)
	).set_delay(0.25)

	tween.tween_callback(func():
		completed = true
		).set_delay(0.25)
