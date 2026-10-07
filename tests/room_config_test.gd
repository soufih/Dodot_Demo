extends Node

const Generator = preload(Path.LEVEL_GENERATOR_V1_SCRIPT)
const GeneratorV2 = preload(Path.LEVEL_GENERATOR_V2_SCRIPT)

func _ready() -> void:
	var config := RoomConfig.new()
	config.RoomType = ENUM.Type.Corridor
	config.Entrance = ENUM.Location.LEFT
	config.Exit = [ENUM.Location.BOTTOM, ENUM.Location.RIGHT]
	var generator := Generator.new()
	generator.auto_generate = false
	assert(generator.check_room(config, ["Corridor", "LEFT", [false, false, true, true], 1]))
	assert(not generator.check_room(config, ["Corridor", "LEFT", [false, true, true, false], 1]))
	config.Exit = []
	assert(generator.check_room(config, ["Corridor", "LEFT", [false, false, false, false], 1]))
	generator.prepare_generating()
	var rooms := generator.get_level_rooms(0)
	assert(rooms != null)
	assert(rooms.RoomLog.size() == 12)
	assert(generator.get_level_rooms(-1) == null)
	assert(generator.get_level_template(999) == null)
	var templates := generator.get_level_template(0)
	assert(templates != null and templates.TemplatePath.size() == 2)
	for template_path in templates.TemplatePath:
		assert(FileAccess.file_exists(template_path))
	for room in rooms.RoomLog:
		for direction in room.Exit:
			assert(direction in ENUM.Location.values())
		for property in room.get_property_list():
			assert(property.name != "Exit_v2")
			assert(property.name != "Entrance_v2")
	assert(rooms.RoomLog[0].RoomPath is PackedScene)
	assert(rooms.RoomLog[0].Exit == [ENUM.Location.RIGHT])
	assert(rooms.RoomLog[3].Exit == [ENUM.Location.RIGHT, ENUM.Location.BOTTOM])
	assert(rooms.RoomLog[4].Exit == [ENUM.Location.BOTTOM])
	assert(rooms.RoomLog[1].Exit.is_empty())
	var corridors := generator.corridor_candidates(0, "LEFT")
	assert(corridors.size() == 1)
	assert(corridors[0] == rooms.RoomLog[2].RoomPath)
	var selection := generator.select_room_scenes(0)
	assert(not selection.is_empty())
	assert(selection[0][0] == rooms.RoomLog[0].RoomPath)
	var generator_v2 := GeneratorV2.new()
	generator_v2.load_level_catalog()
	assert(generator_v2.get_level_rooms(0) == rooms)
	assert(generator_v2.get_level_rooms(-1) == null)
	assert(generator_v2.get_level_rooms(999) == null)
	var instance := generator_v2.instantiate_room(rooms.RoomLog[0])
	assert(instance != null)
	assert(generator_v2.DIRECT[ENUM.Location.TOP] == "TOP")
	assert(generator_v2.ENTRANCE_FOR_EXIT[ENUM.Location.RIGHT] == ENUM.Location.LEFT)
	assert(generator_v2.ENTRANCE_FOR_EXIT[ENUM.Location.LEFT] == ENUM.Location.RIGHT)
	assert(generator_v2.ENTRANCE_FOR_EXIT[ENUM.Location.TOP] == ENUM.Location.BOTTOM)
	assert(generator_v2.ENTRANCE_FOR_EXIT[ENUM.Location.BOTTOM] == ENUM.Location.TOP)
	assert(rooms.RoomLog[2].Entrance == ENUM.Location.LEFT)
	assert(rooms.RoomLog[4].Entrance == ENUM.Location.TOP)
	generator_v2.free()
	generator.free()
	print("room_config_test: PASS")
	get_tree().quit()
