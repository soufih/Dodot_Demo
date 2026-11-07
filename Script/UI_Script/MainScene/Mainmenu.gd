extends BaseUI

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)
const PLAYER_BACKPACK = preload("res://Rescource/Data/Inventory/player_backpack.tres")
const PLAYER_EQUIPMENT = preload("res://Rescource/Data/Inventory/player_equipment.tres")
const HOME_WAREHOUSE = preload("res://Rescource/Data/Inventory/home_warehouse.tres")

@onready var start_button = $ButtonContainer/gamestart
@onready var setting_button = $ButtonContainer/setting
@onready var quit_button = $ButtonContainer/quit

func _ready() -> void:
	start_button.pressed.connect(on_start_pressed)
	setting_button.pressed.connect(on_setting_pressed)
	quit_button.pressed.connect(on_quit_pressed)
	UIManager.configure_scene(UIManager.scene_owner(self), [UIId.SETTINGS])


## 新游戏开始前重建背包、装备与家园仓库；普通切关继续绑定原会话容器。
func on_start_pressed():
	# 新游戏明确重置；切关、返回家园和重建角色继续复用既有会话。
	var initialized := PlayerInventorySession.start_new(PLAYER_BACKPACK, InventoryManager)
	if initialized.is_ok():
		initialized = PlayerInventorySession.start_new(PLAYER_EQUIPMENT, InventoryManager)
	if initialized.is_ok():
		initialized = PlayerInventorySession.start_new(HOME_WAREHOUSE, InventoryManager)
	if not initialized.is_ok():
		push_error(initialized.message)
		return
	SceneLoading.load_next_scene(SceneLoading.HOME_SCENE_PATH)


func on_setting_pressed():
	UIManager.open(UIId.SETTINGS, {}, UIManager.scene_owner(self))


func on_quit_pressed():
	get_tree().quit()
