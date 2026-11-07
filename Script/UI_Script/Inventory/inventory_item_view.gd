extends PanelContainer
## 物品纯展示组件；所有节点在 item_view.tscn 中声明。

## 将配置和实例副本绑定到图标、数量与提示，不修改物品数据。
func display(item: ItemInstance, config: ItemConfig) -> void:
	$Margin/Icon.texture = config.IconTexture
	$Quantity.text = str(item.quantity) if config.MaxStack > 1 else ""
	tooltip_text = "%s\n数量 %d · ID %d\n占位 %s%s" % [
		config.ItemName, item.quantity, item.instance_id, config.GridSize,
		" · 已旋转" if item.rotated else ""]

## 通过预设样式标记选中项，普通物品与拖拽预览复用同一场景。
func set_selected(selected: bool) -> void:
	$Selection.visible = selected
