extends Node

var ReferEnemyPorpertyLog:EnemyPorpertyLog

##加载敌人数据
func load_enemy():
	load_enemy_porperty()

#加载敌人属性列表
func load_enemy_porperty():
	if ReferEnemyPorpertyLog != null:
		return
	ReferEnemyPorpertyLog = load("uid://2srf8bdj186") as EnemyPorpertyLog
	if !ReferEnemyPorpertyLog:
		push_error("ERRO!WHEN LOAD ENEMY PORPERTY")

#获取敌人
func get_enemies_of_level(Level:int)->Array:
	var enemies:Array = []
	if ReferEnemyPorpertyLog:
		var result:Dictionary = ReferEnemyPorpertyLog.Log
		if !result:
			return enemies
		for enemy in result:
			if result[enemy].Habitat == Level:
				enemies.append(result[enemy])
	return enemies

#获取敌人属性
func get_enemy_porperty(Name:String)->EnemyConfig:
	if ReferEnemyPorpertyLog:
		if ReferEnemyPorpertyLog.Log.get(Name):
			return ReferEnemyPorpertyLog.Log.get(Name)
	return null

#获取敌人掉落物
func get_dropped_item(target:String)->Array[droppedItemConfig]:
	if ReferEnemyPorpertyLog:
		var porperty:EnemyConfig = ReferEnemyPorpertyLog.Log.get(target)
		if porperty:
			return porperty.Drop
	return []

#掉落物品
func drop(Target:String, Pos:Vector2):
	var Items:Array[droppedItemConfig] = get_dropped_item(Target)
	var result:Array = []

	for Item:droppedItemConfig in Items:
		
		var id = Item.id
		var range_x = Item.range_x
		var range_y = Item.range_y
		var possbility = Item.possbility
		#判断能否掉落
		if randf_range(0, 100) > possbility:
			continue

		var amount = randi_range(range_x, range_y)
		result.append({
			"id":id, 
			"amount":amount
		})

	if result.size() == 0:
		return

	DroppedItemSystem.create_dropped_item(result, Pos)
