@tool
extends Node
class_name LevelGenerator

static var ReferLevelRoomLog:LevelRoomLog
static var ReferLevelTemplateLog:LevelTemplateLog

var Startpoint:Vector2i
## 单个房间发生碰撞后，最多插入的无支路走廊数量。
@export_range(1, 32, 1) var max_corridor_retries: int = 8
## 现有房间接口有 8 像素的墙边重叠，允许接缝误差。
@export_range(0.0, 24.0, 0.5) var collision_tolerance: float = 8.0

const OPPOSITE_EXIT = {"LEFT": "RIGHT", "RIGHT": "LEFT", "TOP": "BOTTOM", "BOTTOM": "TOP"}
# RoomConfig.Exit 的顺序与 Entrance 枚举不同。
const EXIT_ORDER = ["LEFT", "TOP", "RIGHT", "BOTTOM"]

func _init() -> void:
	prepare_generating()
	#generate_level(LevelInformation.get_level_info().level)
	generate_level(0)
	
func _ready() -> void:
	prepare_generating()

#房间数据初始化
func prepare_generating():
	randomize()
	load_level_room_log()
	load_level_template_log()

#生成关卡
func generate_level(level: int):
	assemble_room(level)
	generate_enemy(level)
	generate_player()

#加载房间列表
func load_level_room_log():
	if ReferLevelRoomLog:
		return
	ReferLevelRoomLog = load("uid://dh3a2qfk263s4") as LevelRoomLog
	if !ReferLevelRoomLog:
		push_error("ERRO!WHEN LOAD ROOMS OF LEVEL")

#加载模板列表
func load_level_template_log():
	if ReferLevelTemplateLog:
		return
	ReferLevelTemplateLog = load("uid://imcee336yrsx") as LevelTemplateLog
	if !ReferLevelTemplateLog:
		push_error("ERRO!WHEN LOAD LEVEL TEMPLATE")

#加载房间
func get_level_rooms(Level:int)->LevelRoomConfig:
	if ReferLevelRoomLog:
		var result = ReferLevelRoomLog.LevelLog.get(Level)
		if result:
			return result
	return null

#加载模板
func get_level_template(Level:int)->TemplateConfig:
	if ReferLevelTemplateLog:
		var result = ReferLevelTemplateLog.LevelLog.get(Level)
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
	
	var Result = FileAccess.open(CurrentLevelTemplates[randi()%Size], FileAccess.READ)
	if Result == null:
		push_error("ERRO!WHEN ACCESS TEMPLATE FILE", FileAccess.get_open_error())
	return JSON.parse_string(Result.get_line())

#随机挑选房间
func select_room(Level:int)->Array:
	var Template = random_select_level_template(Level)
	var Rooms =  get_level_rooms(Level)	
	var SelectedRooms:Array
	
	for Target in Template:
		var Candidate:Array = [] #保存候选房间
		Candidate.clear()
		
		for Room in Rooms.RoomLog: #筛选符合条件的房间
			if check_room(Room, Target):
				Candidate.append(Room.RoomPath)#加入候选房间
				
		if Candidate.size() == 0:
			break
		# #从候选房间中随机挑选一个
		var result = load(Candidate[randi()%Candidate.size()]) as PackedScene #从候选房间中随机挑选一个
		var Index:int = Target[3]
		var entrance:String = Target[1]
		
		SelectedRooms.append([result, Index, Target[1]]) #保存房间信息和它的相对位置信息

		# var result:String = Candidate[randi()%Candidate.size()]
		# if !RoomLoadThreads.is_alive():
		# 	RoomLoadThreads.start(load_rooms.bind(SelectedRooms, Index, entrance, result))
		# RoomLoadThreads.wait_to_finish()

	return SelectedRooms

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
func assemble_room(Level:int):
	var SelectedRooms:Array = select_room(Level)
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
			return
				
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
			return
		# 成功后才写入模板缓存，插入的走廊不占用模板索引。
		var TargetRoom = place_room_with_corridors(RoomScene, Neighbour, Entrance, Level, occupied)
		if TargetRoom == null:
			push_error("无法放置房间 %s：没有可用的无碰撞走廊连接。" % Index)
			return
		RoomCache[Index] = TargetRoom
	print("Done! Assemble Room")
	
	SelectedRooms.clear()
	RoomCache.clear()


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
func corridor_candidates(level: int, entrance: String) -> Array[PackedScene]:
	var result: Array[PackedScene] = []
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
		var scene := load(config.RoomPath) as PackedScene
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
func generate_enemy(Level:int):
	#获取所有房间
	var Rooms = self.get_children()
	
	#遍历所有房间
	for room:Node2D in Rooms:
		if room.has_node("EnemySpawnPoint"):
			#获取房间内的敌人生成点
			var SpawnPoints = room.get_node("EnemySpawnPoint").get_children()
			spawn_enemy(SpawnPoints, Level)
	
	print("Done! Generate Enemy")

#生成敌人的具体规则
func spawn_enemy(SpawnPoints:Array[Node], Level:int):
	var Size = SpawnPoints.size()
	var Index = 0
	var Enemies:Array = EnemyManager.get_enemies_of_level(Level)
	if Enemies.size() == 0:
		return

	while Index < Size:
		randomize()
		#随机挑选一个敌人
		var Target:EnemyConfig = Enemies.get(randi()%Enemies.size())
		
		#生成敌人
		var Enemy = load(Target.Path).instantiate()
		SpawnPoints[Index].add_child(Enemy)
		
		#普通敌人可较为密集的生成
		if Target.Level == ENUM.EnemyLevel.Normal:
			Index += 1
		
		#精英敌人分散生成
		if Target.Level == ENUM.EnemyLevel.Elite:
			Index += 2
		
		if Index >= Size:
			break

#生成玩家
func generate_player():
	var hero = load("res://Scene/Hero/Hero.tscn").instantiate()
	if !hero:
		return
	DataLoader.set_hero(hero)
	add_child(hero)
	hero.global_position = Startpoint
	print("Done! Generate Player")

##销毁关卡
func destroy_level():
	var Rooms = self.get_children()
	for room in Rooms:
		room.queue_free()
	print("Done! Destroy Level")
