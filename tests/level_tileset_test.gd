extends SceneTree

const BASELINE = Path.LEVEL_TILESET_BASELINE_FILE
const ROOMS = ["BaseRoom", "Corridor/C1", "Corridor/C2", "Corridor/C3", "End/E1", "Room/R4", "Room/R5", "Room/R6", "Start/S1"]

func _initialize() -> void:
	call_deferred("run_test")

func layer_signature(layer: TileMapLayer) -> String:
	var parts: PackedStringArray = [str(layer.transform), str(layer.tile_set.tile_size), str(layer.tile_map_data)]
	for cell in layer.get_used_cells():
		var source_id := layer.get_cell_source_id(cell)
		var coords := layer.get_cell_atlas_coords(cell)
		var alternative := layer.get_cell_alternative_tile(cell)
		assert(layer.tile_set.has_source(source_id))
		var atlas := layer.tile_set.get_source(source_id) as TileSetAtlasSource
		assert(atlas != null and atlas.has_tile(coords))
		var data := layer.get_cell_tile_data(cell)
		assert(data != null)
		parts.append(str([cell, source_id, coords, alternative, atlas.texture.resource_path, atlas.get_tile_texture_region(coords), data.texture_origin, data.modulate, data.flip_h, data.flip_v, data.transpose, data.z_index, data.y_sort_origin]))
	return "\n".join(parts).sha256_text()

func run_test() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	var expected: Dictionary = {}
	if not capture:
		expected = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	var signatures: Dictionary = {}
	var shared: TileSet = load(Path.LEVEL_TILE_SET_RESOURCE)
	for room_name in ROOMS:
		var room: Node2D = load(Path.ROOM_SCENE_PATTERN % room_name).instantiate()
		for node in room.find_children("*", "TileMapLayer", true, false):
			if node.tile_set == null:
				assert(node.get_used_cells().is_empty())
				continue
			var key: String = room_name + "/" + str(room.get_path_to(node))
			signatures[key] = layer_signature(node)
			if not capture:
				assert(node.tile_set == shared, "Not using shared TileSet: " + key)
				assert(expected[key] == signatures[key], "Appearance changed: " + key)
		room.free()
	if capture:
		var file := FileAccess.open(BASELINE, FileAccess.WRITE)
		file.store_string(JSON.stringify(signatures, "\t"))
	else:
		assert(expected.size() == signatures.size())
	print("PASS: all nine room scenes and %d TileMapLayers preserve tile graphics" % signatures.size())
	quit()
