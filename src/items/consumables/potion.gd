# SPDX-FileCopyrightText: 2023 Elia Argentieri
#
# SPDX-License-Identifier: GPL-3.0-or-later

class_name Potion
extends "../consumable.gd"


var heal: int


func _init(_name, _icon, _quantity, _heal):
	super(_name, _icon, _quantity, 10, 50)
	heal = _heal


func effect(target: Player):
	if target.can_consume() and target.hp < target.hp_max:
		target.heal(heal)
		target.state_machine.travel("drink")
		return true
	return false


func clone():
	return get_script().new(name, icon, quantity, heal)
