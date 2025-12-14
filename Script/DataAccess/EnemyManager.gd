extends Node

var ReferLevelEnemyLog:LevelEnemyLog
var ReferEnemyPorpertyLog:EnemyPorpertyLog

##加载敌人数据
func load_enemy():
	load_enemy_log()
	load_enemy_porperty()

#加载关卡敌人列表
func load_enemy_log():
	ReferLevelEnemyLog = load("uid://buyhm8wjeyf3u") as LevelEnemyLog
	#print(ReferLevelEnemyLog)
	if !ReferLevelEnemyLog:
		push_error("ERRO!WHEN LOAD ENEMY")

#加载敌人属性列表
func load_enemy_porperty():
	ReferEnemyPorpertyLog = load("uid://2srf8bdj186") as EnemyPorpertyLog
	if !ReferEnemyPorpertyLog:
		push_error("ERRO!WHEN LOAD ENEMY PORPERTY")

#获取敌人
func get_enemies(Level:int)->Array:
	if ReferLevelEnemyLog:
		var result:EnemyLog = ReferLevelEnemyLog.Log.get(Level)
		if result:
			return result.Log
	return []

#获取敌人属性
func get_enemy_porperty(Name:String)->EnemyPorperty:
	if ReferEnemyPorpertyLog:
		if ReferEnemyPorpertyLog.Log.get(Name):
			return ReferEnemyPorpertyLog.Log.get(Name)
	return null

#获取敌人掉落物
func get_dropped_item(target:String)->Array[Vector4]:
	if ReferEnemyPorpertyLog:
		var porperty:EnemyPorperty = ReferEnemyPorpertyLog.Log.get(target)
		if porperty:
			return porperty.Drop
	return []

#掉落物品
func drop(Target:String, Pos:Vector2):
	var Items:Array[Vector4] = EnemyManager.get_dropped_item(Target)
	var result:Array = []

	for Item:Vector4 in Items:
		
		var id = int(Item.x) 
		var range_x = Item.y
		var range_y = Item.z
		var probility = Item.w
		#判断能否掉落
		if randf_range(0, 100) > probility:
			continue

		var amount = randi_range(range_x, range_y)
		result.append([id, amount])

	if result.size() == 0:
		return

	DroppedItemSystem.create_dropped_item(result, Pos)
