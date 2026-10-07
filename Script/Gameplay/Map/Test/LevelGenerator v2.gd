@tool
extends Node

static var ReferLevelCatalog: LevelCatalog
var spaceUsage:Array[Rect2]
var levelInformation:Dictionary[Room,Dictionary]##{room:{entrance1: room2,...}...}
var tileMapsize:Dictionary
var maxAmount:int = 0

const DIRECT: Dictionary = {
	ENUM.Location.RIGHT: "RIGHT",
	ENUM.Location.TOP: "TOP",
	ENUM.Location.LEFT: "LEFT",
	ENUM.Location.BOTTOM: "BOTTOM",
}
# Match the next entrance to the opposite exit direction.
const ENTRANCE_FOR_EXIT: Dictionary = {
	ENUM.Location.RIGHT: ENUM.Location.LEFT,
	ENUM.Location.TOP: ENUM.Location.BOTTOM,
	ENUM.Location.LEFT: ENUM.Location.RIGHT,
	ENUM.Location.BOTTOM: ENUM.Location.TOP,
}
const TILE_MAP_SIZE_PATH: String = Path.TILEMAP_SIZES_JSON

class Room:
	var roomInstance:Node2D
	var roomConfig:RoomConfig
	
	func _init(instance:Node2D, config:RoomConfig):
		self.roomInstance = instance
		self.roomConfig = config

func _ready() -> void:
	load_level_catalog()
	load_tilemap_size()
	generate_map(0, 20, 10)

# 加载统一关卡目录。
func load_level_catalog() -> void:
	if ReferLevelCatalog != null:
		return
	ReferLevelCatalog = load(Path.LEVEL_CATALOG_RESOURCE) as LevelCatalog
	if ReferLevelCatalog == null:
		push_error("Failed to load LevelCatalog")

func load_tilemap_size():
	if not tileMapsize.is_empty():
		return
	#从json文件中读取tilemap大小
	var file = FileAccess.open(TILE_MAP_SIZE_PATH, FileAccess.ModeFlags.READ)
	if file:
		tileMapsize = JSON.parse_string(file.get_as_text())
	else:
		push_error("ERROR!WHEN OPEN TILEMAP SIZE FILE")

# 读取当前关卡的房间配置。
func get_level_rooms(level: int) -> LevelRoomConfig:
	if ReferLevelCatalog == null or level < 0 or level >= ReferLevelCatalog.Log.size():
		return null
	var config := ReferLevelCatalog.Log[level]
	return config.Rooms if config != null else null

#实例化房间
func instantiate_room(roomConfig:RoomConfig)->Node2D:
	var RoomScene:PackedScene = roomConfig.RoomPath
	if RoomScene == null:
		push_error("ERROR!WHEN LOAD ROOM SCENE")
		return null

	var RoomInstance = RoomScene.instantiate() as Node2D
	if !RoomInstance:
		push_error("ERROR!WHEN INSTANTIATE ROOM SCENE")
		return null
	add_child(RoomInstance)
	return RoomInstance

#生成地图
func generate_map(level: int, maxRoomAmount:int, maxDepth:int):
	randomize()
	var roomConfiglog = get_level_rooms(level)
	if not roomConfiglog:
		push_error("ERROR!NO ROOM CONFIG FOR THIS LEVEL")
		return

	var exit:ENUM.Location = ENUM.Location.RIGHT
	maxAmount = maxRoomAmount-maxDepth

	#随机挑选开始房间
	var lastRoom:Room = rand_generate_room(null, exit,[ENUM.Type.Start], roomConfiglog)
	 	
	#生成主干路并记录房间连接情况
	for i in range(maxDepth-2):
		#随机挑选下一个房间
		exit = lastRoom.roomConfig.Exit[randi() % lastRoom.roomConfig.Exit.size()]
		lastRoom = rand_generate_room(lastRoom, exit, [ENUM.Type.Corridor, ENUM.Type.Room], roomConfiglog)

	#随机挑选结束房间
	exit = lastRoom.roomConfig.Exit[randi() % lastRoom.roomConfig.Exit.size()]
	lastRoom = rand_generate_room(lastRoom, exit, [ENUM.Type.End], roomConfiglog)

	#生成支路
	var roomAmount = maxAmount
	
	for room in levelInformation.keys():
		roomAmount -= generate_branch(room, roomAmount, roomConfiglog)

