extends "res://Script/UI_Script/Inventory/inventory_gameplay_lab.gd"
## 仓库正式接入测试台，沿用真实 Hero、掉落按钮与既有角色输入。

## 测试台明确开始新会话时同时重置家园仓库；普通关闭和切关不调用。
func _on_reset_pressed() -> void:
	super._on_reset_pressed()
	var result := PlayerInventorySession.start_new($HomeWarehouse.definition, InventoryManager)
	status.text = "背包、装备与仓库已重置" if result.is_ok() else result.message
