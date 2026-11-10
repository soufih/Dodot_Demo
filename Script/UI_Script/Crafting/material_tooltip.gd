extends PanelContainer
## 只负责显示传入的数据；可在独立场景中调整布局、字体、颜色与边距。

func set_material_info(data: Dictionary) -> void:
	$Margin/Content/Header/Icon.texture = data.icon
	$Margin/Content/Header/MaterialName.text = data.name if not data.name.is_empty() else "材料"
	$Margin/Content/Description.text = data.description
	$Margin/Content/Description.visible = not data.description.is_empty()
	$Margin/Content/Owned.text = "仓库拥有：%d" % data.owned
	$Margin/Content/Required.text = "本次需要：%d" % data.required
	$Margin/Content/Missing.text = "缺少：%d" % data.missing
	$Margin/Content/Missing.modulate = Color("f18d86") if data.missing > 0 else Color("bde1ba")
	$Margin/Content/Navigation.visible = data.has_recipe
