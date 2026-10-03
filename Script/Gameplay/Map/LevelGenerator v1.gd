@tool
extends Node
class_name LevelGenerator

static var ReferLevelRoomLog:LevelRoomLog
static var ReferLevelTemplateLog:LevelTemplateLog
static var _template_cache: Dictionary[String, Array] = {}
static var _prepared_level: int = -1
static var _prepared_selection: Array = []

const SceneLoading = preload("res://Script/Gameplay/System/SceneLoader.gd")

@export var auto_generate: bool = true
var loading_progress: float = 0.0
var generation_succeeded: bool = false
var _generated_nodes: Array[Node] = []
var _enemies: Array = []

var Startpoint:Vector2i
## 单个房间发生碰撞后，最多插入的无支路走廊数量。
@export_range(1, 32, 1) var max_corridor_retries: int = 8
## 现有房间接口有 8 像素的墙边重叠，允许接缝误差。
@export_range(0.0, 24.0, 0.5) var collision_tolerance: float = 8.0

const OPPOSITE_EXIT = {"LEFT": "RIGHT", "RIGHT": "LEFT", "TOP": "BOTTOM", "BOTTOM": "TOP"}
# RoomConfig.Exit 的顺序与 Entrance 枚举不同。
const EXIT_ORDER = ["LEFT", "TOP", "RIGHT", "BOTTOM"]

func _ready() -> void:
	if Engine.is_editor_hint() or not auto_generate:
		return
	generate_level(LevelInformation.Level)

#房间数据初始化
func prepare_generating():
	load_level_room_log()
	load_level_template_log()

#生成关卡
func generate_level(level: int) -> bool:
	prepare_generating()
	destroy_level()
	Startpoint = Vector2i.ZERO
	generation_succeeded = false
	var existing := get_children()
	var assembled := assemble_room(level)
	for child in get_children():
		if not existing.has(child):
			_generated_nodes.append(child)
	if not assembled:
		destroy_level()
		return false
	_enemies = EnemyManager.get_enemies_of_level(level)
	if not generate_enemy(level) or not generate_player():
		destroy_level()
		return false
	for child in get_children():
		if not existing.has(child) and not _generated_nodes.has(child):
			_generated_nodes.append(child)
	generation_succeeded = true
	return true

#加载房间列表
func load_level_room_log():
	if ReferLevelRoomLog:
		return
	ReferLevelRoomLog = load("res://Rescource/Data/LevelRoomLog.tres") as LevelRoomLog
	if !ReferLevelRoomLog:
		push_error("ERRO!WHEN LOAD ROOMS OF LEVEL")

#加载模板列表
func load_level_template_log():
	if ReferLevelTemplateLog:
		return
	ReferLevelTemplateLog = load("res://Rescource/Data/LevelTemplateLog.tres") as LevelTemplateLog
	if !ReferLevelTemplateLog:
		push_error("ERRO!WHEN LOAD LEVEL TEMPLATE")

#加载房间
func get_level_rooms(Level:int)->LevelRoomConfig:
	if ReferLevelRoomLog:
		if Level < 0 or Level >= ReferLevelRoomLog.LevelLog.size():
			return null
		var result = ReferLevelRoomLog.LevelLog[Level]
		if result:
			return result
	return null

#加载模板
func get_level_template(Level:int)->TemplateConfig:
	if ReferLevelTemplateLog:
		if Level < 0 or Level >= ReferLevelTemplateLog.LevelLog.size():
			return null
		var result = ReferLevelTemplateLog.LevelLog[Level]
		if result:
			return result
	return null

#随机挑选模板
func random_select_level_template(Level:int)->Array:
	var LevelTemplates = get_level_template(Level)
	if !LevelTemplates:
		return []
	var CurrentLevelTemplates:Array = LevelTemplates.get("TemplatePath")
	if !CurrentLevelTemplates:
		return []
	var Size = CurrentLevelTemplates.size()
	
	var path: String = CurrentLevelTemplates[randi() % Size]
	if _template_cache.has(path):
		return _template_cache[path]
	var Result = FileAccess.open(path, FileAccess.READ)
	if Result == null:
		push_error("ERRO!WHEN ACCESS TEMPLATE FILE", FileAccess.get_open_error())
		return []
	var parsed = JSON.parse_string(Result.get_as_text())
	if not parsed is Array:
		push_error("关卡模板不是有效数组：%s" % path)
		return []
	_template_cache[path] = parsed
	return parsed

#随机挑选房间
func select_room_paths(Level: int) -> Array:
	var Template = random_select_level_template(Level)
	var Rooms = get_level_rooms(Level)
	var SelectedRooms:Array
	if Rooms == null or Template.is_empty():
		push_error("关卡 %s 缺少房间或模板配置。" % Level)
		return []
	
	for Target in Template:
		var Candidate:Array = [] #保存候选房间
		Candidate.clear()
		
		for Room in Rooms.RoomLog: #筛选符合条件的房间
			if check_room(Room, Target):
				Candidate.append(Room.RoomPath)#加入候选房间
				
		if Candidate.size() == 0:
			# 现有模板含尚未配置的末端分支，保持原来的已匹配前缀生成行为。
			break
		var result: String = Candidate[randi() % Candidate.size()]
		var Index:int = Target[3]
		SelectedRooms.append([result, Index, Target[1]]) #保存房间信息和它的相对位置信息

	return SelectedRooms


