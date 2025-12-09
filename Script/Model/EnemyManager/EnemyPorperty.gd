extends Resource
class_name EnemyPorperty

@export var Name: String

#敌人数值
@export var MaxHealth: float
@export var MaxToughness: float
@export var DamageResist: Array[float]
@export var AbnormalConditionResist: Array[float]
@export var ToughnessRecover: float

#敌人属性
@export var Drop:Array[Vector4] #物品id, 掉落范围， 掉落概率
@export var Movementlist:Dictionary[String, DamagePorperty]
