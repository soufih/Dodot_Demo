extends Node

var UIStack: Array[BaseUI] = []
var tmp_slot:TmpSlot
var UILayer: CanvasLayer
var is_paused: bool = false

var setting_panel_instance: BaseUI= null


func _ready() -> void:
	load_ui_layer_config()
	
	
	load_ui("uid://dg5jscvs3feh3") #装备栏UI
	load_ui("uid://1s1kttvb6l7w") #物品栏UI
	load_ui("uid://cyy1mus77qou1")#暂停菜单UI
	setting_panel_instance = load_ui("uid://di38xxftqwhae") ##加载设置面板

##加载UI层配置
func load_ui_layer_config():
	var TmpSlotLayer = CanvasLayer.new()
	UILayer = CanvasLayer.new()
	
	
	add_child(TmpSlotLayer)
	add_child(UILayer)
	
	TmpSlotLayer.layer = 100
	UILayer.layer = 99

	tmp_slot = preload("uid://bb4quhyltqxmu").instantiate()
	TmpSlotLayer.add_child(tmp_slot)

	# var Backpack:BaseUI = preload("uid://b12ujb2p2b4v").instantiate()
	# Backpack.hide()
	# UILayer.add_child(Backpack)

##加载UI
func load_ui(ui_path: String) -> BaseUI:
	var ui_scene: PackedScene = load(ui_path)
	var ui_instance: BaseUI = ui_scene.instantiate()
	UILayer.add_child(ui_instance)
	ui_instance.hide()
	return ui_instance


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		ui_cancel()
	
	if event.is_action_pressed("OpenBackpack")&& !is_paused:
		ui_open_backpack()

##UIStack新增元素时调用
func ui_add_to_stack(ui: BaseUI) -> void:
	UIStack.append(ui)
	print("UI Stack:",UIStack)

##移除UI栈顶元素
func ui_pop_from_stack() -> void:
	if UIStack.size() > 0:
		UIStack.pop_back()
	print("UI Stack:",UIStack)

##获取UI栈顶元素
func ui_get_top() -> BaseUI:
	if UIStack.size() > 0:
		return UIStack[UIStack.size() - 1]
	return null

##清空UI栈
func ui_clear_stack() -> void:
	UIStack.clear()

##关闭最上层UI
func ui_cancel():
	if UIStack.size() > 0:
		var top_ui: BaseUI = UIStack[UIStack.size() - 1]
		top_ui.hide()
	else: #栈为空时打开暂停菜单
		open_pause_menu()

##打开暂停菜单
func open_pause_menu():
	var pause_menu = UILayer.get_node("menu_ui") as BaseUI
	if pause_menu:
		pause_menu.visible = !pause_menu.visible
		is_paused = pause_menu.visible


##打开/关闭背包
func ui_open_backpack():
	# var backpack_ui = UILayer.get_node("Backpack") as BaseUI
	# if backpack_ui:
	# 	backpack_ui.visible = !backpack_ui.visible

	var item_bar = UILayer.get_node("item_bar") as BaseUI
	if item_bar:
		item_bar.visible = !item_bar.visible
	
	var equipment_bar = UILayer.get_node("equipment_bar") as BaseUI
	if equipment_bar:
		equipment_bar.visible = !equipment_bar.visible
