extends Node

@export var _player_info = {}

func set_player_info(player_info):
	_player_info = player_info

func get_player_info(id):
	return _player_info.get(id)
