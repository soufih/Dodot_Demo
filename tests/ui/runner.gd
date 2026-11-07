extends Node
## 真实 UIManager、窗口场景、输入事件及跨场景切换回归。
const SceneLoading = preload("res://Script/Gameplay/System/SceneLoader.gd")
var assertions := 0
var failures := 0
var scope: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	scope = get_parent()
	# 测试执行器跨场景存活，窗口仍归当前场景所有。
	reparent(get_tree().root)
	UIManager.configure_scene(scope, [UIId.PAUSE, UIId.SETTINGS, UIId.MAP, UIId.EQUIPMENT, UIId.INVENTORY, UIId.DEATH, UIId.END])
	for frame in range(3):
		await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ui-capture="):
			await _capture(arg.trim_prefix("--ui-capture="))
			get_tree().quit()
			return
	await _test_windows()
	await _test_requests_and_input()
	await _test_lifetime()
	await _test_map_and_inventory()
	await _test_result_and_failure()
	await _test_scene_transition()
	print("UI_MANAGEMENT_TEST_RESULT assertions=%d failures=%d" % [assertions, failures])
	get_tree().quit(0 if failures == 0 else 1)


func expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("UI_SPEC: " + message)


func _test_windows() -> void:
	var background := Button.new()
	scope.add_child(background)
	background.position = Vector2(8, 8)
	background.size = Vector2(120, 40)
	var clicks := {"count": 0}
	background.pressed.connect(func(): clicks.count += 1)
	background.grab_focus()
	await _click(Vector2(20, 20))
	expect(clicks.count == 1, "场景按钮基线可点击")
	clicks.count = 0
	var pause = UIManager.open(UIId.PAUSE)
	expect(pause != null and pause.is_node_ready(), "打开时挂载和 ready 已完成")
	expect(UIManager.is_open(UIId.PAUSE) and get_tree().paused, "暂停菜单实际暂停场景树")
	expect(get_viewport().gui_get_focus_owner() == null, "打开模态窗口清除下层焦点，不自动选中按钮")
	expect(UIManager.open(UIId.PAUSE) == pause and UIManager.UIList.size() == 1, "重复打开复用实例且不重复入栈")
	await _click(Vector2(20, 20))
	expect(clicks.count == 0, "模态界面阻止点击穿透到场景按钮")
	var copied := UIManager.UIList
	copied.clear()
	expect(UIManager.UIList.size() == 1, "兼容查询返回副本")
	var setting_button: Button = pause.get_node("PanelContainer/MarginContainer/VBoxContainer/Setting_Button")
	setting_button.grab_focus()
	UIManager.open(UIId.PAUSE)
	expect(get_viewport().gui_get_focus_owner() == setting_button, "重复打开窗口保留用户手动选择的控件")
	setting_button.pressed.emit()
	var settings = UIManager.get_ui(UIId.SETTINGS)
	expect(UIManager.UIList.size() == 2 and UIManager.ui_get_top() == settings, "菜单按钮通过注册表打开设置")
	expect(get_viewport().gui_get_focus_owner() == null, "打开设置不自动选择控件")
	expect(setting_button.mouse_filter == Control.MOUSE_FILTER_IGNORE and setting_button.focus_mode == Control.FOCUS_NONE, "下层模态窗口不可点击和聚焦")
	expect(pause.process_mode == Node.PROCESS_MODE_DISABLED, "下层脚本停止处理")
	await _escape()
	expect(not UIManager.is_open(UIId.SETTINGS) and UIManager.is_open(UIId.PAUSE) and get_tree().paused, "Esc 关闭设置后仍保持暂停")
	expect(get_viewport().gui_get_focus_owner() == null, "关闭设置不自动恢复原按钮焦点")
	expect(setting_button.mouse_filter != Control.MOUSE_FILTER_IGNORE, "下层窗口恢复交互")
	await _escape()
	expect(not get_tree().paused and UIManager.UIList.is_empty(), "最后一个暂停窗口关闭后恢复")
	expect(get_viewport().gui_get_focus_owner() == null, "关闭最后窗口不自动恢复场景焦点")
	await _click(Vector2(20, 20))
	expect(clicks.count == 1, "关闭最后模态后场景按钮可正常点击")
	expect(not UIManager.close(UIId.PAUSE), "重复关闭安全无副作用")
	for i in range(5):
		UIManager.open(UIId.SETTINGS)
		UIManager.close(UIId.SETTINGS)
	expect(settings.volume_slider.value_changed.get_connections().size() == 1, "缓存设置窗口不重复连接音量信号")
	expect(settings.process_mode == Node.PROCESS_MODE_DISABLED, "隐藏缓存不处理输入和轮询")
	var hud := BaseUI.new()
	scope.add_child(hud)
	hud.begin()
	hud.hide()
	hud.show()
	expect(UIManager.UIList.is_empty(), "未注册的 HUD 和内部控件不自动入栈")
	hud.queue_free()
	background.queue_free()


