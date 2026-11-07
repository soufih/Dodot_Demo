extends BaseUI

@onready var level_discription = $level_discription

@onready var discription_pos1: Marker2D = $"Level1/discription_pos_1"
@onready var discription_pos2: Marker2D = $"Level2/discription_pos_2"
@onready var discription_pos3: Marker2D = $"Level3/discription_pos_3"
@onready var discription_pos4: Marker2D = $"Level4/discription_pos_4"
@onready var discription_pos5: Marker2D = $"Level5/discription_pos_5"

@onready var camera_pos_1: Marker2D = $"Level1/camera_pos_1"
@onready var camera_pos_2: Marker2D = $"Level2/camera_pos_2"
@onready var camera_pos_3: Marker2D = $"Level3/camera_pos_3"
@onready var camera_pos_4: Marker2D = $"Level4/camera_pos_4"
@onready var camera_pos_5: Marker2D = $"Level5/camera_pos_5"

@onready var camera:Camera2D = $MapCammera
var camera_pos_start:Vector2
var _selection_tween: Tween

func _ready() -> void:
	begin()
	camera_pos_start = camera.global_position
	

func _on_level_1_button_down() -> void:
	CurrentLevel.set_level_info(0,"level1")
	level_discription.global_position = discription_pos1.global_position
	
	var tween := _new_selection_tween()
	tween.tween_property(camera,"global_position", camera_pos_1.global_position, 0.25)
	tween.set_parallel()
	tween.tween_property(camera,"zoom", Vector2(1.5,1.5), 0.25)

	tween.tween_callback(level_discription.show).set_delay(0.25)


func _on_level_2_button_down() -> void:
	CurrentLevel.set_level_info(1,"level2")
	level_discription.global_position = discription_pos2.global_position

	var tween := _new_selection_tween()
	tween.tween_property(camera,"global_position", camera_pos_2.global_position, 0.25)
	tween.set_parallel()
	tween.tween_property(camera,"zoom", Vector2(1.5,1.5), 0.25)

	tween.tween_callback(level_discription.show).set_delay(0.25)


func _on_level_3_button_down() -> void:
	CurrentLevel.set_level_info(2,"level3")
	level_discription.global_position = discription_pos3.global_position
	
	var tween := _new_selection_tween()
	tween.tween_property(camera,"global_position", camera_pos_3.global_position, 0.25)
	tween.set_parallel()
	tween.tween_property(camera,"zoom", Vector2(1.5,1.5), 0.25)
	
	tween.tween_callback(level_discription.show).set_delay(0.25)


func _on_level_4_button_down() -> void:
	CurrentLevel.set_level_info(3,"level4")
	level_discription.global_position = discription_pos4.global_position
	
	var tween := _new_selection_tween()
	tween.tween_property(camera,"global_position", camera_pos_4.global_position, 0.25)
	tween.set_parallel()
	tween.tween_property(camera,"zoom", Vector2(1.5,1.5), 0.25)

	tween.tween_callback(level_discription.show).set_delay(0.25)



func _on_level_5_button_down() -> void:
	CurrentLevel.set_level_info(4,"level5")
	level_discription.global_position = discription_pos5.global_position

	var tween := _new_selection_tween()
	tween.tween_property(camera,"global_position", camera_pos_5.global_position, 0.25)
	tween.set_parallel()
	tween.tween_property(camera,"zoom", Vector2(1.5,1.5), 0.25)

	tween.tween_callback(level_discription.show).set_delay(0.25)


func _on_level_discription_visibility_changed() -> void:
	if !level_discription:
		return
	if !level_discription.visible:
		var tween := _new_selection_tween()
		tween.tween_property(camera,"global_position", camera_pos_start, 0.25)
		tween.set_parallel()
		tween.tween_property(camera,"zoom", Vector2(1,1), 0.25)


func _on_map_ui_visibility_changed() -> void:
	if !camera:
		return
	
	if visible:
		camera.make_current()
		return

	var cameras = get_tree().get_nodes_in_group("Camera")
	for c in cameras:
		if c.name == "MainCamera":
			c.make_current()


func _new_selection_tween() -> Tween:
	if _selection_tween != null:
		_selection_tween.kill()
	_selection_tween = create_tween()
	return _selection_tween


func cancel_local_interaction() -> bool:
	if level_discription.visible:
		level_discription.hide()
		return true
	return false


func on_close(_reason: StringName) -> void:
	if _selection_tween != null:
		_selection_tween.kill()
	level_discription.hide()
	# hide 信号可能生成复位动画；关闭后直接复位并取消延迟 show。
	if _selection_tween != null:
		_selection_tween.kill()
	camera.global_position = camera_pos_start
	camera.zoom = Vector2.ONE
