extends Node

#UI界面
var inventoryUI: BaseUI = null
var pauseMenuUI: BaseUI = null

func _ready() -> void:
	EnemyManager.load_enemy()
	inventoryUI = UIManager.load_ui(Path.INVENTORY_UI_SCENE, "UILayer") #背包UI
	pauseMenuUI =  UIManager.load_ui(Path.MENU_UI_SCENE, "UILayer")#暂停菜单UI

func _exit_tree() -> void:
	UIManager.ui_clear_list()
	if inventoryUI:
		inventoryUI.queue_free()
	if pauseMenuUI:
		pauseMenuUI.queue_free()

	DataLoader.set_hero(null)
