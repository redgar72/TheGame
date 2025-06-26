extends Node
class_name GameObject

var actions: Dictionary[String, Callable]

class Action:
	var call: Callable
	var name: String
	
	func _init(_name, _call):
		call = _call
		name = _name


func _init(_name, actions) -> void:
	name = _name
	actions = actions
