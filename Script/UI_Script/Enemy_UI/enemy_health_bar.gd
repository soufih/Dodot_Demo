class_name EnemyHealthBar
extends Node2D
## 跟随人物头顶的世界空间血条，不继承人物的朝向翻转。

@export var target: BaseCharacter
@export var head_offset: Vector2 = Vector2(0, -64)
@export var hide_when_full: bool = true
@export_range(0.0, 1.0) var damage_delay: float = 0.2
@export_range(0.0, 1.0) var damage_duration: float = 0.3

@onready var health_bar: ProgressBar = $Health
@onready var damage_bar: ProgressBar = $Damage
var _damage_tween: Tween

func _ready() -> void:
	top_level = true
	hide()
	if target == null:
		target = get_parent() as BaseCharacter
	if target == null:
		set_process(false)
		return
	# 子节点先于人物初始化，等待人物读取配置并设置初始血量。
	if not target.is_node_ready():
		await target.ready
	target.health_changed.connect(refresh)
	target.death.connect(_on_death)
	refresh()
	damage_bar.value = health_bar.value
	_process(0.0)

func _exit_tree() -> void:
	if _damage_tween != null:
		_damage_tween.kill()
	if is_instance_valid(target):
		if target.health_changed.is_connected(refresh):
			target.health_changed.disconnect(refresh)
		if target.death.is_connected(_on_death):
			target.death.disconnect(_on_death)

func _process(_delta: float) -> void:
	if is_instance_valid(target):
		global_transform = Transform2D(0.0, target.global_position + head_offset)

## 当前血量立即更新，受伤残影延迟追随；治疗时立即同步。
func refresh() -> void:
	var maximum := maxf(target.MaxHealth, 0.0)
	var current := clampf(target.CurrentHealth, 0.0, maximum)
	var previous := health_bar.value
	health_bar.max_value = maxf(maximum, 1.0)
	damage_bar.max_value = health_bar.max_value
	health_bar.value = current
	visible = maximum > 0.0 and current > 0.0 and (not hide_when_full or current < maximum)
	if current == previous:
		return
	if _damage_tween != null:
		_damage_tween.kill()
	if current < previous and visible:
		_damage_tween = create_tween()
		_damage_tween.tween_interval(damage_delay)
		_damage_tween.tween_property(damage_bar, "value", current, damage_duration)
	else:
		damage_bar.value = current

func _on_death() -> void:
	hide()
