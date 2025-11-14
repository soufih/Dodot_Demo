extends BaseCharacter
class_name BaseEnemy

var Porperty:DamagePorperty

func beginning():
	super.beginning()
	add_to_group("Enemy")
	Porperty = DataLoader.get_enemy_porperty(self.name)
