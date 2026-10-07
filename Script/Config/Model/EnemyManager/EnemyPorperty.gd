extends Resource
class_name EnemyConfig

@export var Name: String
@export var EnemyLevel:ENUM.EnemyLevel
@export var Habitat: int
@export var EnemyPath:String = ""

@export var MaxHealth: float
@export var MaxToughness: float
@export var DamageResist: Array[float]
@export var AbnormalConditionResist: Array[float]
@export var ToughnessRecover: float

@export var Drop:Array[droppedItemConfig]#物品id, 掉落范围， 掉落概率
@export var Movementlist:Dictionary[String, DamagePorperty]