func select_room(Level: int) -> Array:
	var paths: Array
	if _prepared_level == Level and not _prepared_selection.is_empty():
		paths = _prepared_selection
		_prepared_selection = []
		_prepared_level = -1
	else:
		paths = select_room_paths(Level)
	var selected: Array = []
	for room in paths:
		var scene := SceneLoading.get_scene(room[0])
		if scene == null:
			return []
		selected.append([scene, room[1], room[2]])
	return selected


## 加载界面提前确定模板，只加载本次房间、备用直走廊及角色/UI资源。
func prepare_level_async(level: int) -> bool:
	prepare_generating()
	_prepared_level = -1
	_prepared_selection = []
	var selection := select_room_paths(level)
	if selection.is_empty():
		return false
	var paths: Array[String] = [SceneLoading.HERO_SCENE_PATH]
	paths.append_array(SceneLoading.LEVEL_UI_PATHS)
	for room in selection:
		paths.append(room[0])
	for entrance in ENTRANCE:
		paths.append_array(corridor_paths(level, entrance))
	for enemy in EnemyManager.get_enemies_of_level(level):
		paths.append(enemy.Path)
	var loaded: bool = await SceneLoading.prepare_scenes(paths, get_tree(), _on_loading_progress)
	if loaded:
		_prepared_level = level
		_prepared_selection = selection
	return loaded


func _on_loading_progress(value: float) -> void:
	loading_progress = value

#将枚举量与字符串映射
var TYPE = ['Start', 'Corridor', 'Room', 'End']
var ENTRANCE = ['LEFT','RIGHT','TOP','BOTTOM']

#检查房间 确定是否合适
func check_room(Room:RoomConfig, Target:Array)->bool:
	var TargetType = Target[0]
	var TargetEntrance = Target[1]
	var TargetExit = Target[2] 
	return TYPE[Room.RoomType] == TargetType && ENTRANCE[Room.Entrance] == TargetEntrance && Room.Exit == TargetExit 

#组装房间
func assemble_room(Level:int) -> bool:
	var SelectedRooms:Array = select_room(Level)
	if SelectedRooms.is_empty():
		return false
	var RoomCache:Dictionary={}
	# 分支会覆盖 RoomCache 的索引；碰撞记录必须独立保留所有房间。
	var occupied: Array[Rect2] = []

	for Rooms in SelectedRooms:
		var RoomScene = Rooms[0]
		var Index = Rooms[1]
		var Entrance = Rooms[2]
		#如果是0号房间直接实例化
		if Index == 0:
			var Room = RoomScene.instantiate()
			RoomCache[Index] = Room
			add_child(Room)
			occupied.append(room_bounds(Room))
			#保存出生点
			if Room.has_node("Startpoint"):
				Startpoint = Room.get_node("Startpoint").global_position
			continue
		
		#在缓存中查找当前房间的相邻的房间
		var Neighbour
		if RoomCache.has(Index-1):
			Neighbour = RoomCache[Index-1]
		else:
			return false
				
		#将当前房间与相邻房间拼接
		var RoomExit:String
		match Entrance:
			"LEFT":
				RoomExit = "RIGHT"
			"RIGHT":
				RoomExit = "LEFT"
			"TOP":
				RoomExit = "BOTTOM"
			"BOTTOM":
				RoomExit = "TOP"
				
		if !Neighbour.has_node(RoomExit):
			push_error("ERRO!!LACK ROOM")
			return false
		# 成功后才写入模板缓存，插入的走廊不占用模板索引。
		var TargetRoom = place_room_with_corridors(RoomScene, Neighbour, Entrance, Level, occupied)
		if TargetRoom == null:
			push_error("无法放置房间 %s：没有可用的无碰撞走廊连接。" % Index)
			return false
		RoomCache[Index] = TargetRoom
	print("Done! Assemble Room")
	
	SelectedRooms.clear()
	RoomCache.clear()
	return true


## 以 BaseLayer 占地检测，包含房间内部空地；边界接触不算碰撞。
## 使用局部变换组合，兼容原生成器在 _init 中、尚未入树时生成。
func room_bounds(room: Node2D) -> Rect2:
	var layer := room.get_node_or_null("BaseLayer") as TileMapLayer
	if layer == null or layer.tile_set == null or not layer.get_used_rect().has_area():
		return Rect2()
	var cells := layer.get_used_rect()
	var size := Vector2(layer.tile_set.tile_size)
	var local_rect := Rect2(Vector2(cells.position) * size, Vector2(cells.size) * size)
	return room.transform * (layer.transform * local_rect)


func overlaps_rooms(bounds: Rect2, occupied: Array[Rect2]) -> bool:
	for other in occupied:
		var overlap := bounds.intersection(other)
		if overlap.size.x > collision_tolerance and overlap.size.y > collision_tolerance:
			return true
	return false


