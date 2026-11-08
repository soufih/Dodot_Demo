extends Node

const ID := "crafting_ui_warehouse"
var t = preload("res://tests/inventory/spec_context.gd").new()
var window: BaseUI
var view

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(1152, 648)
	UIManager.configure_scene(self, [UIId.EQUIPMENT, UIId.SETTINGS])
	InventoryManager.create_container(ID, Vector2i(6, 5), InventoryManager.ServiceType.WAREHOUSE)
	InventoryManager.create_container("crafting_ui_bag", Vector2i(4, 4), InventoryManager.ServiceType.GRID)
	InventoryManager.add_to_container("crafting_ui_bag", 20, 50, Vector2i.ZERO)
	var bag := t.value(InventoryManager.get_snapshot("crafting_ui_bag"))
	var base_connections := InventoryManager.container_changed.get_connections().size()
	window = UIManager.open(UIId.EQUIPMENT, {"warehouse_id": ID}, self)
	t.expect(window != null, "正式合成场景可经 UIManager 打开")
	if window == null:
		_finish()
		return
	view = window.compound_ui
	await _frames()
	t.equal(view.recipes.item_count, 5, "正式目录五份配方显示完整")
	_select(&"material_21")
	t.expect(view.confirm.disabled and view.status.text.contains("不足"), "背包有材料仍显示仓库材料不足")
	var missing_tooltip = view.materials.get_child(0)._make_custom_tooltip("")
	t.expect(view.materials.get_child(0).get_node("Margin/Row/Quantity").text == "0 / 5"
		and missing_tooltip.scene_file_path == "res://UI/Crafting/material_tooltip.tscn"
		and missing_tooltip.get_node("Margin/Content/Header/MaterialName").text == ResourceManager.get_item_name(20)
		and missing_tooltip.get_node("Margin/Content/Description").text == ResourceManager.get_item_discription(20)
		and missing_tooltip.get_node("Margin/Content/Missing").text == "缺少：5", "材料卡片使用独立悬浮场景，填充名称、描述和缺少量")
	missing_tooltip.free()
	InventoryManager.add_to_container(ID, 20, 15, Vector2i.ZERO)
	t.expect(not view.confirm.disabled, "仓库添加材料后按钮实时启用")
	t.expect(view.limit.text.contains("3 次"), "显示材料支持的次数上限")
	view.times.value = 2
	var enough_tooltip = view.materials.get_child(0)._make_custom_tooltip("")
	t.expect(view.materials.get_child(0).get_node("Margin/Row/Quantity").text == "15 / 10"
		and enough_tooltip.get_node("Margin/Content/Owned").text == "仓库拥有：15"
		and enough_tooltip.get_node("Margin/Content/Required").text == "本次需要：10"
		and enough_tooltip.get_node("Margin/Content/Missing").text == "缺少：0", "库存与次数变化同步刷新卡片数量和悬浮场景")
	enough_tooltip.free()
	t.expect(view.products.get_child(0).get_node("Margin/Row/Quantity").text == "×2"
		and view.products.get_child(0).get_node("Margin/Row/Icon").texture == ResourceManager.get_item_icon(21)
		and view.recipes.get_item_text(1) == "%s ×1" % ResourceManager.get_item_name(21), "左侧总览保留名称，右侧产物仅显示图标和数量")
	await _frames()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crafting-tooltip-capture="):
			await _capture_material_tooltip(arg.trim_prefix("--crafting-tooltip-capture="))
			return
		if arg.begins_with("--crafting-capture="):
			await RenderingServer.frame_post_draw
			var path := arg.trim_prefix("--crafting-capture=")
			t.equal(get_viewport().get_texture().get_image().save_png(path), OK, "导出实际渲染截图")
			get_window().size = Vector2i(800, 600)
			await _frames()
			await RenderingServer.frame_post_draw
			t.expect(get_viewport().get_visible_rect().encloses(view.confirm.get_global_rect()), "小窗口确认按钮仍在可见范围")
			t.equal(get_viewport().get_texture().get_image().save_png(path.get_basename() + "-small.png"), OK, "导出小窗口渲染截图")
			# 截图模式只准备布局；隐藏原生窗口缩放后不继续派发合成鼠标事件。
			UIManager.close(UIId.EQUIPMENT)
			InventoryManager.unregister_container(ID)
			InventoryManager.unregister_container("crafting_ui_bag")
			_finish()
			return
	await _test_material_navigation()
	# 使用真实 GUI 输入触发按钮，覆盖节点绑定与点击分发。
	await _click(view.confirm.get_global_rect().get_center())
	t.equal(_count(20), 5, "点击确认按次数扣除仓库材料")
	t.equal(_count(21), 2, "点击确认将产物放回仓库")
	t.expect(view.status.text.contains("成功"), "界面显示提交成功反馈")
	t.expect(view.confirm.disabled, "合成后剩余材料不足两次，按钮立即禁用")
	t.equal(t.value(InventoryManager.get_snapshot("crafting_ui_bag")), bag, "UI 合成不改变背包")
	view.times.value = 1
	t.expect(not view.confirm.disabled, "调整回可执行次数后恢复按钮")
	# 模拟旧预览：不依赖按钮禁用，正式命令仍重新校验库存。
	InventoryManager.remove_from_container(ID, Vector2i.ZERO)
	view.confirm.pressed.emit()
	t.equal(_count(21), 2, "旧 UI 操作不会额外生成产物")
	t.expect(view.status.text.contains("不足"), "旧操作显示实际失败原因")
	view.available_only.button_pressed = true
	view.available_only.toggled.emit(true)
	t.equal(view.recipes.item_count, 0, "材料筛选不将背包数量计入")
	t.expect(view.confirm.disabled, "空列表清空详情并禁用按钮")
	view.available_only.button_pressed = false
	view.available_only.toggled.emit(false)
	view.category.select(1)
	view.category.item_selected.emit(1)
	t.equal(view.recipes.item_count, 3, "武器分类根据产物类型筛选")
	UIManager.close(UIId.EQUIPMENT)
	t.equal(InventoryManager.container_changed.get_connections().size(), base_connections, "关闭解绑仓库信号")
	t.equal(_count(21), 2, "关闭不清空仓库产物")
	for index in range(3):
		window = UIManager.open(UIId.EQUIPMENT, {"warehouse_id": ID}, self)
		t.equal(InventoryManager.container_changed.get_connections().size(), base_connections + 1, "重新打开不重复订阅")
		UIManager.close(UIId.EQUIPMENT)
	window = UIManager.open(UIId.EQUIPMENT, {"warehouse_id": "crafting_ui_bag"}, self)
	view = window.compound_ui
	view.category.select(0)
	view.refresh()
	t.expect(view.confirm.disabled and view.status.text.contains("不支持"), "窗口拒绝普通背包作为材料与产物容器")
	UIManager.close(UIId.EQUIPMENT)
	window = UIManager.open(UIId.EQUIPMENT, {"warehouse_id": "missing_warehouse"}, self)
	view = window.compound_ui
	t.expect(view.confirm.disabled and view.status.text.contains("未注册"), "仓库不存在时显示原因，不偷偷创建仓库")
	UIManager.close(UIId.EQUIPMENT)
	# 正式 K 键动作沿用原窗口入口，默认绑定家园仓库。
	var action := InputEventAction.new()
	action.action = &"OpenEquipmentEnhancement"
	action.pressed = true
	Input.parse_input_event(action)
	await _frames()
	window = UIManager.get_ui(UIId.EQUIPMENT)
	t.expect(UIManager.is_open(UIId.EQUIPMENT) and window.compound_ui.warehouse_id == "warehouse_home", "K 键动作默认打开家园仓库合成")
	UIManager.close(UIId.EQUIPMENT)
	InventoryManager.unregister_container(ID)
	InventoryManager.unregister_container("crafting_ui_bag")
	_finish()

