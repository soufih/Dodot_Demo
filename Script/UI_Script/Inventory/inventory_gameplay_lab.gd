extends Node2D
## 可直接运行的正式接入测试台：真实玩家、掉落工厂、交互与 UIManager。

@onready var inventory: PlayerInventoryComponent = $Hero/Inventory
@onready var status: Label = $HUD/Panel/Margin/Rows/Status

## 场景只负责测试布置，正式背包沿用角色会话组件和全局 Manager。
func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().size = Vector2i(1440, 900)
	UIManager.configure_scene(self, [UIId.INVENTORY, UIId.PAUSE, UIId.SETTINGS, UIId.DEATH, UIId.END])
	DataLoader.set_hero($Hero)
	inventory.items_received.connect(_on_received)
	await get_tree().process_frame
	_spawn(21, 250)
	status.text = "已生成 250 份材料，靠近光点按 E 拾取，Tab 打开背包。"

## 测试台销毁时仅清理角色引用，容器生命周期仍归会话所有。
func _exit_tree() -> void:
	if DataLoader.get_hero() == $Hero:
		DataLoader.set_hero(null)

## 生成真实掉落场景；测试台固定掉落位置，便于重复验证拾取与满包。
func _spawn(config_id: int, quantity: int) -> void:
	var dropped: DroppedItem = $Hero/DropComponent.create_dropped_item(
		[{"id": config_id, "amount": quantity}], $Hero.global_position + Vector2(22, 0))
	dropped.freeze = true
	dropped.linear_velocity = Vector2.ZERO

## 材料超过 MaxStack，可验证自动分成多栈及满包余量保留。
func _on_material_pressed() -> void:
	_spawn(21, 250)
	status.text = "已生成材料 × 250"

## 正式武器配置带多格尺寸，可验证摆放及拖动时按 R 旋转。
func _on_sword_pressed() -> void:
	_spawn(10, 1)
	status.text = "已生成长剑 × 1"

## 第二把单手武器用于验证副武器穿戴与 Q 键切换。
func _on_secondary_pressed() -> void:
	_spawn(11, 1)
	status.text = "已生成备用武器 × 1"

## 双手弓用于验证主武器与副武器的双向互斥。
func _on_two_hand_pressed() -> void:
	_spawn(15, 1)
	status.text = "已生成双手弓 × 1；穿戴前需要卸下副武器。"

## 使用现有 UIManager 开关正式背包，不实例化测试台专用背包窗口。
func _on_inventory_pressed() -> void:
	inventory.toggle_inventory()

## 显式新会话用于重复测试；关闭旧视图，恢复背包和装备的初始配置并清理测试掉落。
func _on_reset_pressed() -> void:
	UIManager.close(UIId.INVENTORY)
	var result := inventory.start_new()
	for child in get_children():
		if child is DroppedItem:
			child.queue_free()
	status.text = "背包与装备已重置" if result.is_ok() else result.message

## 拾取反馈显示实际入包数量，部分成功时同时说明剩余物品未入包。
func _on_received(result: InventoryResult) -> void:
	status.text = "已入包 %d 件" % result.payload if result.is_ok() else result.message
	if result.is_ok() and not result.message.is_empty():
		status.text += " · " + result.message