#检查房间 确定是否合适
func check_room(roomConfig:RoomConfig, lastRoom:Room, exit:ENUM.Location)->bool:
	#检查房间空间占用情况，防止生成的房间重叠
	if tileMapsize.is_empty():
		return false

	var tmpRect:Rect2
	tmpRect.position = Vector2(tileMapsize[roomConfig.Name]["rect_p"]["x"], 
								tileMapsize[roomConfig.Name]["rect_p"]["y"])
	tmpRect.size =  Vector2(tileMapsize[roomConfig.Name]["rect_s"]["x"], 
							tileMapsize[roomConfig.Name]["rect_s"]["y"])
	var RoomRect = tmpRect

	if !lastRoom:
		spaceUsage.append(RoomRect)
		return true

	#计算上一个房间出口位置
	var exitPos:Vector2 = lastRoom.roomInstance.get_node(DIRECT[exit]).global_position
	if exitPos == Vector2.ZERO:
		push_error("ERROR!WHEN GET EXIT POSITION")
		return false

	#计算房间偏移后的位置,入口位置固定坐标原点
	RoomRect.position = exitPos+RoomRect.position
	for rect in spaceUsage:
		if rect.intersects(RoomRect):
			return false
	spaceUsage.append(RoomRect)

	return true

#随机生成房间
func rand_generate_room(lastRoom:Room, exit:ENUM.Location, SelectroomType:Array[ENUM.Type],roomConfiglog:LevelRoomConfig)->Room:
	var candidateRooms:Array[RoomConfig] = []
	var result:Room

	#根据房间类型和入口位置筛选候选房间
	for room:RoomConfig in roomConfiglog.RoomLog:
		if room != null and room.RoomPath != null and room.RoomType in SelectroomType and (room.Entrance == ENTRANCE_FOR_EXIT[exit] or !lastRoom): #匹配入口
			candidateRooms.append(room)
	
	#如果没有符合条件的房间，返回null
	if candidateRooms.is_empty():
		push_warning("ERROR!NO ROOM CAN BE SELECTED")
		return null

	#检查房间是否合适
	var roomConfig:RoomConfig = candidateRooms[randi() % candidateRooms.size()]
	if lastRoom:
		while !check_room(roomConfig, lastRoom, exit):
			candidateRooms.erase(roomConfig)
			if candidateRooms.is_empty():
				break
			roomConfig = candidateRooms[randi() % candidateRooms.size()]

	#实例化房间
	var roomInstance = instantiate_room(roomConfig)
	if not roomInstance:
		push_error("ERROR!WHEN INSTANTIATE ROOM")
		return null

	result = Room.new(roomInstance, roomConfig)

	if not lastRoom:
		levelInformation[result] = {}
		for e in result.roomConfig.Exit:
			#if not levelInformation[lastRoom].keys().has(e):
			levelInformation[result][e] = null
		return result

	#记录房间连接情况
	
	levelInformation[lastRoom][exit] = result

	if !levelInformation.has(result):
		levelInformation[result] = {}
	for e in result.roomConfig.Exit:
		#if not levelInformation[lastRoom].keys().has(e):
		levelInformation[result][e] = null

	#连接房间
	var exitNode:Node2D = lastRoom.roomInstance.get_node(DIRECT[exit])
	roomInstance.global_position = exitNode.global_position

	return result

#生成支路
func generate_branch(room: Room, maxExtendlength:int, roomConfiglog:LevelRoomConfig)->int:
	if not room:
		return 0
	
	for exit in room.roomConfig.Exit:
		var exits:Dictionary = levelInformation.get(room)
		#print(exits[exit])
		if exits[exit] == null:
			#最大延展长度为0时，保底生成一个房间并退出
			if maxExtendlength <= 0:
				rand_generate_room(room, exit, [ENUM.Type.End], roomConfiglog)
				return 0

			#单个支路最大延展长度
			var extendLength = randi_range(1, maxExtendlength-1)
			maxExtendlength -= extendLength
			
			var branchRoom:Room = rand_generate_room(room, exit, [ENUM.Type.Room, ENUM.Type.Corridor], roomConfiglog)
			return generate_branch(branchRoom, maxExtendlength,roomConfiglog)+extendLength

	return 0
