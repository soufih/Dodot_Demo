extends BaseCharacter
class_name BaseEnemy

var Porperty:EnemyConfig
var Atived:bool = false

func beginning():
	super.beginning()
	add_to_group("Enemy")
	Porperty = EnemyManager.get_enemy_porperty(self.name)
	if !Porperty:
		push_warning("Can't Find Enemy Porperty")
		return
		
	MaxHealth = Porperty.MaxHealth
	CurrentHealth = MaxHealth
	MaxToughness = Porperty.MaxToughness
	Toughness = MaxToughness
	ToughnessRecover = Porperty.ToughnessRecover
	AbnormalConditionResist = Porperty.AbnormalConditionResist
	DamageResist = Porperty.DamageResist
