## 管理人物的技能获取/移除、资源技能触发和状态冷却，不直接调用状态机转化函数。
## 获得性属性能力只在获取/移除时应用效果；对应动作由输入节点和人物状态执行。
class_name SkillController
extends Node

## 资源技能开始执行时通知；只应用 acquire_effects 的能力不会触发此信号。
signal skill_started(id: StringName)
## 资源技能执行结束时通知，cancelled 区分正常结束和中断。
signal skill_finished(id: StringName, cancelled: bool)
## owned_skills 增减时通知；一次性记录和瞬时技能不触发此信号。
signal skills_changed

## 人物初始化时自动获取的技能 ID，配置从 ResourceManager 查询。
@export var initial_skills: Array[StringName] = []
## 获得性动作的状态路径 → 技能 ID；路径相对此节点，冷却时长来自技能资源。
@export var state_skill_map: Dictionary[NodePath, StringName] = {}
## 所有技能统一按 ID 保存物理 Timer；移除技能不会重置已有冷却。
var skill_timer_map: Dictionary[StringName, Timer] = {}
var _state_skill_ids: Dictionary[BaseState, StringName] = {}
## ACQUIRED 和 CONTINUOUS 的已获得表；一次性执行记录不会在移除时清空。
var owned_skills: Dictionary[StringName, SkillRuntime] = {}
## 本控制器生命周期内已执行的一次性能力；不属于存档持久化数据。
var once_records: Dictionary[StringName, bool] = {}
## 相对人物的“节点路径:信号名”映射到技能 ID 列表，顺序为获取顺序。
var trigger_skill_map: Dictionary[NodePath, Array] = {}
## 信号来源使用弱引用，断开监听时允许来源节点已经被释放。
var _sources: Dictionary[NodePath, WeakRef] = {}
## 保存连接时使用的 Callable，确保移除时能准确断开同一个回调。
var _callbacks: Dictionary[NodePath, Callable] = {}
## 当前持续性资源技能的单次执行上下文；null 表示没有持续技能占用。
var active_context: SkillContext
## 当前持续技能的剩余秒数；配置 duration=0 时由效果条件决定结束。
var remaining_duration := 0.0
@onready var hero: HeroProperty = get_parent()
@onready var input: InputController = hero.get_node("InputController")
@onready var state: Node = hero.get_node("State")

## 连接全局请求和状态通知，创建冷却 Timer，再获取初始技能。
func _ready() -> void:
	# 在状态执行物理移动后检测结束条件。
	process_physics_priority = 100
	SignalBus.skill_acquire_requested.connect(_on_acquire_requested)
	SignalBus.skill_remove_requested.connect(_on_remove_requested)
	state.state_changed.connect(_on_state_changed)
	for path in state_skill_map:
		var ability_state := get_node_or_null(path) as BaseState
		if ability_state == null:
			push_error("Invalid cooldown state: %s" % path)
			continue
		_state_skill_ids[ability_state] = state_skill_map[path]
	for id in initial_skills:
		acquire_skill(id)

## 获取任意类型技能时创建计时器，重复注册保留剩余时间。
func _register_skill_timer(definition: SkillDefinition) -> void:
	if skill_timer_map.has(definition.id):
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.wait_time = maxf(definition.cooldown, 0.001)
	timer.timeout.connect(_on_skill_cooldown_finished.bind(definition.id))
	add_child(timer)
	skill_timer_map[definition.id] = timer


## 供输入节点及所有资源技能查询冷却；未获取过的技能视为无冷却。
## 此查询只判断冷却，能力启用、生命和输入限制由调用方判断。
func is_skill_ready(id: StringName) -> bool:
	return not skill_timer_map.has(id) or skill_timer_map[id].is_stopped()


## 返回技能冷却剩余秒数，未注册时返回 0。
func get_skill_cooldown_remaining(id: StringName) -> float:
	return skill_timer_map[id].time_left if skill_timer_map.has(id) else 0.0

## 只为有正数冷却的技能启动 Timer，不检查获取或释放条件。
func start_skill_cooldown(id: StringName) -> void:
	var definition := ResourceManager.get_skill_config(id)
	if definition == null or definition.cooldown <= 0.0:
		return
	_register_skill_timer(definition)
	skill_timer_map[id].start(definition.cooldown)
	SignalBus.skill_cooldown_started.emit(hero, id, definition.cooldown)

## 计时器到期后统一通过总线通知；零冷却和直接 stop 不产生到期事件。
func _on_skill_cooldown_finished(id: StringName) -> void:
	SignalBus.skill_cooldown_finished.emit(hero, id)


