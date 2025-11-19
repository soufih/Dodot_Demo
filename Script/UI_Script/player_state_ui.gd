extends Control

@export var states: BaseCharacter

@onready var health_bar: TextureProgressBar = $HP/Health_bar

func _ready() ->void:
	states = get_parent()
	states.health_changed.connect(update_health)
	update_health()

func update_health() ->void:
	health_bar.value = states.get_character_current_health()
#血条显示更新
