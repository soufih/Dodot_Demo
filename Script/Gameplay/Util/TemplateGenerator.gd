extends TileMapLayer

@export var Level: String
@export_file var TemplatePath: String = ""
@export var EnableDrawing: bool = true
@export var Brush: String = "Room"
## 键为绘制颜色，值为房间类型；同一类型有多个颜色时使用第一项。
@export var RoomTypes: Dictionary[Color, String] = {
	Color.GREEN: "Start",
	Color.DODGER_BLUE: "Room",
	Color.YELLOW: "Corridor",
	Color.RED: "End",
}
var LevelPorperty: Array = []
var _status: Label
var TYPES: Array:
	get:
		return _type_colors().keys()
var _brushes: HBoxContainer
var _displayed_types: Array = []
var _colors_snapshot: Dictionary = {}
var _palette: Dictionary = {}
const DIRECTIONS = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const ENTRANCES = ["LEFT", "TOP", "RIGHT", "BOTTOM"]
const EXIT_DIRECTIONS = [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 8.0
const ZOOM_STEP: float = 1.2

func _ready() -> void:
	_refresh_types()
	if Engine.is_editor_hint() or not EnableDrawing:
		return
	position += Vector2(320, 240)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.position = Vector2(12, 12)
	canvas.add_child(panel)
	var brushes := HBoxContainer.new()
	_brushes = brushes
	panel.add_child(brushes)
	var path_edit := LineEdit.new()
	path_edit.custom_minimum_size.x = 420
	path_edit.text = _path("")
	path_edit.text_changed.connect(func(value: String): TemplatePath = value)
	panel.add_child(path_edit)
	_refresh_types(true)
	var save_button := Button.new()
	save_button.text = "保存 (Ctrl+S)"
	save_button.pressed.connect(save_level_template)
	panel.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "读取 (Ctrl+O)"
	load_button.pressed.connect(load_level_template)
	panel.add_child(load_button)
	_status = Label.new()
	panel.add_child(_status)
	_report("左键绘制 / 右键擦除；数字键按按钮顺序选类型（最多9种）；中键拖动；滚轮缩放")
	queue_redraw()

func _process(_delta: float) -> void:
	if RoomTypes != _colors_snapshot:
		_refresh_types(true)

func _draw() -> void:
	if Engine.is_editor_hint() or not EnableDrawing or tile_set == null:
		return
	var cell_size := Vector2(tile_set.tile_size)
	var color := Color(0.6, 0.6, 0.6, 0.2)
	for i in range(-64, 65):
		draw_line(Vector2(i * cell_size.x, -64 * cell_size.y), Vector2(i * cell_size.x, 64 * cell_size.y), color)
		draw_line(Vector2(-64 * cell_size.x, i * cell_size.y), Vector2(64 * cell_size.x, i * cell_size.y), color)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not EnableDrawing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_S:
			save_level_template()
		elif event.ctrl_pressed and event.keycode == KEY_O:
			load_level_template()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var types := TYPES
			var index: int = event.keycode - KEY_1
			if index >= types.size():
				return
			Brush = types[index]
			_report("画笔：" + Brush)
		else:
			return
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		position += event.relative
		return
	if event is InputEventMouseButton and not event.pressed:
		return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var factor: float = ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
		zoom_at(event.position, factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		var cell := local_to_map(get_local_mouse_position())
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			erase_cell(cell)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var tile := _find_tile(Brush)
			if not tile.is_empty():
				set_cell(cell, tile[0], tile[1], tile[2])

## 保持鼠标下的画布坐标不变；界面位于独立 CanvasLayer，不随画布缩放。
func zoom_at(viewport_position: Vector2, factor: float) -> void:
	var local_anchor := get_global_transform_with_canvas().affine_inverse() * viewport_position
	var parent_anchor := transform * local_anchor
	var zoom := clampf(scale.x * factor, MIN_ZOOM, MAX_ZOOM)
	scale *= zoom / scale.x
	position += parent_anchor - transform * local_anchor

func _path(path: String) -> String:
	if not path.is_empty():
		return path
	if not TemplatePath.is_empty():
		return TemplatePath
	return "res://Rescource/LevelTemplate/" + str(name) + Level

func _report(message: String) -> void:
	if is_instance_valid(_status):
		_status.text = message
	print(message)

func _refresh_types(force: bool = false) -> void:
	if RoomTypes != _colors_snapshot or tile_set == null:
		_rebuild_color_tiles()
	var types := TYPES
	if not Brush in types:
		Brush = "" if types.is_empty() else str(types[0])
	if not force and types == _displayed_types:
		return
	_displayed_types = types
	notify_property_list_changed()
	if not is_instance_valid(_brushes):
		return
	for child in _brushes.get_children():
		_brushes.remove_child(child)
		child.queue_free()
	for i in range(types.size()):
		var type: String = types[i]
		var button := Button.new()
		button.text = (str(i + 1) + ": " if i < 9 else "") + type
		button.add_theme_color_override("font_color", _type_colors()[type])
		button.pressed.connect(func(): Brush = type; _report("画笔：" + type))
		_brushes.add_child(button)

func _validate_property(property: Dictionary) -> void:
	if property.name == "Brush":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(TYPES)

func _find_tile(type: String) -> Array:
	if RoomTypes != _colors_snapshot:
		_refresh_types(true)
	return _palette.get(type, [])

func _type_colors() -> Dictionary:
	var colors: Dictionary = {}
	for color: Color in RoomTypes:
		var type: String = RoomTypes[color]
		if not type.strip_edges().is_empty() and not colors.has(type):
			colors[type] = color
	return colors

func _cell_type(cell: Vector2i) -> String:
	var tile := [get_cell_source_id(cell), get_cell_atlas_coords(cell), get_cell_alternative_tile(cell)]
	for type in _palette:
		if _palette[type] == tile:
			return type
	return ""

## 自动生成纯色图集；TileSet 仅负责显示，不承担房间类型配置。
func _rebuild_color_tiles() -> void:
	var previous: Dictionary = {}
	for cell in get_used_cells():
		previous[cell] = _cell_type(cell)
	var first_build := _palette.is_empty() and _colors_snapshot.is_empty()
	var colors := _type_colors()
	var types := colors.keys()
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture_region_size = tiles.tile_size
	var image := Image.create(maxi(types.size(), 1) * 16, 16, false, Image.FORMAT_RGBA8)
	for i in range(types.size()):
		image.fill_rect(Rect2i(i * 16, 0, 16, 16), colors[types[i]])
	atlas.texture = ImageTexture.create_from_image(image)
	_palette.clear()
	for i in range(types.size()):
		atlas.create_tile(Vector2i(i, 0))
		_palette[types[i]] = [0, Vector2i(i, 0), 0]
	tiles.add_source(atlas, 0)
	# 首次兼容旧场景的四个图集位置，不读取旧 RoomType 属性。
	if first_build:
		var legacy := ["Start", "Room", "Corridor", "End"]
		for cell in previous:
			var coords := get_cell_atlas_coords(cell)
			if get_cell_source_id(cell) == 0 and coords.y == 0 and coords.x >= 0 and coords.x < legacy.size():
				previous[cell] = legacy[coords.x]
	clear()
	tile_set = tiles
	for cell in previous:
		var tile: Array = _palette.get(previous[cell], [])
		if not tile.is_empty():
			set_cell(cell, tile[0], tile[1], tile[2])
	_colors_snapshot = RoomTypes.duplicate()
	queue_redraw()

func save_level_template(path: String = "") -> bool:
	_refresh_types()
	if TYPES.is_empty():
		_report("保存失败：颜色字典中没有有效的房间类型。")
		return false
	var cells := get_used_cells()
	var starts: Array[Vector2i] = []
	for cell in cells:
		var type := _cell_type(cell)
		if not type in TYPES:
			_report("保存失败：存在未知房间类型。")
			return false
		if type == "Start":
			starts.append(cell)
	if starts.size() != 1:
		_report("保存失败：必须且只能有一个 Start。")
		return false
	var records: Array = []
	var visited: Dictionary = {}
	if not _visit(starts[0], starts[0], "LEFT", 0, visited, records) or visited.size() != cells.size():
		_report("保存失败：模板含环路、断开区域或 End 后的房间。")
		return false
	# 原格式以起点为原点；验证重建结果，拒绝无法表达的相邻关系。
	if _decode(records).is_empty():
		_report("保存失败：房间连接无法转换为模板。")
		return false
	var destination := _path(path)
	var error := DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if error != OK:
		_report("保存失败：无法创建目录。")
		return false
	var file := FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		_report("保存失败：无法写入 " + destination)
		return false
	file.store_line(JSON.stringify(records))
	file.flush()
	if file.get_error() != OK:
		_report("保存失败：写入错误。")
		return false
	LevelPorperty = records
	_report("已保存：" + destination)
	return true

func _visit(cell: Vector2i, parent: Vector2i, entrance: String, depth: int,
		visited: Dictionary, records: Array) -> bool:
	if visited.has(cell):
		return false
	visited[cell] = true
	var exits: Array[bool] = [false, false, false, false]
	for i in range(4):
		var next: Vector2i = cell + EXIT_DIRECTIONS[i]
		exits[i] = next != parent and get_cell_source_id(next) != -1
	var type := _cell_type(cell)
	if type == "End" and exits.has(true):
		return false
	records.append([type, entrance, exits, depth])
	for i in range(4):
		var next: Vector2i = cell + DIRECTIONS[i]
		if next != parent and get_cell_source_id(next) != -1:
			if not _visit(next, cell, ENTRANCES[i], depth + 1, visited, records):
				return false
	return true

## 兼容原来的深度优先数组格式，重复深度代表返回之前的分支。
func _decode(records: Array) -> Dictionary:
	var layout: Dictionary = {}
	var stack: Array[Vector2i] = []
	var rows: Dictionary = {}
	for record in records:
		if not record is Array or record.size() != 4:
			return {}
		if not record[0] in TYPES or not record[1] in ENTRANCES:
			return {}
		if not record[2] is Array or record[2].size() != 4:
			return {}
		for flag in record[2]:
			if not flag is bool:
				return {}
		if not (record[3] is int or record[3] is float):
			return {}
		var depth := int(record[3])
		if depth != record[3] or depth < 0 or depth > stack.size():
			return {}
		var cell := Vector2i.ZERO
		if layout.is_empty():
			if depth != 0 or record[0] != "Start":
				return {}
		else:
			if depth == 0 or record[0] == "Start":
				return {}
			cell = stack[depth - 1] + DIRECTIONS[ENTRANCES.find(record[1])]
		if layout.has(cell):
			return {}
		stack.resize(depth)
		stack.append(cell)
		layout[cell] = record[0]
		rows[cell] = record
	# 检查出口与还原后的相邻格一致，避免载入后静默改变连接。
	for cell: Vector2i in rows:
		var record: Array = rows[cell]
		var parent: Vector2i = cell - DIRECTIONS[ENTRANCES.find(record[1])]
		for i in range(4):
			var next: Vector2i = cell + EXIT_DIRECTIONS[i]
			var expected: bool = layout.has(next) and (record[3] == 0 or next != parent)
			if record[2][i] != expected or (record[0] == "End" and expected):
				return {}
	return layout

func load_level_template(path: String = "") -> bool:
	_refresh_types()
	var source := _path(path)
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		_report("读取失败：无法打开 " + source)
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Array:
		_report("读取失败：无效 JSON 模板。")
		return false
	var layout := _decode(json.data)
	if layout.is_empty():
		_report("读取失败：模板结构或连接不合法。")
		return false
	var palette: Dictionary = {}
	for type in layout.values():
		palette[type] = _find_tile(type)
		if palette[type].is_empty():
			_report("读取失败：颜色字典缺少类型 " + str(type))
			return false
	# 完整验证后再替换，失败保留原画布。
	clear()
	for cell: Vector2i in layout:
		var tile: Array = palette[layout[cell]]
		set_cell(cell, tile[0], tile[1], tile[2])
	LevelPorperty = json.data
	_report("已读取：" + source)
	return true
