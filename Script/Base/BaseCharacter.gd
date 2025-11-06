class_name BaseCharacter
extends CharacterBody2D

#signal health_changed

@export var MaxHealth: float = 100
@export var MaxMana:float = 100
@export var MaxToughness: float
@export var DamageResist: Array[float]
@export var AbnormalConditionResist: Array[float]
@export var ToughnessRecover: float

var CurrentHealth: float = MaxHealth
var CurrentMana:float = MaxMana
var Toughness: float = MaxToughness
var DamageEnhance:Array
var DamageReduce:Array
var RecoverTimer = Timer.new()

func beginning():
	add_to_group("Chr")
	RecoverTimer.one_shot = true

func running(delta: float):
	pass
	
func physics_running(delta: float):
	pass
	
func breaked():
	if get_node("AnimationPlayer"):
		get_node("AnimationPlayer").play("Break")
	#health_changed.emit()
#	添加其他共同的破防逻辑

func take_damage():
	pass

func death():
	if get_node("AnimationPlayer"):
		get_node("AnimationPlayer").play("Break")
#	添加其他共用的死亡逻辑

func toughness_reduced():
	RecoverTimer.start(ToughnessRecover)
	if RecoverTimer.is_stopped():
		Toughness = MaxToughness

func sum_damage_enhance()->float:
	var Sum:float
	for i in DamageEnhance:
		Sum = Sum + i
	return Sum

func sum_damage_reduce()->float:
	var Sum:float
	for i in DamageReduce:
		Sum = Sum + i
	return Sum

func get_character_current_health()->float:
	return CurrentHealth
	
func get_character_max_health()->float:
	return MaxHealth

func get_character_current_mana()->float:
	return MaxMana

func get_character_max_mana()->float:
	return MaxMana

func get_character_max_toughness()->float:
	return MaxToughness
	
func get_character_toughness()->float:
	return Toughness
	
func get_character_damage_resist()->Array:
	return DamageResist

func get_character_abnormal_condition_resist()->Array:
	return AbnormalConditionResist

func set_character_current_health(CH: float):
	CurrentHealth = CH
	
func set_character_max_health(MH:float):
	MaxHealth = MH

func set_character_current_mana(CM: float):
	CurrentMana = CM

func set_character_max_mana(MM: float):
	MaxMana = MM

func set_character_max_toughness(MT:float):
	MaxToughness = MT
	
func set_character_toughness(T:float):
	Toughness = T
