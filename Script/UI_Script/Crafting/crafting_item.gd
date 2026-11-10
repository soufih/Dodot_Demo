extends PanelContainer
## 卡片提供悬浮信息，由 Godot 管理独立提示场景的显示、定位和释放。

@export var material_tooltip_scene: PackedScene
var _material_info: Dictionary = {}

func configure_material_tooltip(material: Dictionary, has_recipe: bool) -> void:
	_material_info = {
		"name": ResourceManager.get_item_name(material.config_id).strip_edges(),
		"description": ResourceManager.get_item_discription(material.config_id).strip_edges(),
		"icon": ResourceManager.get_item_icon(material.config_id),
		"owned": material.owned, "required": material.required, "missing": material.missing,
		"has_recipe": has_recipe,
	}
	# 原生悬浮系统需要非空文本才会调用自定义提示工厂，实际内容由场景渲染。
	tooltip_text = "材料详情"

func _make_custom_tooltip(_for_text: String) -> Object:
	if _material_info.is_empty() or material_tooltip_scene == null:
		return null
	var tooltip = material_tooltip_scene.instantiate()
	tooltip.set_material_info(_material_info)
	return tooltip
