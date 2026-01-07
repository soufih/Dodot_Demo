extends Node

@onready var startpoint:Marker2D = $Startpoint
#UI界面
var equipemntBarUI: BaseUI = null
var backpackBarUI: BaseUI = null
var pauseMenuUI: BaseUI = null
var warehouse:BaseUI = null
var equipmentEnhancementUI:BaseUI = null
var mapUI:BaseUI = null
#玩家
var hero: HeroProperty


func _enter_tree() -> void:
	equipemntBarUI = UIManager.load_ui("uid://dg5jscvs3feh3") #装备栏UI
	backpackBarUI = UIManager.load_ui("uid://1s1kttvb6l7w") #物品栏UI
	warehouse = UIManager.load_ui("uid://cd2xfe7rysnxr") #仓库UI
	equipmentEnhancementUI = UIManager.load_ui("uid://hmacpsbsf4q8") #装备强化界面
	pauseMenuUI = UIManager.load_ui("uid://cyy1mus77qou1")#暂停菜单UI
	mapUI = UIManager.load_ui("uid://baysbd0v7e3fm") #地图UI

func _ready() -> void:
	hero = load("res://Scene/Hero/Hero.tscn").instantiate()
	DataLoader.set_hero(hero)
	startpoint.add_child(hero)

func _exit_tree() -> void:
	equipemntBarUI.queue_free()
	backpackBarUI.queue_free()
	warehouse.queue_free()
	equipmentEnhancementUI.queue_free()
	pauseMenuUI.queue_free()
	mapUI.queue_free()

	DataLoader.set_hero(null)
