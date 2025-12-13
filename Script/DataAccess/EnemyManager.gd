extends Node

var InforLevelEnemyLog:LevelEnemyLog
var InforEnemyPorpertyLog:EnemyPorpertyLog

func _ready() -> void:
	load_enemy_log()
	load_enemy_porperty()

#加载关卡敌人列表
func load_enemy_log():
	InforLevelEnemyLog = load("uid://buyhm8wjeyf3u") as LevelEnemyLog
	#print(InforLevelEnemyLog)
	if !InforLevelEnemyLog:
		push_error("ERRO!WHEN LOAD ENEMY")

func load_enemy_porperty():
	InforEnemyPorpertyLog = load("uid://2srf8bdj186") as EnemyPorpertyLog
	if !InforEnemyPorpertyLog:
		push_error("ERRO!WHEN LOAD ENEMY PORPERTY")

#获取敌人
func get_enemies(Level:int)->Array:
	if InforLevelEnemyLog:
		var result:EnemyLog = InforLevelEnemyLog.Log.get(Level)
		if result:
			return result.Log
	return []

#获取敌人属性
func get_enemy_porperty(Name:String)->EnemyPorperty:
	if InforEnemyPorpertyLog:
		if InforEnemyPorpertyLog.Log.get(Name):
			return InforEnemyPorpertyLog.Log.get(Name)
	return null

#获取敌人掉落物
func get_dropped_item(target:String)->Array[Vector4]:
	if InforEnemyPorpertyLog:
		var porperty:EnemyPorperty = InforEnemyPorpertyLog.Log.get(target)
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
