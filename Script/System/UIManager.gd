extends Node

var UIStack: Array[BaseUI] = []
var tmp_slot:TmpSlot
var UILayer: CanvasLayer

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

	var Backpack:BaseUI = preload("uid://b12ujb2p2b4v").instantiate()
	Backpack.hide()
	UILayer.add_child(Backpack)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		ui_cancel()
	
	if event.is_action_pressed("OpenBackpack"):
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

##关闭最上层UI
func ui_cancel():
	if UIStack.size() > 0:
		var top_ui: BaseUI = UIStack[UIStack.size() - 1]
		if top_ui.has_method("ui_close"):
			top_ui.hide()
	else: #栈为空时打开暂停菜单
		open_pause_menu()

##打开暂停菜单
func open_pause_menu():
	print("Open Pause Menu")

##打开/关闭背包
func ui_open_backpack():
	var backpack = UILayer.get_node("Backpack")
	if backpack:
		backpack.visible = !backpack.visible
