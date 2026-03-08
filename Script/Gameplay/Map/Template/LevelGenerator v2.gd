extends Node

static var ReferLevelRoomLog:LevelRoomLog
var roomSpace:Array[Rect2]
var levelInformation:Dictionary##{room:[{entrance1: room2}]...}
var tileMapsize:Dictionary
var roomCache:Dictionary[String, PackedScene]

const Direct: Dictionary = {
	ENUM.Location_v2.RIGHT : "RIGHT", 
	ENUM.Location_v2.UP : "UP", 
	ENUM.Location_v2.NONE : "NONE",
	ENUM.Location_v2.LEFT : "LEFT", 
	ENUM.Location_v2.DOWN : "DOWN",
	}

#加载房间列表
func load_level_room_log():
	if ReferLevelRoomLog:
		return
	ReferLevelRoomLog = load("uid://dh3a2qfk263s4") as LevelRoomLog
	if !ReferLevelRoomLog:
		push_error("ERRO!WHEN LOAD ROOMS OF LEVEL")

func load_tilemap_size():
	if tileMapsize.size() > 0:
		return
	#从json文件中读取tilemap大小
	var file = FileAccess.open("res://Config/Level/TileMapSize.json", FileAccess.ModeFlags.READ)
	if file:
		var json = file.parse(file.get_as_text())
		if json.error == OK:
			tileMapsize = json.result
		else:
			push_error("ERROR!WHEN LOAD TILEMAP SIZE")
	else:
		push_error("ERROR!WHEN OPEN TILEMAP SIZE FILE")

#加载房间列表
func get_level_rooms(level:int)->LevelRoomConfig:
	if ReferLevelRoomLog:
		var result = ReferLevelRoomLog.LevelLog.get(level)
		if result:
			return result
	return null

#实例化房间
func instantiate_room(Room:RoomConfig)->Node2D:
	var RoomScene:PackedScene
	if Room.RoomPath in roomCache:
		RoomScene = roomCache[Room.RoomPath]
	else:
		RoomScene = load(Room.RoomPath) as PackedScene
		if !RoomScene:
			push_error("ERROR!WHEN LOAD ROOM SCENE")
			return null
		roomCache[Room.RoomPath] = RoomScene
	
	var RoomInstance = RoomScene.instantiate() as Node2D
	if !RoomInstance:
		push_error("ERROR!WHEN INSTANTIATE ROOM SCENE")
		return null
	get_tree().current_scene.add_child(RoomInstance)
	return RoomInstance

func clear_room_cache():
	roomCache.clear()

#检查房间 确定是否合适
func check_room(Room:RoomConfig, lastRoom:RoomConfig, exit:ENUM.Location_v2)->bool:
	#检查房间空间占用情况，防止生成的房间重叠
	var RoomRect:Rect2 = tileMapsize[Room.Name].get("rect")
	if !lastRoom:
		roomSpace.append(RoomRect)
		return true

	#计算房间偏移后的占用情况
	var exitPos:Vector2 = tileMapsize[lastRoom.Name].get("exit_pos").get(Direct.get(exit))
	RoomRect.position = exitPos-RoomRect.position

	for rect in roomSpace:
		if rect.intersects(RoomRect):
			return false
	roomSpace.append(RoomRect)

	return true


func generate_map(level: int, maxAmount:int, maxDepth:int):
	var roomConfiglog = get_level_rooms(level)

	#随机挑选开始房间
	var lastRoom = rand_select_room(null ,null, [ENUM.Type.Start], roomConfiglog)
	 	
	#生成主干路并记录房间连接情况
	for i in range(maxDepth):
		#随机挑选下一个房间
		lastRoom = rand_select_room(lastRoom["RoomInstance"], lastRoom["RoomConfig"], [ENUM.Type.Corridor, ENUM.Type.Room], roomConfiglog)

	#随机挑选结束房间
	lastRoom = rand_select_room(lastRoom["RoomInstance"], lastRoom["RoomConfig"], [ENUM.Type.End], roomConfiglog)

	maxAmount -= maxDepth
	#遍历主干路根据房间的出口信息挑选入口匹配的房间


func rand_select_room(lastRoominstance:Node2D, lastRoom:RoomConfig, roomType:Array[ENUM.Type],roomConfiglog:LevelRoomConfig)->Dictionary:
	var exit = lastRoom.Exit_v2[randi() % lastRoom.Exit_v2.size()]
	var candidateRooms:Array[RoomConfig] = []

	#根据房间类型和入口位置筛选候选房间
	for room:RoomConfig in roomConfiglog.RoomLog:
		if room.RoomType in roomType and (room.Entrance_v2 == -exit or !lastRoom): #匹配入口
			candidateRooms.append(room)

	#如果没有符合条件的房间，返回null
	if candidateRooms.is_empty():
		push_error("ERROR!NO ROOM CAN BE SELECTED")
		return {}

	#检查房间是否合适
	var Room:RoomConfig = candidateRooms[randi() % candidateRooms.size()]
	while !check_room(Room, lastRoom, exit) || candidateRooms.is_empty() || !lastRoom:
		candidateRooms.erase(Room)
		Room = candidateRooms[randi() % candidateRooms.size()]
	
	#实例化房间
	var RoomInstance = instantiate_room(Room)
	if !RoomInstance:
		push_error("ERROR!WHEN INSTANTIATE ROOM")
		return {}

	if !lastRoominstance:
		return {"RoomInstance": RoomInstance, "RoomConfig": Room}

	#记录房间连接情况
	if !levelInformation.has(lastRoominstance):
		levelInformation[lastRoominstance] = []
	for e in lastRoom.Exit_v2:
		levelInformation[lastRoominstance].append({e: null})
	levelInformation[lastRoominstance][exit] = RoomInstance

	#连接房间
	var exitNode:Node2D = lastRoominstance.get_node(Direct[exit])
	RoomInstance.global_position = exitNode.global_position
	
	return {"RoomInstance": RoomInstance, "RoomConfig": Room}


func generate_branch():
	pass