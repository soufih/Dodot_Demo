extends Node



#UI界面
var inventoryUI: BaseUI = null
var pauseMenuUI: BaseUI = null
#玩家
var hero: HeroProperty

func _init() -> void:
	EnemyManager.load_enemy()
	inventoryUI = UIManager.load_ui("uid://m6qc3rqc8yuq", "UILayer") #背包UI
	pauseMenuUI =  UIManager.load_ui("uid://cyy1mus77qou1", "UILayer")#暂停菜单UI

func _exit_tree() -> void:
	UIManager.ui_clear_list()
	if inventoryUI:
		inventoryUI.queue_free()
	if pauseMenuUI:
		pauseMenuUI.queue_free()

	DataLoader.set_hero(null)
