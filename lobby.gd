extends Control

# TODO: define default IP address and port constants
const LEVEL_1 = preload("res://level_1.tscn")

@onready var name_input = $NameLineEdit
@onready var host_game_button = $HostGameButton
@onready var join_game_button = $JoinGameButton
@onready var start_game_button = $StartGameButton
@onready var log = $Log
@onready var display_names_timer = $DisplayNamesTimer

var players = {}

func _ready() -> void:
	pass
	# TODO: connect multiplayer signals to functions

func log_message(message):
	log.text = log.text + message + '\n'

# TODO: RPC to start game

# TODO: RPC to update player info


func _on_host_game_button_pressed() -> void:
	# TODO: create server peer
	name_input.editable = false
	host_game_button.disabled = true
	join_game_button.disabled = true
	start_game_button.visible = true
	

func _on_join_game_button_pressed() -> void:
	# TODO: create client peer
	name_input.editable = false
	host_game_button.disabled = true
	join_game_button.disabled = true

func _on_start_game_button_pressed() -> void:
	pass

# TODO: define functions for multiplayer signals

func _on_display_names_timer_timeout() -> void:
	var msg = "Current players: "
	for id in players:
		msg += players[id]["name"] + "  "
	log_message(msg)
