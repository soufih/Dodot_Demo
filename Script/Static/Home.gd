extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

@onready var startpoint:Marker2D = $Startpoint
#UI界面
var pauseMenuUI: BaseUI = null
var equipmentEnhancementUI:BaseUI = null
var mapUI:BaseUI = null
#玩家
var hero: HeroProperty


func _enter_tree() -> void:
	equipmentEnhancementUI = UIManager.load_ui(Path.EQUIPMENT_ENHANCEMENT_UI_SCENE, "UILayer") #装备强化界面
	pauseMenuUI = UIManager.load_ui(Path.MENU_UI_SCENE, "UILayer")#暂停菜单UI
	mapUI = UIManager.load_ui(Path.MAP_SCENE, "flotUIlayer") #地图UI

func _ready() -> void:
	hero = SceneLoading.get_scene(SceneLoading.HERO_SCENE_PATH).instantiate()
	DataLoader.set_hero(hero)
	startpoint.add_child(hero)

func _exit_tree() -> void:
	UIManager.ui_clear_list()
	if equipmentEnhancementUI:
		equipmentEnhancementUI.queue_free()
	if pauseMenuUI:
		pauseMenuUI.queue_free()
	if pauseMenuUI:
		mapUI.queue_free()

	DataLoader.set_hero(null)