## 实际鼠标悬浮触发原生提示工厂，在嵌入子窗口模式下捕获完整显示结果。
func _capture_material_tooltip(path: String) -> void:
	get_window().gui_embed_subwindows = true
	var motion := InputEventMouseMotion.new()
	motion.position = view.materials.get_child(0).get_node("Margin/Row/Icon").get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var popups: Array[Window] = get_window().get_embedded_subwindows()
	t.expect(popups.any(func(popup: Window) -> bool: return popup.visible), "真实悬浮创建可见的提示窗口")
	t.equal(get_viewport().get_texture().get_image().save_png(path), OK, "导出独立材料悬浮场景的实际渲染截图")
	UIManager.close(UIId.EQUIPMENT)
	InventoryManager.unregister_container(ID)
	InventoryManager.unregister_container("crafting_ui_bag")
	_finish()

func _test_material_navigation() -> void:
	var before := t.value(InventoryManager.get_snapshot(ID))
	var original_window := window
	view.category.select(1)
	view.category.item_selected.emit(1)
	_select(&"sword_10")
	view.times.value = 3
	await _frames()
	var craftable_tooltip = view.materials.get_child(0)._make_custom_tooltip("")
	t.expect(craftable_tooltip.get_node("Margin/Content/Navigation").visible, "可合成材料的独立悬浮场景显示点击跳转提示")
	craftable_tooltip.free()
	await _click(view.materials.get_child(0).get_global_rect().get_center())
	var raw_tooltip = view.materials.get_child(0)._make_custom_tooltip("")
	t.expect(view.selected_recipe == &"material_21"
		and not raw_tooltip.get_node("Margin/Content/Navigation").visible, "点击材料原地跳转，没有配方的下层材料不提示跳转")
	raw_tooltip.free()
	t.expect(UIManager.get_ui(UIId.EQUIPMENT) == original_window and view.warehouse_id == ID,
		"跳转复用原窗口和仓库，不新开窗口")
	t.expect(view.category.get_selected_id() == ENUM.ItemType.None and view.times.value == 1,
		"目标被分类隐藏时解除筛选，新配方次数重置为一次")
	t.equal(view.recipes.get_item_metadata(view.recipes.get_selected_items()[0]), &"material_21", "左侧总览同步选中目标配方")
	await _click(view.materials.get_child(0).get_global_rect().get_center())
	t.equal(view.selected_recipe, &"material_21", "原材料没有配方时点击不跳转")
	t.equal(t.value(InventoryManager.get_snapshot(ID)), before, "浏览与点击材料不消耗或生成物品")
	# 仓库只有成品材料时，武器可合成，而材料自身的配方被材料筛选隐藏。
	InventoryManager.add_to_container(ID, 21, 1, Vector2i(2, 0))
	InventoryManager.add_to_container(ID, 22, 2, Vector2i(4, 0))
	InventoryManager.add_to_container(ID, 23, 4, Vector2i(5, 0))
	InventoryManager.remove_from_container(ID, Vector2i.ZERO)
	view.available_only.button_pressed = true
	view.available_only.toggled.emit(true)
	_select(&"sword_10")
	await _frames()
	await _click(view.materials.get_child(0).get_global_rect().get_center())
	t.expect(view.selected_recipe == &"material_21" and not view.available_only.button_pressed,
		"材料不足的目标配方仍可查看，自动解除材料筛选")
	t.expect(view.confirm.disabled, "跳转到缺料配方只允许浏览，不能直接合成")
	_select(&"sword_10")
	await _frames()
	await _click(view.materials.get_child(2).get_global_rect().get_center())
	t.equal(view.selected_recipe, &"material_23", "点击另一种材料跳转到对应配方")
	await _click(view.materials.get_child(0).get_global_rect().get_center())
	t.equal(view.selected_recipe, &"material_23", "下一层没有配方的材料仍保持当前页面")
	InventoryManager.remove_from_container(ID, Vector2i(2, 0))
	InventoryManager.remove_from_container(ID, Vector2i(4, 0))
	InventoryManager.remove_from_container(ID, Vector2i(5, 0))
	InventoryManager.add_to_container(ID, 20, 15, Vector2i.ZERO)
	_select(&"material_21")
	view.times.value = 2
	await _frames()

func _select(id: StringName) -> void:
	for index in range(view.recipes.item_count):
		if view.recipes.get_item_metadata(index) == id:
			view.recipes.select(index)
			view.recipes.item_selected.emit(index)
			return
	t.expect(false, "配方应当存在：%s" % id)

func _count(id: int) -> int:
	var counts := WarehouseManager.get_item_count(ID, id)
	return counts.payload if counts.is_ok() else -1

func _frames() -> void:
	for index in range(3):
		await get_tree().process_frame

func _click(pos: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	Input.parse_input_event(motion)
	await _frames()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = pos
		event.global_position = pos
		Input.parse_input_event(event)
		await _frames()

func _finish() -> void:
	print("CRAFTING_UI_TEST_RESULT assertions=%d failures=%d" % [t.assertions, t.failures])
	get_tree().quit(0 if t.failures == 0 else 1)
