extends Control

@export var states: BaseCharacter

@onready var health_bar: TextureProgressBar = $HP/Health_bar

func _ready() ->void:
	states.health_changed.connect(update_health)
	update_health()

func update_health() ->void:
	health_bar.value = states.CurrentHealth
