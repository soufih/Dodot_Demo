extends Node
## 运行真实角色测试台，通过实际按键与场景按钮验证完整链路，可选输出渲染截图。

const LAB = "res://Scene/Inventory/InventoryGameplayLab.tscn"
const DEFINITION = preload("res://Rescource/Data/Inventory/player_backpack.tres")
var checks = preload("res://tests/inventory/spec_context.gd").new()

## Autoload 初始化后再加载测试台，保持与 F6 运行相同的启动顺序。
func _ready() -> void:
	_run.call_deferred()

## 使用测试台自带的真实 Hero、掉落工厂和按钮，不替换角色输入或交互组件。
func _run() -> void:
	reparent(get_tree().root)
	checks.equal(get_tree().change_scene_to_file(LAB), OK, "加载正式接入测试台")
	for frame in range(90):
		await get_tree().physics_frame
		await get_tree().process_frame
	var lab := get_tree().current_scene
	var hero: HeroProperty = lab.get_node("Hero")
	checks.expect(not hero._InputController.is_banned, "真实角色启动后恢复游戏输入")
	checks.expect(hero.InteractBox.get_current_interactable() is PickupInteractable, "真实角色检测到测试台材料")
	await _capture("--gameplay-world-capture=")
	await _key(KEY_E)
	checks.equal(_total(), 250, "真实角色按 E 拾取全部材料")
	checks.equal(InventoryManager.get_snapshot(DEFINITION.container_id).items.size(), 3, "正式背包按上限拆为三栈")
	lab.get_node("HUD/Panel/Margin/Rows/Sword").pressed.emit()
	for frame in range(3):
		await get_tree().physics_frame
		await get_tree().process_frame
	await _key(KEY_E)
	checks.equal(_total(), 251, "测试台按钮生成的正式武器可以拾取")
	checks.equal(InventoryManager.get_snapshot(DEFINITION.container_id).items.size(), 4, "背包包含三栈材料和一把多格武器")
	await _key(KEY_TAB)
	checks.expect(UIManager.is_open(UIId.INVENTORY), "真实角色 Tab 打开正式背包窗口")
	checks.equal(UIManager.get_ui(UIId.INVENTORY).windows[0].container_id, DEFINITION.container_id, "窗口绑定真实角色背包")
	await _capture("--gameplay-capture=")
	await _key(KEY_TAB)
	checks.expect(not UIManager.is_open(UIId.INVENTORY) and not hero._InputController.is_banned, "真实角色关闭背包后恢复输入")
	lab.get_node("HUD/Panel/Margin/Rows/Reset").pressed.emit()
	checks.equal(_total(), 0, "测试台重置按钮开始空背包会话")
	print("INVENTORY_GAMEPLAY_LAB_TEST_RESULT assertions=%d failures=%d" % [checks.assertions, checks.failures])
	get_tree().quit(0 if checks.failures == 0 else 1)

## 仅显式传入输出路径时渲染截图，普通 headless 回归无需等待渲染信号。
func _capture(prefix: String) -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			await RenderingServer.frame_post_draw
			checks.equal(get_tree().root.get_texture().get_image().save_png(argument.trim_prefix(prefix)), OK, "保存真实场景截图")

## 汇总正式容器数量，核对场景交互后的实际业务状态。
func _total() -> int:
	var total := 0
	for record in InventoryManager.get_snapshot(DEFINITION.container_id).items.values():
		total += record.instance.quantity
	return total

## 注入按下和释放两个真实事件，覆盖 Hero 的现有输入路由。
func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
