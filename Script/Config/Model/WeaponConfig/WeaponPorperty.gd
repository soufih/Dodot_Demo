extends Resource
class_name WeaponPorperty

@export_category("Properties")
@export var Name: String
@export var Type: ENUM.WeaponType
@export var BaseDamage: DamagePorperty
@export var DamageMultipler: Dictionary[int, float]## Key: Movement, Value: Multiplier
@export var AttackSpeed: float = 1.0
@export var MaxCombo:int = 1

@export_category("Action")
@export var BeforeAttack:Array[WeaponAction]
@export var DuringAttack:Array[WeaponAction]
@export var AfterAttack:Array[WeaponAction]
