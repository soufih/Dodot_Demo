extends Node

#UI界面
var equipemntBarUI: BaseUI = null
var backpackBarUI: BaseUI = null
var pauseMenuUI: BaseUI = null
#玩家
var hero: HeroProperty

func _ready() -> void:
	equipemntBarUI =  UIManager.load_ui("uid://dg5jscvs3feh3", "UILayer")#装备栏UI
	backpackBarUI = UIManager.load_ui("uid://1s1kttvb6l7w", "UILayer") #物品栏UI
	pauseMenuUI =  UIManager.load_ui("uid://cyy1mus77qou1", "UILayer")#暂停菜单UI
	
	LevelGenerator.prepare_generating()
	LevelGenerator.generate_level(LevelInformation.get_level_info().level)

func _exit_tree() -> void:
	UIManager.ui_clear_stack()
	if equipemntBarUI:
		equipemntBarUI.queue_free()
	if backpackBarUI:
		backpackBarUI.queue_free()
	if pauseMenuUI:
		pauseMenuUI.queue_free()

	DataLoader.set_hero(null)