func _escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame


func _click(point: Vector2) -> void:
	# 无头窗口默认只有 64 像素，Input 入口使用窗口坐标，需应用拉伸变换。
	point = get_viewport().get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(event)
		await get_tree().process_frame


func _test_requests_and_input() -> void:
	var owner := Node.new()
	scope.add_child(owner)
	var input := InputController.new()
	input.process_mode = Node.PROCESS_MODE_PAUSABLE
	owner.add_child(input)
	Input.action_press("MoveLeft")
	expect(input.get_move_direction() == -1.0, "基线轮询可读取角色输入")
	input.buffer_action("Attack")
	var a := UIManager.acquire_request(owner, true, true, true)
	var b := UIManager.acquire_request(owner, false, true, true)
	expect(input.is_banned and input.get_move_direction() == 0.0 and input.buffered_actions.is_empty(), "锁生效时阻止轮询并清空动作缓冲")
	UIManager.open(UIId.PAUSE)
	UIManager.close(UIId.PAUSE)
	expect(get_tree().paused, "关闭 UI 不解除外部暂停")
	UIManager.release_request(a)
	expect(not get_tree().paused and UIManager.is_banned and input.is_banned, "只释放自己的暂停与输入请求")
	input.ban_input(true)
	UIManager.release_request(b)
	expect(not UIManager.is_banned and input.is_banned, "UI 解锁不覆盖角色自身禁用状态")
	input.ban_input(false)
	expect(not input.is_banned, "角色自身状态也可独立解除")
	Input.action_release("MoveLeft")
	UIManager.acquire_request(owner, true, true, true)
	UIManager.acquire_request(owner, false, true, true)
	owner.queue_free()
	await get_tree().process_frame
	expect(not get_tree().paused and not UIManager.has_blocking_ui(), "同一持有者的多个请求在离树时全部解锁")
	# 调试暂停也是外部请求，不得被关闭控制台或普通 UI 撤销。
	DebugTool.execute_command("game.pause on")
	UIManager.open(UIId.DEBUG)
	expect(UIManager.is_open(UIId.DEBUG) and UIManager.is_banned, "控制台统一参与输入汇总")
	expect(get_viewport().gui_get_focus_owner() == null, "打开控制台不自动聚焦输入框")
	await _escape()
	expect(not UIManager.is_open(UIId.DEBUG), "控制台未聚焦输入框时也可按 Esc 关闭")
	expect(get_tree().paused and not UIManager.is_banned, "关闭控制台保留调试暂停")
	DebugTool.execute_command("game.pause off")
	expect(not get_tree().paused, "调试暂停可独立释放")


