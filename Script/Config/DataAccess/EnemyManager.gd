extends Node

var ReferEnemyPorpertyLog:EnemyPorpertyLog

##加载敌人数据
func load_enemy():
	load_enemy_porperty()

#加载敌人属性列表
func load_enemy_porperty():
	if ReferEnemyPorpertyLog != null:
		return
	ReferEnemyPorpertyLog = load(Path.ENEMY_PORPERTY_CATALOG_RESOURCE) as EnemyPorpertyLog
	if !ReferEnemyPorpertyLog:
		push_error("ERRO!WHEN LOAD ENEMY PORPERTY")

#获取敌人
func get_enemies_of_level(level:int)->Array:
	var enemies:Array = []
	if ReferEnemyPorpertyLog:
		var result:Dictionary = ReferEnemyPorpertyLog.Log
		if !result:
			return enemies
		for enemy in result:
			if result[enemy].Habitat == level:
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
