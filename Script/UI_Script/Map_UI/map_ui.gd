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

@onready var camera = $Camera2D

func _ready() -> void:
	begin()
	hide()

func _on_level_1_button_down() -> void:
	LevelInformation.set_level_info(0,"level1")
	level_discription.global_position = discription_pos1.global_position
	level_discription.show()


func _on_level_2_button_down() -> void:
	LevelInformation.set_level_info(1,"level2")
	level_discription.global_position = discription_pos2.global_position
	level_discription.show()


func _on_level_3_button_down() -> void:
	LevelInformation.set_level_info(2,"level3")
	level_discription.global_position = discription_pos3.global_position
	level_discription.show()


func _on_level_4_button_down() -> void:
	LevelInformation.set_level_info(3,"level4")
	level_discription.global_position = discription_pos4.global_position
	level_discription.show()


func _on_level_5_button_down() -> void:
	LevelInformation.set_level_info(4,"level5")
	level_discription.global_position = discription_pos5.global_position
	level_discription.show()