func _test_lifetime() -> void:
	var config := UIConfig.new()
	config.id = &"fixture"
	config.scene_path = "res://tests/ui/fixture_ui.tscn"
	config.allow_multiple = true
	config.modal = true
	expect(UIManager.register_ui(config), "可注册独立窗口配置")
	var overlay := UIConfig.new()
	overlay.id = &"fixture_overlay"
	overlay.scene_path = config.scene_path
	overlay.layer = UIConfig.Layer.RESULT
	overlay.modal = true
	overlay.participates_in_back = false
	overlay.keep_alive = false
	expect(UIManager.register_ui(overlay), "可注册不参与普通返回栈的模态覆盖")
	var owner := Node.new()
	scope.add_child(owner)
	UIManager.configure_scene(owner, [&"fixture", overlay.id])
	var a = UIManager.open(&"fixture", {}, owner, "a")
	var b = UIManager.open(&"fixture", {}, owner, "b")
	expect(a != b and UIManager.UIList.size() == 2, "多实例标识分别管理")
	UIManager.activate(a)
	expect(UIManager.ui_get_top() == a and a.get_parent().get_child(-1) == a, "聚焦同步绘制和返回顺序")
	UIManager.close_top()
	expect(a.closes == 1 and UIManager.is_open(&"fixture", "b"), "关闭顶层只调用一次生命周期")
	a.show()
	expect(a.opens == 2 and UIManager.is_open(&"fixture", "a"), "旧 show 也经过打开钩子")
	a.queue_free()
	await get_tree().process_frame
	expect(UIManager.get_ui(&"fixture", "a") == null and UIManager.UIList.size() == 1, "外部释放时清理实例和栈")
	UIManager.open(overlay.id, {}, owner)
	expect(UIManager.close_top() and UIManager.is_open(&"fixture", "b") and UIManager.is_open(overlay.id), "不入普通返回栈的模态仍阻止 Esc 穿透")
	UIManager.close(overlay.id)
	UIManager.close_scope(owner)
	expect(UIManager.get_ui(&"fixture", "b") == null and not UIManager.has_blocking_ui(), "所属场景清理含隐藏缓存和输入请求")
	UIManager.configure_scene(owner, [&"fixture"])
	expect(UIManager.open(&"fixture", {"reject": true}, owner) == null, "绑定失败回滚本次实例")
	expect(UIManager.UIList.is_empty() and not UIManager.has_blocking_ui(), "绑定失败不残留栈和锁")
	owner.queue_free()
	await get_tree().process_frame


func _test_map_and_inventory() -> void:
	var map = UIManager.open(UIId.MAP)
	expect(map != null and map.get_parent().follow_viewport_enabled, "地图保留世界坐标画布")
	map.level_discription.show()
	UIManager.close_top()
	expect(UIManager.is_open(UIId.MAP) and not map.level_discription.visible, "地图先关闭内部关卡说明")
	map._on_level_1_button_down()
	UIManager.close(UIId.MAP)
	await get_tree().create_timer(0.65).timeout
	expect(not map.level_discription.visible and map.camera.zoom == Vector2.ONE, "关闭地图取消延迟显示与镜头动画")
	InventoryManager.create_container("ui_spec_grid", Vector2i(4, 3), InventoryManager.ServiceType.GRID)
	var inventory = UIManager.open(UIId.INVENTORY, {"container_id": "ui_spec_grid"})
	expect(inventory.windows.size() == 1 and not get_tree().paused and UIManager.gameplay_blocked, "背包工作区绑定业务容器且独立阻止角色输入")
	var view = inventory.windows[0]
	view.dragging = true
	UIManager.close_top()
	expect(UIManager.is_open(UIId.INVENTORY) and not view.dragging, "Esc 优先取消局部拖动，不直接关闭整个背包")
	view.dragging = true
	UIManager.open(UIId.SETTINGS)
	expect(not view.dragging, "上层模态取消背包窗口拖动")
	UIManager.close(UIId.SETTINGS)
	UIManager.close(UIId.INVENTORY)
	expect(InventoryManager.container_changed.get_connections().is_empty(), "关闭缓存背包解除窗口与画板订阅")
	expect(not InventoryManager.get_snapshot("ui_spec_grid").is_empty(), "关闭 UI 不删除业务容器")
	UIManager.open(UIId.INVENTORY, {"container_id": "ui_spec_grid"})
	expect(InventoryManager.container_changed.get_connections().size() == 2, "重开只重新绑定一组窗口订阅")
	UIManager.close(UIId.INVENTORY)
	InventoryManager.unregister_container("ui_spec_grid")


