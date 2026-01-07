extends Node

var UIStack: Array[BaseUI] = []
var tmp_slot:TmpSlot
var UILayer: CanvasLayer
var is_paused: bool = false


func _ready() -> void:
	load_ui_layer_config()

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


##加载UI
func load_ui(ui_path: String) -> BaseUI:
	if !UILayer:
		return null	
	var ui_scene: PackedScene = load(ui_path)
	var ui_instance: BaseUI = ui_scene.instantiate()
	
	UILayer.call_deferred("add_child",ui_instance)
	ui_instance.hide()
		
	return ui_instance


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		ui_cancel()
	
	if is_paused:
		return

	if event.is_action_pressed("OpenBackpack"):
		ui_open_backpack()

	if event.is_action_pressed("OpenWarehouse"):
		ui_open_warehouse()
	
	if event.is_action_pressed("OpenEquipmentEnhancement"):
		ui_open_equipment_enhancement()

	if event.is_action_pressed("OpenMap"):
		ui_open_map()
	
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
		if top_ui:
			top_ui.hide()
			is_paused = false
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
	var item_bar = UILayer.get_node("item_bar") as BaseUI
	var equipment_bar = UILayer.get_node("equipment_bar") as BaseUI

	if item_bar:
		item_bar.visible = !item_bar.visible

	if equipment_bar:
		equipment_bar.visible = !equipment_bar.visible

##打开/关闭仓库
func ui_open_warehouse():
	var warehouse_ui = UILayer.get_node("warehouse_ui") as BaseUI
	if warehouse_ui:
		warehouse_ui.visible = !warehouse_ui.visible

##打开/关闭装备强化界面
func ui_open_equipment_enhancement():
	var equipment_enhancement_ui = UILayer.get_node("equipment_enhancement_ui") as BaseUI
	if equipment_enhancement_ui:
		equipment_enhancement_ui.visible = !equipment_enhancement_ui.visible

func ui_open_map():
	var map_ui = UILayer.get_node("map_ui") as BaseUI
	if map_ui:
		map_ui.visible = !map_ui.visible
