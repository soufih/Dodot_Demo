extends Camera2D

## 边界碰撞约束整个可见画面，未配置边界时自由跟随。
@export var boundary_collision_enabled: bool = true:
	set(value):
		boundary_collision_enabled = value
		if is_node_ready():
			_select_boundary()
var active_boundary: CameraBoundary
var _entered_boundaries: Array[CameraBoundary] = []

@export_category("长按查看")
## 长按时的镜头偏移距离（像素）：W 向上，S 向下。
@export_range(0.0, 1000.0, 1.0, "or_greater") var look_down_distance: float = 160.0
@export_range(0.0, 3.0, 0.05, "or_greater") var look_hold_duration: float = 0.4
@export_range(1.0, 2000.0, 1.0, "or_greater") var look_move_speed: float = 320.0
@export var _InputController: InputController

var _base_position: Vector2
var _up_hold_time: float = 0.0
var _down_hold_time: float = 0.0
var _look_displacement: float = 0.0
var _look_enabled := true

func _ready() -> void:
	_base_position = position
	var hero := get_parent() as HeroProperty
	if hero != null:
		hero.climb_started.connect(_on_climb_started)
		hero.climb_finished.connect(_on_climb_finished)
	add_to_group("Camera")
	SignalBus.camera_room_entered.connect(_on_room_entered)
	SignalBus.camera_room_exited.connect(_on_room_exited)
	SignalBus.camera_boundary_changed.connect(_on_boundary_changed)
	get_viewport().size_changed.connect(_apply_boundary_limits)
	_apply_boundary_limits()

func _process(delta: float) -> void:
	_update_look(delta)


func _update_look(delta: float) -> void:
	if not _look_enabled:
		return
	var accepts_input := is_current() and not UIManager.is_banned and UIManager.UIList.is_empty()
	var hero := get_parent() as HeroProperty
	if hero != null:
		accepts_input = accepts_input and hero.CurrentHealth > 0.0 and not _InputController.is_banned
	var up_pressed := accepts_input and Input.is_action_pressed("Up")
	var down_pressed := accepts_input and Input.is_action_pressed("Down")
	_up_hold_time = _up_hold_time + delta if up_pressed else 0.0
	_down_hold_time = _down_hold_time + delta if down_pressed else 0.0
	var target: float = 0.0
	if up_pressed and not down_pressed and _up_hold_time >= look_hold_duration:
		target = -look_down_distance
	elif down_pressed and not up_pressed and _down_hold_time >= look_hold_duration:
		target = look_down_distance
	_look_displacement = move_toward(_look_displacement, target, look_move_speed * delta)
	# 移动镜头节点而非 offset，保持 Camera2D 的房间边界约束有效。
	position = _base_position + Vector2(0.0, _look_displacement)

func _on_climb_started() -> void:
	_look_enabled = false
	_up_hold_time = 0.0
	_down_hold_time = 0.0
	_look_displacement = 0.0
	position = _base_position


func _on_climb_finished() -> void:
	_look_enabled = true


func _on_room_entered(player: Node2D, boundary: CameraBoundary) -> void:
	if player != get_parent():
		return
	_entered_boundaries.erase(boundary)
	_entered_boundaries.append(boundary)
	_select_boundary()


func _on_room_exited(player: Node2D, boundary: CameraBoundary) -> void:
	if player != get_parent():
		return
	_entered_boundaries.erase(boundary)
	_select_boundary()


func _on_boundary_changed(boundary: CameraBoundary) -> void:
	if _entered_boundaries.has(boundary):
		_select_boundary()


func _select_boundary() -> void:
	active_boundary = null
	if boundary_collision_enabled:
		# 优先级相同的重叠区域使用最后进入的房间。
		for boundary in _entered_boundaries:
			if not is_instance_valid(boundary) or boundary.is_queued_for_deletion() or not boundary.enabled:
				continue
			if active_boundary == null or boundary.priority >= active_boundary.priority:
				active_boundary = boundary
	_apply_boundary_limits()


## 修改缩放时同步更新窄房间限制，避免依赖每帧检测。
func set_view_zoom(value: Vector2) -> void:
	zoom = value
	_apply_boundary_limits()


func _apply_boundary_limits() -> void:
	limit_enabled = boundary_collision_enabled and is_instance_valid(active_boundary)
	if not limit_enabled:
		return
	var area := active_boundary.get_world_bounds()
	if not area.has_area():
		limit_enabled = false
		return
	var visible_size := get_viewport_rect().size / zoom.abs().max(Vector2(0.001, 0.001))
	# 窄走廊小于画面时锁定该轴中心，避免上下/左右限制相互冲突。
	var effective_size := area.size.max(visible_size)
	var effective := Rect2(area.get_center() - effective_size * 0.5, effective_size)
	limit_left = floori(effective.position.x)
	limit_top = floori(effective.position.y)
	limit_right = ceili(effective.end.x)
	limit_bottom = ceili(effective.end.y)
