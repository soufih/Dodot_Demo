extends Control

@onready var Hero: BaseCharacter = DataLoader.HERO
@onready var health_bar: TextureProgressBar = $HP/Health_bar

var max_health: float
var health: float
var need_update:bool = true
var base_max_health: float = 100

func _ready() ->void:
	Hero.health_changed.connect(update_health)
	await get_tree().create_timer(0.1).timeout
	update_health()

	
#血条显示更新
func update_health() ->void:
	max_health = Hero.get_character_max_health()
	health = Hero.get_character_current_health()
	need_update = true

#顺滑血条变化
func _process(delta: float) -> void:
	if health_bar.max_value == max_health && health_bar.value == health:
		need_update = false
	
	if need_update:
		health_bar.max_value = lerpf(health_bar.max_value, max_health, delta*2)
		health_bar.value = lerpf(health_bar.value, health, delta*2)
