extends Node

func _ready() -> void:
	var editor = load("res://Scene/Map/Template/Template1.tscn").instantiate()
	editor.EnableDrawing = false
	add_child(editor)
	# 房间类型和显示颜色仅由导出字典决定。
	assert(editor.tile_set.get_custom_data_layers_count() == 0)
	editor.RoomTypes[Color.PURPLE] = "Treasure"
	editor._refresh_types()
	assert("Treasure" in editor.TYPES)
	assert(not editor._find_tile("Treasure").is_empty())
	editor.RoomTypes[Color.PINK] = "Treasure"
	assert(editor.TYPES.count("Treasure") == 1)
	editor.RoomTypes[Color.WHITE] = ""
	assert(not "" in editor.TYPES)
	editor.RoomTypes.erase(Color.PURPLE)
	editor.RoomTypes.erase(Color.PINK)
	editor.RoomTypes.erase(Color.WHITE)
	editor._refresh_types()
	var original_count: int = editor.get_used_cells().size()
	var path := "res://tests/template_roundtrip.tmp.json"
	assert(editor.save_level_template(path))
	var records: Array = editor.LevelPorperty.duplicate(true)
	editor.clear()
	assert(editor.load_level_template(path))
	assert(editor.get_used_cells().size() == original_count)
	assert(editor.save_level_template(path))
	assert(editor.LevelPorperty == records)
	# 旧模板兼容。
	assert(editor.load_level_template("res://Rescource/LevelTemplate/Level2"))
	# 非法文件不改变现有画布。
	var before: Array = editor.get_used_cells()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[[\"Start\",\"LEFT\",[],0]]")
	file.close()
	assert(not editor.load_level_template(path))
	assert(editor.get_used_cells() == before)
	# 环路被拒绝，文件不会被无效画布覆盖。
	editor.clear()
	var start: Array = editor._find_tile("Start")
	var room: Array = editor._find_tile("Room")
	editor.set_cell(Vector2i.ZERO, start[0], start[1], start[2])
	for cell in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		editor.set_cell(cell, room[0], room[1], room[2])
	assert(not editor.save_level_template(path))
	DirAccess.remove_absolute(path)
	print("TEMPLATE_EDITOR_TESTS_PASSED")
	get_tree().quit()

