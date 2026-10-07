extends CanvasLayer
## 关卡共享背景。世界坐标驱动视差，房间切换不重置纹理位置。

const BACKGROUND_SHADER = preload(Path.LEVEL_BACKGROUND_SHADER)
const OUTSIDE_MASK = preload(Path.LEVEL_OUTSIDE_MASK_SCRIPT)
## 列表顺序为由近及远，绘制时反向叠加。
@export var level_catalog: LevelCatalog = preload(Path.LEVEL_CATALOG_RESOURCE)

## 背景图片的等比尺寸倍率：1.0 为每张素材的原始尺寸，2.0 为两倍尺寸。
## 数值越大，洞穴结构越大；所有背景图层一起缩放。
@export_range(0.1, 8.0, 0.1, "or_greater") var texture_scale: float = 1.5
@export_range(0.0, 0.3, 0.01) var perspective_strength: float = 0.08
@export_range(0.0, 0.2, 0.01) var fog_strength: float = 0.035

var _layer_surfaces: Array[ColorRect] = []
var _material: ShaderMaterial
var _elapsed: float = 0.0
var _hidden_backgrounds: Array[Dictionary] = []
var _outside_mask: Control

func _ready() -> void:
	layer = -100
	var base := ColorRect.new()
	base.name = "BackgroundBase"
	base.color = Color("#0f070d")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var surface := ColorRect.new()
	surface.name = "BackgroundSurface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = BACKGROUND_SHADER
	_material.set_shader_parameter("effects_only", true)
	surface.material = _material
	add_child(surface)
	_outside_mask = OUTSIDE_MASK.new()
	_outside_mask.name = "OutsideRoomMask"
	add_child(_outside_mask)
	var generator := get_parent().get_node("LevelGenerator")
	generator.level_generated.connect(_on_level_generated)
	generator.level_clearing.connect(_restore_backgrounds)
	if generator.generation_succeeded:
		_on_level_generated()

func _process(delta: float) -> void:
	_elapsed += delta
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var materials: Array[ShaderMaterial] = [_material]
	for surface in _layer_surfaces:
		materials.append(surface.material as ShaderMaterial)
	for material in materials:
		_update_material(material, camera)

func _update_material(material: ShaderMaterial, camera: Camera2D) -> void:
	material.set_shader_parameter("camera_position", camera.get_screen_center_position())
	material.set_shader_parameter("camera_zoom", camera.zoom)
	material.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)
	material.set_shader_parameter("texture_scale", texture_scale)
	material.set_shader_parameter("perspective_strength", perspective_strength)
	material.set_shader_parameter("fog_strength", fog_strength)
	material.set_shader_parameter("elapsed", _elapsed)

func _on_level_generated() -> void:
	_restore_backgrounds()
	var generator_level = get_parent().get_node("LevelGenerator").get("generated_level")
	set_background_level(CurrentLevel.CurrentLevel if generator_level == null else int(generator_level))
	var generator := get_parent().get_node("LevelGenerator")
	for child in generator.get_children():
		var base_layer := child.get_node_or_null("BaseLayer") as TileMapLayer
		if base_layer != null and base_layer.tile_set != null:
			var cells := base_layer.get_used_rect()
			var tile_size := Vector2(base_layer.tile_set.tile_size)
			var bounds := Rect2(Vector2(cells.position) * tile_size, Vector2(cells.size) * tile_size)
			if bounds.has_area():
				_outside_mask.room_bounds.append(base_layer.global_transform * bounds)
		# 保留 BaseLayer、平台、门框以及碰撞，只替换独立的旧背景分组。
		for background_name in ["Background", "Backgroud", "MainCamera/background"]:
			var old := child.get_node_or_null(background_name) as CanvasItem
			if old != null:
				_hidden_backgrounds.append({"node": weakref(old), "visible": old.visible})
				old.hide()

## 从目录选择关卡，清除上一个关卡的图层；空列表保留基础填充色。
func set_background_level(level_index: int) -> void:
	var textures: Array[Texture2D] = []
	if level_catalog != null and level_index >= 0 and level_index < level_catalog.Log.size():
		var config := level_catalog.Log[level_index]
		if config != null and config.LevelInfor != null:
			for texture in config.LevelInfor.Background:
				if texture != null:
					textures.append(texture)
	set_background_textures(textures)

## 输入按由近及远排列；近层后绘制，透明区域显示后面的远层。
func set_background_textures(textures: Array[Texture2D]) -> void:
	for surface in _layer_surfaces:
		remove_child(surface)
		surface.queue_free()
	_layer_surfaces.clear()
	for index in range(textures.size() - 1, -1, -1):
		var surface := ColorRect.new()
		surface.name = "BackgroundLayer%d" % index
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var material := ShaderMaterial.new()
		material.shader = BACKGROUND_SHADER
		material.set_shader_parameter("background_texture", textures[index])
		var depth := 0.70 if textures.size() == 1 else lerpf(0.70, 0.08, float(index) / float(textures.size() - 1))
		material.set_shader_parameter("layer_depth", depth)
		surface.material = material
		add_child(surface)
		# 基础色之后、雾气和外侧遮罩之前，按远到近绘制。
		move_child(surface, 1 + _layer_surfaces.size())
		_layer_surfaces.append(surface)

func _restore_backgrounds() -> void:
	if is_instance_valid(_outside_mask):
		_outside_mask.room_bounds.clear()
		_outside_mask.queue_redraw()
	for entry in _hidden_backgrounds:
		var old = entry.node.get_ref()
		if is_instance_valid(old):
			old.visible = entry.visible
	_hidden_backgrounds.clear()

func _exit_tree() -> void:
	_restore_backgrounds()
