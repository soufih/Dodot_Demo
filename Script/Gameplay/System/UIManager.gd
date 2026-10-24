extends Node

const SceneLoading = preload(Path.SCENE_LOADER_SCRIPT)

var UIList: Array[BaseUI] = []
var UILayer: CanvasLayer
var flotUIlayer: CanvasLayer
var is_paused: bool = false
var is_banned:bool = false
var death_ui: BaseUI
var end_ui: BaseUI

func _ready() -> void:
	load_ui_layer_config()
	SignalBus.player_death.connect(show_death_screen)

##加载UI层配置
func load_ui_layer_config():
	UILayer = CanvasLayer.new()
	UILayer.name = "UILayer"
	flotUIlayer = CanvasLayer.new()
	flotUIlayer.name = "flotUIlayer"
	flotUIlayer.follow_viewport_enabled = true
	
	add_child(UILayer)
	add_child(flotUIlayer)	
	
	UILayer.layer = 99
	flotUIlayer.layer = 101

##加载UI
func load_ui(ui_path: String, layer: String) -> BaseUI:
	if !UILayer:
		return null	
	var ui_scene := SceneLoading.get_scene(ui_path)
	if ui_scene == null:
		return null
	var ui_instance: BaseUI = ui_scene.instantiate()
	ui_instance.hide()

	if get_node(layer):
		get_node(layer).call_deferred("add_child",ui_instance)

	return ui_instance


func _input(event: InputEvent) -> void:
	if is_banned or is_instance_valid(death_ui) or is_instance_valid(end_ui):
		return
	
	if event.is_action_pressed("ui_cancel"):
		ui_cancel()
	
	if is_paused:
		return

	if event.is_action_pressed("OpenEquipmentEnhancement"):
		ui_open_equipment_enhancement()

	if event.is_action_pressed("OpenMap"):
		ui_open_map()

func ban_ui_input():
	is_banned = true

func use_ui_input():
	is_banned = false

##移除UI列表中的UI
func ui_remove_from_list(ui: BaseUI) -> void:
	if UIList.has(ui):
		UIList.erase(ui)

##UIList新增元素时调用
func ui_add_to_list(ui: BaseUI) -> void:
	UIList.append(ui)

##移除UI列表顶元素
func ui_pop_from_list() -> void:
	if UIList.size() > 0:
		UIList.pop_back()

##获取UI列表顶元素
func ui_get_top() -> BaseUI:
	if UIList.size() > 0:
		return UIList[UIList.size() - 1]
	return null

##清空UI列表
func ui_clear_list() -> void:
	UIList.clear()

##关闭所有UI
func ui_close_all():
	for ui in UIList.duplicate():
		if ui:
			ui.hide()
	UIList.clear()


func show_death_screen() -> void:
	if is_instance_valid(death_ui) or is_instance_valid(end_ui) or get_tree().current_scene == null:
		return
	ui_close_all()
	is_paused = false
	var scene := SceneLoading.get_scene(Path.DEATH_UI_SCENE)
	if scene == null:
		return
	death_ui = scene.instantiate() as BaseUI
	var layer := CanvasLayer.new()
	layer.name = "DeathLayer"
	layer.layer = 110
	get_tree().current_scene.add_child(layer)
	layer.add_child(death_ui)


func show_end_screen() -> void:
	if is_instance_valid(end_ui) or is_instance_valid(death_ui) or get_tree().current_scene == null:
		return
	var scene := SceneLoading.get_scene(Path.END_UI_SCENE)
	if scene == null:
		return
	ui_close_all()
	is_paused = false
	end_ui = scene.instantiate() as BaseUI
	var layer := CanvasLayer.new()
	layer.name = "EndLayer"
	layer.layer = 110
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(layer)
	layer.add_child(end_ui)

##关闭最上层UI
func ui_cancel():
	if is_instance_valid(death_ui) or is_instance_valid(end_ui):
		return
	if UIList.size() > 0:
		var top_ui: BaseUI = UIList[UIList.size() - 1]
		if top_ui:
			top_ui.hide()
			is_paused = false
	else: #列表为空时打开暂停菜单
		open_pause_menu()


##打开暂停菜单
func open_pause_menu():
	if !UILayer.has_node("menu_ui"):
		return
	var pause_menu = UILayer.get_node("menu_ui") as BaseUI
	if pause_menu:
		pause_menu.visible = !pause_menu.visible
		is_paused = pause_menu.visible

##打开/关闭装备强化界面
func ui_open_equipment_enhancement():
	if !UILayer.has_node("equipment_enhancement_ui"):
		return
	var equipment_enhancement_ui = UILayer.get_node("equipment_enhancement_ui") as BaseUI
	if equipment_enhancement_ui:
		equipment_enhancement_ui.visible = !equipment_enhancement_ui.visible


func ui_open_map():
	if !flotUIlayer.has_node("map_ui"):
		return
	var map_ui = flotUIlayer.get_node("map_ui") as BaseUI
	if map_ui:
		map_ui.visible = !map_ui.visible