## 信号总线可服务多个人物，此组件只处理目标为自己人物的请求。
func _on_acquire_requested(target: HeroProperty, id: StringName) -> void:
	if target == hero:
		acquire_skill(id)

## 与获取请求一样，按 target 隔离不同人物的技能变更。
func _on_remove_requested(target: HeroProperty, id: StringName) -> void:
	if target == hero:
		remove_skill(id)

## 按资源类型获取技能，返回是否接受本次请求。
## ONE_TIME 首次立即执行并记录；INSTANT 每次立即执行；其他类型加入已获得表。
## 重复获取已拥有的技能返回 true，但不刷新效果或冷却。
func acquire_skill(id: StringName) -> bool:
	var definition := ResourceManager.get_skill_config(id)
	if definition == null:
		return false
	_register_skill_timer(definition)
	if definition.kind == SkillDefinition.Kind.ONE_TIME:
		if once_records.has(id):
			return false
		if not is_skill_ready(id):
			return false
		var context := SkillContext.new(hero, definition)
		if not definition.can_execute(context):
			return false
		# 先记录再执行，防止异步执行或效果内再次获取导致重复释放。
		once_records[id] = true
		start_skill_cooldown(id)
		_execute_immediate(context)
		return true
	if definition.kind == SkillDefinition.Kind.INSTANT:
		if not is_skill_ready(id):
			return false
		var context := SkillContext.new(hero, definition)
		if not definition.can_execute(context):
			return false
		start_skill_cooldown(id)
		_execute_immediate(context)
		return true
	if owned_skills.has(id):
		return true
	# 无触发信号的获得性能力只应用/撤销属性效果。
	var passive := definition.kind == SkillDefinition.Kind.ACQUIRED and definition.trigger.is_empty()
	if not passive and not _register_trigger(definition.trigger, id):
		return false
	var runtime := SkillRuntime.new()
	runtime.definition = definition
	runtime.acquire_context = SkillContext.new(hero, definition)
	owned_skills[id] = runtime
	definition.apply_acquired(runtime.acquire_context)
	skills_changed.emit()
	return true


## 移除已拥有技能：取消持续执行、撤销获取效果，再清理触发映射。
## 一次性记录不删除，技能 Timer 也不重置，防止重新获取绕过冷却。
func remove_skill(id: StringName) -> bool:
	if not owned_skills.has(id):
		return false
	if active_context != null and active_context.definition.id == id:
		_finish_active(true)
	var runtime := owned_skills[id]
	runtime.definition.revoke_acquired(runtime.acquire_context)
	owned_skills.erase(id)
	for trigger in trigger_skill_map.keys():
		trigger_skill_map[trigger].erase(id)
		if trigger_skill_map[trigger].is_empty():
			_disconnect_trigger(trigger)
			trigger_skill_map.erase(trigger)
	skills_changed.emit()
	return true


## 验证并连接触发来源，例如 InputController:dash_pressed；路径相对 hero。
## 仅允许人物自身或其子节点的一个信号，同一来源信号只连接一次。
func _register_trigger(trigger: NodePath, id: StringName) -> bool:
	if trigger.get_name_count() == 0 or trigger.get_subname_count() != 1 or trigger.is_absolute():
		return false
	var source := hero.get_node_or_null(NodePath(trigger.get_concatenated_names()))
	if source == null or (source != hero and not hero.is_ancestor_of(source)) or not source.has_signal(trigger.get_subname(0)):
		return false
	if not trigger_skill_map.has(trigger):
		trigger_skill_map[trigger] = []
		var argument_count := 0
		for info in source.get_signal_list():
			if info.name == trigger.get_subname(0):
				argument_count = info.args.size()
		var callback := _on_trigger.bind(trigger)
		# 丢弃来源信号携带的参数，只将绑定的 trigger 传入统一处理函数。
		if argument_count > 0:
			callback = callback.unbind(argument_count)
		_callbacks[trigger] = callback
		_sources[trigger] = weakref(source)
		source.connect(trigger.get_subname(0), callback)
	trigger_skill_map[trigger].append(id)
	return true


## 断开来源信号并删除连接记录；调用方负责清理 trigger_skill_map。
func _disconnect_trigger(trigger: NodePath) -> void:
	var source = _sources[trigger].get_ref()
	if is_instance_valid(source) and source.is_connected(trigger.get_subname(0), _callbacks[trigger]):
		source.disconnect(trigger.get_subname(0), _callbacks[trigger])
	_sources.erase(trigger)
	_callbacks.erase(trigger)


