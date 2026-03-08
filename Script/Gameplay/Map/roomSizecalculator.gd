@tool
extends Node2D

func _draw() -> void:
	pass
	draw_rect(Rect2(0.0, -384.0, 2880.0, 1704.0), Color.BLACK)
	draw_circle(Vector2(2880.0, 0),10, Color.YELLOW)

func _ready() -> void:
	# 只在编辑器中运行
	if not Engine.is_editor_hint():
		return
	
	# 使用call_deferred避免阻塞编辑器
	call_deferred("_scan_and_save")

func _scan_and_save() -> void:
	print("开始递归扫描地图场景中的TileMapLayer...")
	
	# 递归扫描"res://Scene/Map/"路径及其所有子文件夹下的场景
	var map_scenes = scan_map_scenes_recursive("res://Scene/Map/")
	
	if map_scenes.is_empty():
		print("未找到场景文件！")
		return
	
	print("总共找到 ", map_scenes.size(), " 个场景文件")
	
	# 获取各个场景中TileMapLayer的Rect2
	var scene_data:Dictionary = {}
	var processed = 0
	
	for scene_path in map_scenes:
		var scene_name = scene_path.get_file().get_basename()
		var relative_path = scene_path.trim_prefix("res://")
		
		print("正在处理 [", processed + 1, "/", map_scenes.size(), "]: ", relative_path)
		
		# 获取场景中所有TileMapLayer的边界
		var tilemap_data:Dictionary = await get_scene_tilemap_layers_rect(scene_path)
		if tilemap_data:
			scene_data[scene_name] = {
				"name": scene_name,
				"path": scene_path,
				"relative_path": relative_path,
				"folder": scene_path.get_base_dir().trim_prefix("res://"),
				"rect": tilemap_data.get("rect"),
				"exit_pos":tilemap_data.get("exit_pos")
			}
		processed += 1
	
	# 将结果保存为JSON
	save_to_json(scene_data, "res://Script/Gameplay/Map/tilemap_sizes.json")

# 递归扫描指定路径及其所有子文件夹下的场景文件
func scan_map_scenes_recursive(path: String) -> Array:
	var scenes = []
	var dir = DirAccess.open(path)
	
	if not dir:
		print("无法打开目录: ", path)
		return scenes
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		
		var full_path = path + file_name
		
		if dir.current_is_dir():
			# 递归扫描子文件夹
			var sub_scenes = scan_map_scenes_recursive(full_path + "/")
			scenes += sub_scenes
		elif file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
			scenes.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return scenes

# 获取场景中所有TileMapLayer的边界
func get_scene_tilemap_layers_rect(scene_path: String) -> Dictionary:
	var scene = load(scene_path)
	var instance = scene.instantiate()
	
	# 临时添加到场景树以获得准确布局
	add_child(instance)
	await get_tree().process_frame
	
	# 查找所有TileMapLayer并计算边界
	var tilemap_data = find_tilemap_layers(instance)
	
	# 清理
	instance.queue_free()
	
	return tilemap_data

# 递归查找所有TileMapLayer节点
func find_tilemap_layers(node: Node) -> Dictionary:
	var tilemap_data:Dictionary = {
		"rect": Rect2(),
		"exit_pos": Dictionary()
	}
	# 检查当前节点是否为TileMapLayer
	if node is TileMapLayer:
		tilemap_data["rect"] = calculate_tilemap_layer_bounds(node)

	#检查是否为出口并记录位置信息
	if node.name in ["UP", "BOTTOM", "LEFT", "RIGHT"]:
		tilemap_data["exit_pos"][node.name] = node.position

	# 递归检查子节点
	for child in node.get_children():
		tilemap_data["rect"] = find_tilemap_layers(child)["rect"].merge(tilemap_data["rect"])
		tilemap_data["exit_pos"].merge(find_tilemap_layers(child)["exit_pos"]) 
	return tilemap_data

# 计算TileMapLayer的边界
func calculate_tilemap_layer_bounds(layer: TileMapLayer) -> Rect2:
	var used_rect:Rect2 = layer.get_used_rect()
	
	if not used_rect.has_area():
		return Rect2()
	
	# 获取TileSet信息
	var tile_set = layer.tile_set
	if not tile_set:
		return Rect2()

	used_rect.position *= 24
	used_rect.size *= 24

	used_rect.position = to_global(used_rect.position)

	return used_rect


# 获取节点的完整路径字符串
func get_node_path_string(node: Node) -> String:
	var path = node.name
	var current = node.get_parent()
	
	while current and current != get_tree().root:
		path = current.name + "/" + path
		current = current.get_parent()
	
	return path

# 保存数据为JSON文件
func save_to_json(data: Dictionary, file_path: String) -> void:
	var json_string = JSON.stringify(data, "\t")
	
	# 确保目录存在
	var dir_path = file_path.get_base_dir()
	var dir = DirAccess.open(dir_path)
	if not dir:
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("JSON文件已保存: ", file_path)
	else:
		print("无法保存JSON文件: ", file_path)