func _test_result_and_failure() -> void:
	UIManager.show_death_screen()
	var death = UIManager.get_ui(UIId.DEATH)
	expect(death != null and get_tree().paused, "死亡结果通过统一管理器暂停游戏")
	expect(UIManager.close_top() and UIManager.is_open(UIId.DEATH), "结果界面消费 Esc 且不可取消")
	expect(UIManager.open(UIId.SETTINGS) == null and UIManager.open(UIId.END) == null, "结果互斥并拒绝普通窗口")
	expect(UIManager.open(UIId.DEBUG) == null, "结果状态禁止打开调试覆盖")
	death.return_scene_path = ""
	death._on_confirm_pressed()
	expect(UIManager.is_open(UIId.LOADING), "返回动作创建常驻加载界面")
	print("EXPECTED_LOADING_FAILURE_BEGIN")
	for frame in range(4):
		await get_tree().process_frame
	print("EXPECTED_LOADING_FAILURE_END")
	expect(not UIManager.is_open(UIId.LOADING) and UIManager.is_open(UIId.DEATH), "加载失败仅关闭加载层并保留原结果界面")
	expect(not death.confirm_button.disabled and get_viewport().gui_get_focus_owner() == null, "失败恢复按钮，不自动聚焦确认按钮")
	expect(get_tree().paused and UIManager.gameplay_blocked, "失败后保留结果界面的暂停和输入锁")
	UIManager.close(UIId.DEATH)
	UIManager.show_end_screen()
	expect(UIManager.is_open(UIId.END) and get_tree().paused, "结算界面使用同一套暂停与生命周期")
	UIManager.close(UIId.END)


func _test_scene_transition() -> void:
	UIManager.open(UIId.PAUSE)
	var old_pause: WeakRef = weakref(UIManager.get_ui(UIId.PAUSE))
	var trace := {"early_unlock": false}
	var track_loading := func() -> void:
		if UIManager.is_open(UIId.LOADING) and not UIManager.gameplay_blocked:
			trace.early_unlock = true
	UIManager.state_changed.connect(track_loading)
	expect(SceneLoading.load_next_scene("res://Scene/Map/MainScene/MainScene.tscn", false) == OK, "加载入口接受真实目标场景")
	expect(SceneLoading.load_next_scene("res://Scene/Map/MainScene/MainScene.tscn", false) == ERR_BUSY, "重复加载返回忙碌状态")
	await get_tree().scene_changed
	await get_tree().process_frame
	expect(get_tree().current_scene.name == "MainScene" and not UIManager.is_open(UIId.LOADING), "跨场景加载成功并关闭常驻覆盖")
	expect(old_pause.get_ref() == null and UIManager.get_ui(UIId.PAUSE) == null, "旧场景释放包括隐藏的缓存窗口")
	expect(not get_tree().paused and not UIManager.has_blocking_ui(), "新场景不继承旧暂停和锁")
	expect(not trace.early_unlock, "加载完成前没有因旧场景释放而提前解除输入锁")
	UIManager.state_changed.disconnect(track_loading)
	expect(UIManager.open(UIId.MAP) == null, "主菜单不允许打开家园地图")
	var mainmenu := get_tree().current_scene.get_node("CanvasLayer/Mainmenu")
	mainmenu.on_setting_pressed()
	expect(UIManager.is_open(UIId.SETTINGS), "新场景设置入口仍可用")
	UIManager.close(UIId.SETTINGS)
	SceneLoading.load_next_scene(SceneLoading.HOME_SCENE_PATH, false)
	await get_tree().scene_changed
	await get_tree().process_frame
	expect(get_tree().current_scene.name == "Home" and UIManager.open(UIId.MAP) != null, "实际家园加载后重新注册窗口能力")
	UIManager.close(UIId.MAP)


func _capture(path: String) -> void:
	UIManager.open(UIId.PAUSE)
	UIManager.open(UIId.SETTINGS)
	for frame in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("UI_MANAGEMENT_CAPTURE_COMPLETE")
