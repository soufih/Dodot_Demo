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
#func get_dropped_item(level:int, target:String)->Array[Vector3i]:
	#pass