## 同方向的一入一出走廊才能继续连接原来选中的房间，不选多出口走廊。
func corridor_paths(level: int, entrance: String) -> Array[String]:
	var result: Array[String] = []
	var rooms := get_level_rooms(level)
	if rooms == null or not OPPOSITE_EXIT.has(entrance):
		return result
	var exit_index := EXIT_ORDER.find(OPPOSITE_EXIT[entrance])
	for config in rooms.RoomLog:
		if config == null or TYPE[config.RoomType] != "Corridor":
			continue
		if ENTRANCE[config.Entrance] != entrance or config.Exit.size() != 4:
			continue
		if config.Exit.count(true) != 1 or not config.Exit[exit_index]:
			continue
		result.append(config.RoomPath)
	return result


func corridor_candidates(level: int, entrance: String) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
	for path in corridor_paths(level, entrance):
		var scene := SceneLoading.get_scene(path)
		if scene != null:
			result.append(scene)
	result.shuffle()
	return result


func place_room_with_corridors(scene: PackedScene, neighbour: Node2D, entrance: String,
		level: int, occupied: Array[Rect2]) -> Node2D:
	var exit_name: String = OPPOSITE_EXIT[entrance]
	var target := scene.instantiate() as Node2D
	var anchor := neighbour
	var inserted: Array[Node2D] = []
	var original_count := occupied.size()
	var candidates: Array[PackedScene] = []
	for attempt in range(max_corridor_retries + 1):
		# 场景根节点是入口；出口坐标转换到生成器的局部空间。
		var marker := anchor.get_node(exit_name) as Node2D
		target.position = anchor.transform * marker.position
		var bounds := room_bounds(target)
		if not bounds.has_area():
			push_error("房间缺少有效的 BaseLayer 占地：%s" % scene.resource_path)
			break
		if not overlaps_rooms(bounds, occupied):
			add_child(target)
			occupied.append(bounds)
			return target
		if attempt == max_corridor_retries:
			break
		if attempt == 0:
			candidates = corridor_candidates(level, entrance)
		var extension: Node2D = null
		for corridor_scene in candidates:
			var corridor := corridor_scene.instantiate() as Node2D
			corridor.position = target.position
			var corridor_bounds := room_bounds(corridor)
			# 配置与场景都只能有一个出口，防止误配置引入支路。
			var exits: int = 0
			for direction in EXIT_ORDER:
				if corridor.has_node(direction):
					exits += 1
			if exits == 1 and corridor.has_node(exit_name) and corridor_bounds.has_area() and not overlaps_rooms(corridor_bounds, occupied):
				extension = corridor
				add_child(extension)
				inserted.append(extension)
				occupied.append(corridor_bounds)
				break
			corridor.free()
		if extension == null:
			break
		anchor = extension
	# 重试失败时撤销本次插入，避免留下不连接目标房间的走廊。
	target.free()
	for corridor in inserted:
		remove_child(corridor)
		corridor.free()
	occupied.resize(original_count)
	return null

#生成敌人
func generate_enemy(Level:int) -> bool:
	# 只遍历本次生成的房间，保留相机等非关卡子节点。
	for room in _generated_nodes:
		if room.has_node("EnemySpawnPoint"):
			#获取房间内的敌人生成点
			var SpawnPoints = room.get_node("EnemySpawnPoint").get_children()
			if not spawn_enemy(SpawnPoints, Level):
				return false
	
	print("Done! Generate Enemy")
	return true

#生成敌人的具体规则
func spawn_enemy(SpawnPoints:Array[Node], Level:int) -> bool:
	var Size = SpawnPoints.size()
	var Index = 0
	var Enemies: Array = _enemies
	if Enemies.size() == 0:
		return true

	while Index < Size:
		#随机挑选一个敌人
		var Target:EnemyConfig = Enemies.get(randi()%Enemies.size())
		
		#生成敌人
		var scene := SceneLoading.get_scene(Target.Path)
		if scene == null:
			return false
		var Enemy = scene.instantiate()
		SpawnPoints[Index].add_child(Enemy)
		
		#普通敌人可较为密集的生成
		if Target.Level == ENUM.EnemyLevel.Normal:
			Index += 1
		
		#精英敌人分散生成
		if Target.Level == ENUM.EnemyLevel.Elite:
			Index += 2
		elif Target.Level != ENUM.EnemyLevel.Normal:
			Index += 1
		
		if Index >= Size:
			break
	return true

#生成玩家
func generate_player() -> bool:
	var scene := SceneLoading.get_scene(SceneLoading.HERO_SCENE_PATH)
	if scene == null:
		return false
	var hero = scene.instantiate()
	if !hero:
		return false
	DataLoader.set_hero(hero)
	add_child(hero)
	hero.global_position = Startpoint
	print("Done! Generate Player")
	return true

##销毁关卡
func destroy_level():
	if not Engine.is_editor_hint() and is_instance_valid(DataLoader.HERO) and _generated_nodes.has(DataLoader.HERO):
		DataLoader.set_hero(null)
	for node in _generated_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	_generated_nodes.clear()
