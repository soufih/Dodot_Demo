extends BaseUI

@onready var Hero: BaseCharacter = DataLoader.HERO
@onready var health_bar: TextureProgressBar = $HP/Health_bar
@onready var mana_bar: TextureProgressBar = $MP/Mana_bar

var max_health: float
var health: float
var need_update_health:bool = true
var base_max_health: float = 100
var max_mana: float
var mana: float
var need_update_mana:bool = true
var base_max_mana: float = 100

func _ready() ->void:
	begin()
	SignalBus.mana_changed.connect(update_mana)
	SignalBus.health_changed.connect(update_health)
	await get_tree().create_timer(0.1).timeout
	update_health()
	update_mana()
	
#血条显示更新
func update_health() ->void:
	max_health = Hero.get_character_max_health()
	health = Hero.get_character_current_health()
	need_update_health = true

#法力值显示更新
func update_mana() ->void:
	max_mana = Hero.get_character_max_mana()
	mana = Hero.get_character_current_mana()
	need_update_mana = true

#顺滑血条变化
func _process(delta: float) -> void:
	if health_bar.max_value == max_health && health_bar.value == health:
		need_update_health = false
	if mana_bar.max_value == max_mana && mana_bar.value == mana:
		need_update_mana = false
	
	
	if need_update_health:
		health_bar.max_value = lerpf(health_bar.max_value, max_health, delta*2)
		health_bar.value = lerpf(health_bar.value, health, delta*2)
	
	if need_update_mana:
		mana_bar.max_value = lerpf(mana_bar.max_value, max_mana, delta*3)
		mana_bar.value = lerpf(mana_bar.value, mana, delta*3)
