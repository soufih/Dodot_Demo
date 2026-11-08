extends Control
## 角色武器 HUD；读取装备组件的当前选择，所有控件仍来自原有场景。

@export var equipment: PlayerEquipmentComponent

@onready var current_item_container = $current_item_container
@onready var next_item_container = $next_item_container
@onready var current_item = $current_item_container/current_item
@onready var next_item = $next_item_container/next_item
var completed:bool = true
var is_banned:bool = false

## 同时监听装备内容和当前使用武器变化，空槽会清除旧图标。
func _ready() -> void:
	SignalBus.weapon_switch.connect(_on_weapon_switch)
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_slot_changed)
		equipment.weapon_changed.connect(_on_equipment_slot_changed)
	refresh_display()


## 解除本角色订阅，不清空跨场景保留的装备数据。
func _exit_tree() -> void:
	if is_instance_valid(equipment):
		equipment.equipment_changed.disconnect(_on_equipment_slot_changed)
		equipment.weapon_changed.disconnect(_on_equipment_slot_changed)


## 保留现有切换动画；实际武器选择已由状态机交给装备组件处理。
func _on_weapon_switch() -> void:
	if completed and equipment != null and equipment.get_next_weapon() != -1:
		switch_item()


## 数据提交或选择变化后重读图标，避免维护额外的武器列表。
func _on_equipment_slot_changed():
	refresh_display()


## 根据当前与备用槽位更新已有 TextureRect。
func refresh_display():
	var weapon_id = equipment.get_current_weapon() if equipment != null else -1
	current_item.texture = ResourceManager.get_item_icon(weapon_id)
	var next_id = equipment.get_next_weapon() if equipment != null else -1
	next_item.texture = ResourceManager.get_item_icon(next_id)

## 动画结束时重新读取真实选择，动画期间再次换装也不会恢复过期图标。
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
		refresh_display()

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
