class_name BaseCharacter
extends CharacterBody2D

signal health_changed
signal state_changed
signal mana_changed
signal toughness_changed
signal death
signal breaked
signal end_breaked

@export var MaxHealth: float
@export var MaxMana:float
@export var MaxToughness: float
@export var DamageResist: Array[float]
@export var AbnormalConditionResist: Array[float]
@export var ToughnessRecover: float
@export var Speed:int
@export var RecoverTimer:Timer

@onready var CurrentHealth: float = MaxHealth
@onready var CurrentMana:float = MaxMana
@onready var Toughness: float = MaxToughness

var DamageEnhance:Array
var DamageReduce:Array
var StatusSlot:Dictionary[ENUM.STATUS, Vector2]  #状态名隐射持续时间和状态层数


func beginning():
	add_to_group("Chr")
	RecoverTimer.one_shot = true
	#StatusEffectManager.enhance_health(self, 5)


func running(_delta: float):
	pass
	

func physics_running(_delta: float):
	pass
	
##计算伤害增强总和
func sum_damage_enhance()->float:
	var Sum:float
	for i in DamageEnhance:
		Sum = Sum + i
	return Sum

##计算伤害抗性总和
func sum_damage_reduce()->float:
	var Sum:float
	for i in DamageReduce:
		Sum = Sum + i
	return Sum

##获取角色当前生命值
func get_character_current_health()->float:
	return CurrentHealth

##获取角色最大生命值
func get_character_max_health()->float:
	return MaxHealth

##获取角色当前法力值
func get_character_current_mana()->float:
	return MaxMana

##获取角色最大法力值
func get_character_max_mana()->float:
	return MaxMana

##获取角色最大韧性值
func get_character_max_toughness()->float:
	return MaxToughness

##获取角色韧性值
func get_character_toughness()->float:
	return Toughness

##获取角色伤害抗性数组
func get_character_damage_resist()->Array:
	return DamageResist

##获取角色异常状态抗性数组
func get_character_abnormal_condition_resist()->Array:
	return AbnormalConditionResist

##获取角色状态槽
func get_character_state_slot()->Dictionary:
	return StatusSlot

##设置角色当前生命值
func set_character_current_health(CH: float):
	CurrentHealth = CH
	health_changed.emit()
	if get_character_current_health() <= 0:
		death.emit()
	health_changed.emit()

##设置角色最大生命值
func set_character_max_health(MH:float):
	MaxHealth = MH
	
	CurrentHealth = min(MaxHealth, CurrentHealth)
	health_changed.emit()

##设置角色当前法力值
func set_character_current_mana(CM: float):
	CurrentMana = CM
	mana_changed.emit()

##设置角色最大法力值
func set_character_max_mana(MM: float):
	MaxMana = MM
	CurrentMana = min(MaxMana, CurrentMana)
	mana_changed.emit()

##设置角色最大韧性值
func set_character_max_toughness(MT:float):
	MaxToughness = MT
	Toughness = min(Toughness, MaxToughness)
	toughness_changed.emit()

##设置角色韧性值
func set_character_toughness(T:float):
	Toughness = T
	if Toughness <= 0:
		breaked.emit()
		Toughness = MaxToughness
	RecoverTimer.start(ToughnessRecover)
	toughness_changed.emit()
	await RecoverTimer.timeout
	Toughness = MaxToughness


##添加新的状态效果
func add_new_status(Name:int, Duration:float, Amount:int):
	StatusSlot[Name] = Vector2(Duration, Amount)
	state_changed.emit()

##擦除状态效果
func erase_status(Name:int):
	StatusSlot.erase(Name)
	state_changed.emit()
