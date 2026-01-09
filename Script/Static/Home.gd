extends Node

@onready var startpoint:Marker2D = $Startpoint
#UI界面
var inventoryUI: BaseUI = null
var pauseMenuUI: BaseUI = null
var warehouse:BaseUI = null
var equipmentEnhancementUI:BaseUI = null
var mapUI:BaseUI = null
#玩家
var hero: HeroProperty


func _enter_tree() -> void:
	inventoryUI = UIManager.load_ui("uid://m6qc3rqc8yuq", "UILayer") #背包UI
	warehouse = UIManager.load_ui("uid://cd2xfe7rysnxr", "UILayer") #仓库UI
	equipmentEnhancementUI = UIManager.load_ui("uid://hmacpsbsf4q8", "UILayer") #装备强化界面
	pauseMenuUI = UIManager.load_ui("uid://cyy1mus77qou1", "UILayer")#暂停菜单UI
	mapUI = UIManager.load_ui("uid://baysbd0v7e3fm", "flotUIlayer") #地图UI

func _ready() -> void:
	hero = load("res://Scene/Hero/Hero.tscn").instantiate()
	DataLoader.set_hero(hero)
	startpoint.add_child(hero)

func _exit_tree() -> void:
	UIManager.ui_clear_stack()
	if inventoryUI:
		inventoryUI.queue_free()
	if warehouse:
		warehouse.queue_free()
	if equipmentEnhancementUI:
		equipmentEnhancementUI.queue_free()
	if pauseMenuUI:
		pauseMenuUI.queue_free()
	if pauseMenuUI:
		mapUI.queue_free()

	DataLoader.set_hero(null)
