extends Node

#UI界面
var pauseMenuUI: BaseUI = null

func _ready() -> void:
	EnemyManager.load_enemy()
	pauseMenuUI =  UIManager.load_ui(Path.MENU_UI_SCENE, "UILayer")#暂停菜单UI

func _exit_tree() -> void:
	UIManager.ui_clear_list()
	if pauseMenuUI:
		pauseMenuUI.queue_free()

	DataLoader.set_hero(null)
