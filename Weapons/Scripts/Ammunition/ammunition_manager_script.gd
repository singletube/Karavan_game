extends Node3D

enum AMMO_TYPES
{
	LIGHTAMMO, MEDIUMAMMO, HEAVYAMMO, SHELLAMMO, EXPLOSIVEAMMO
}

var ammo_dict : Dictionary[AMMO_TYPES, int] = { #key = ammo type, value = ammo start number
	AMMO_TYPES.LIGHTAMMO : 68,
	AMMO_TYPES.MEDIUMAMMO : 60,
	AMMO_TYPES.HEAVYAMMO : 10,
	AMMO_TYPES.SHELLAMMO : 128,
	AMMO_TYPES.EXPLOSIVEAMMO : 3,
}

var max_nb_per_ammo_dict : Dictionary[AMMO_TYPES, int] = { #key = ammo type, value = ammo max number
	AMMO_TYPES.LIGHTAMMO : 136,
	AMMO_TYPES.MEDIUMAMMO : 240,
	AMMO_TYPES.HEAVYAMMO : 40,
	AMMO_TYPES.SHELLAMMO  : 512,
	AMMO_TYPES.EXPLOSIVEAMMO : 8,
}

func refill_ammo(percent: float = 0.5) -> void:
	for t in ammo_dict.keys():
		var max_val: int = max_nb_per_ammo_dict.get(t, 100)
		var gain: int = maxi(1, int(round(max_val * percent)))
		ammo_dict[t] = mini(max_val, ammo_dict[t] + gain)

func add_ammo(amount: int = 60) -> void:
	refill_ammo(0.5)

	
