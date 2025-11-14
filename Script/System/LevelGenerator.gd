extends Node

var InforLevelRoomLog:LevelRoomLog
var InforLevelTemplateLog:LevelTemplateLog


func _ready() -> void:
	randomize()
	prepare_generating()
	assemble_room(0)

func prepare_generating():
	load_level_room_log()
	load_level_template_log()


func load_level_room_log():
	InforLevelRoomLog = load("uid://dh3a2qfk263s4") as LevelRoomLog
	if !InforLevelRoomLog:
		push_error("ERRO!WHEN LOAD ROOMS OF LEVEL")

func load_level_template_log():
	InforLevelTemplateLog = load("uid://imcee336yrsx") as LevelTemplateLog
	if !InforLevelTemplateLog:
		push_error("ERRO!WHEN LOAD LEVEL TEMPLATE")

func get_level_rooms(Level:int)->LevelRoomConfig:
	if InforLevelRoomLog:
		return InforLevelRoomLog.LevelLog[Level]
	return null

func get_level_template(Level:int)->TemplateConfig:
	if InforLevelTemplateLog:
		return InforLevelTemplateLog.LevelLog[Level]
	return null

func random_select_level_template(Level:int)->Array:
	var CurrentLevelTemplates:Array = get_level_template(Level).TemplatePath
	var Size = CurrentLevelTemplates.size()
	
	var Result = FileAccess.open(CurrentLevelTemplates[randi()%Size], FileAccess.READ)
	if Result == null:
		push_error("ERRO!WHEN ACCESS TEMPLATE FILE", FileAccess.get_open_error())
	return JSON.parse_string(Result.get_line())

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
		#从候选房间中随机挑选一个
		var result = load(Candidate[randi()%Candidate.size()]) as PackedScene #从候选房间中随机挑选一个
		
		var Index:int = Target[3]
		SelectedRooms.append([result, Index, Target[1]]) #保存房间信息和它的相当位置信息
		
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

func assemble_room(Level:int):
	var SelectedRooms:Array = select_room(Level)
	var RoomCache:Dictionary={}

	for Rooms in SelectedRooms:
		var RoomScene = Rooms[0]
		var Index = Rooms[1]
		var Entrance = Rooms[2]
		#如果是0号房间直接实例化
		if Index == 0:
			var Room = RoomScene.instantiate()
			RoomCache[Index] = Room
			add_child(Room)
			continue
		
		#在缓存中查找当前房间的相邻的房间
		var Neighbour
		if RoomCache.has(Index-1):
			Neighbour = RoomCache[Index-1]
		else:
			return
				
		#将当前房间与相邻房间拼接
		var Exit:String
		match Entrance:
			"LEFT":
				Exit = "RIGHT"
			"RIGHT":
				Exit = "LEFT"
			"TOP":
				Exit = "BOTTOM"
			"BOTTOM":
				Exit = "TOP"
				
		if !Neighbour.get_node(Exit):
			push_error("ERRO!!LACK ROOM")
			return
		#实例化房间并将其加入缓存
		var TargetRoom = RoomScene.instantiate()
		RoomCache[Index] = TargetRoom
		add_child(TargetRoom)
		
		#拼接房间
		TargetRoom.global_position = Neighbour.get_node(Exit).global_position
	print("Done!")
	
	SelectedRooms.clear()
	RoomCache.clear()
