extends Control

var icon: Texture2D
var skill_id: StringName
var duration := 1.0
var remaining := 0.0
var progress := 0.0
var timer: Timer

func _init() -> void:
	custom_minimum_size = Vector2(68, 68)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	timer = Timer.new()
	timer.one_shot = true
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.timeout.connect(_on_timeout)
	add_child(timer)

## 冷却计时完全由 item 自己维护，到期后销毁自身。
func start_cooldown(id: StringName, cooldown_icon: Texture2D, total_duration: float) -> void:
	skill_id = id
	icon = cooldown_icon
	duration = maxf(total_duration, 0.001)
	timer.start(duration)
	update_remaining(duration)

func _process(_delta: float) -> void:
	update_remaining(timer.time_left)

func _on_timeout() -> void:
	update_remaining(0.0)
	queue_free()

func update_remaining(seconds: float) -> void:
	remaining = maxf(seconds, 0.0)
	progress = clampf(remaining / duration, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(34, 34)
	draw_style_box(_panel(), Rect2(2, 2, 64, 64))
	if icon != null:
		draw_texture_rect(icon, Rect2(10, 10, 48, 48), false)
	else:
		draw_string(ThemeDB.fallback_font, Vector2(18, 40), String(skill_id).left(2).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if progress > 0.0:
		# 扇形从十二点方向逐渐退去，进度直接读取 Timer，暂停时不会漂移。
		var points := PackedVector2Array([center])
		var steps := maxi(2, ceili(64 * progress))
		for i in range(steps + 1):
			var angle := -PI / 2.0 + TAU * progress * i / steps
			points.append(center + Vector2.from_angle(angle) * 27.0)
		draw_colored_polygon(points, Color(0.02, 0.04, 0.08, 0.72))
		draw_arc(center, 30, -PI / 2.0, -PI / 2.0 + TAU * progress, 64, Color(0.5, 0.85, 1.0), 3.0, true)

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	style.set_corner_radius_all(10)
	return style