## trigger 标识触发信号的来源，不是技能 ID；通过映射找到候选技能。
func _on_trigger(trigger: NodePath) -> void:
	# 一次条件信号最多执行一项可用技能。
	# 遍历副本，避免技能效果在执行中获取/移除技能影响本次遍历。
	for id in trigger_skill_map.get(trigger, []).duplicate():
		if try_activate(id):
			break


## 检查已获得、执行占用、生命、输入、事件映射及资源条件，再执行技能。
## 无 trigger 的获得性能力只应用属性效果，不能通过此入口主动释放。
## 所有释放入口共用 skill_timer_map；被动能力获取/移除不启动释放冷却。
func try_activate(id: StringName) -> bool:
	if not owned_skills.has(id) or active_context != null or hero.CurrentHealth <= 0.0 or input.is_banned:
		return false
	var runtime := owned_skills[id]
	var definition := runtime.definition
	if definition.kind == SkillDefinition.Kind.ACQUIRED and definition.trigger.is_empty():
		return false
	# 当前状态只记录映射。组件判断此次控制事件能否被该状态接收。
	if definition.control_event != &"" and not state.Current.NextStates.has(String(definition.control_event)):
		return false
	if not is_skill_ready(id):
		return false
	var context := SkillContext.new(hero, definition, input.get_move_direction())
	if not definition.can_execute(context):
		return false
	start_skill_cooldown(id)
	if definition.kind == SkillDefinition.Kind.CONTINUOUS:
		active_context = context
		remaining_duration = maxf(definition.duration, 0.0)
	_execute_owned(context)
	return true

## 调用资源的统一执行入口；持续技能保留上下文，其他技能执行后立即通知结束。
func _execute_owned(context: SkillContext) -> void:
	skill_started.emit(context.definition.id)
	await context.definition.execute(context)
	if context.definition.kind == SkillDefinition.Kind.CONTINUOUS:
		if active_context == context:
			# 资源可能通过控制信号转化状态，因此在执行后记录实际进入的状态。
			context.execution_state = state.Current
	else:
		skill_finished.emit(context.definition.id, context.cancelled)

## 一次性能力和瞬时技能共用的获取即执行入口，不占用 active_context。
func _execute_immediate(context: SkillContext) -> void:
	skill_started.emit(context.definition.id)
	await context.definition.execute(context)
	skill_finished.emit(context.definition.id, context.cancelled)


## 更新持续时间并检测取消/结束条件；所有冷却 Timer 由 Godot 自动计时。
func _physics_process(delta: float) -> void:
	if active_context == null:
		return
	remaining_duration = maxf(0.0, remaining_duration - delta)
	if input.is_banned or hero.CurrentHealth <= 0.0:
		_finish_active(true)
	elif (active_context.definition.duration > 0.0 and remaining_duration <= 0.0) or active_context.definition.should_finish(active_context):
		_finish_active(false)


## 进入配置状态时开始冷却；离开持续技能记录的执行状态时按配置取消技能。
func _on_state_changed(previous: BaseState, current: BaseState) -> void:
	if _state_skill_ids.has(current):
		start_skill_cooldown(_state_skill_ids[current])
	if active_context != null and active_context.definition.cancel_on_state_change and active_context.execution_state != null and current != active_context.execution_state:
		_finish_active(true)


## 清除当前持续执行，调用资源收尾效果，再发出结束通知。
func _finish_active(cancelled: bool) -> void:
	if active_context == null:
		return
	var context := active_context
	# 收尾效果可能再次发出状态转化信号，先清空占用以避免重入重复结束。
	active_context = null
	remaining_duration = 0.0
	context.cancelled = cancelled
	context.definition.finish(context)
	skill_finished.emit(context.definition.id, cancelled)


## 离场时断开外部监听并撤销获取效果；子节点 Timer 随控制器一同销毁。
func _exit_tree() -> void:
	if SignalBus.skill_acquire_requested.is_connected(_on_acquire_requested):
		SignalBus.skill_acquire_requested.disconnect(_on_acquire_requested)
		SignalBus.skill_remove_requested.disconnect(_on_remove_requested)
	if is_instance_valid(state) and state.state_changed.is_connected(_on_state_changed):
		state.state_changed.disconnect(_on_state_changed)
	for trigger in _callbacks.keys():
		_disconnect_trigger(trigger)
	for runtime in owned_skills.values():
		runtime.definition.revoke_acquired(runtime.acquire_context)
