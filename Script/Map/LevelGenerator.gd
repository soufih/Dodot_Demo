extends Node

static var ReferLevelRoomLog:LevelRoomLog
static var ReferLevelTemplateLog:LevelTemplateLog

var Startpoint:Vector2i

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
	var CurrentLevelTemplates:Array = get_level_template(Level).get("TemplatePath")
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

	for Rooms in SelectedRooms:
		var RoomScene = Rooms[0]
		var Index = Rooms[1]
		var Entrance = Rooms[2]
		#如果是0号房间直接实例化
		if Index == 0:
			var Room = RoomScene.instantiate()
			RoomCache[Index] = Room
			#保存出生点
			if Room.get_node("Startpoint"):
				Startpoint = Room.get_node("Startpoint").global_position
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
	print("Done! Assemble Room")
	
	SelectedRooms.clear()
	RoomCache.clear()

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
	var Enemies:Array = EnemyManager.get_enemies(Level)
	#print(Enemies)
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
