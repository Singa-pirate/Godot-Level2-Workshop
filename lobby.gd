extends Control

const ADDRESS = '127.0.0.1'
const PORT = 7777
const MAX_CLIENTS = 5
const LEVEL_1 = preload("res://level_1.tscn")

@onready var name_input = $NameLineEdit
@onready var host_game_button = $HostGameButton
@onready var join_game_button = $JoinGameButton
@onready var start_game_button = $StartGameButton
@onready var log = $Log
@onready var display_names_timer = $DisplayNamesTimer

var players = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	multiplayer.peer_connected.connect(peer_connected)
	multiplayer.peer_disconnected.connect(peer_disconnected)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.server_disconnected.connect(server_disconnected)

func log_message(message):
	log.text = log.text + message + '\n'

@rpc('authority', 'call_local', 'reliable')
func start_game():
	var level = LEVEL_1.instantiate()
	get_parent().add_child(level)
	self.visible = false

@rpc('any_peer', 'call_remote', 'reliable')
func update_player_info(id: int, name: String):
	players[id] = {
		"id": id,
		"name": name,
		"score": 0
	}

func _on_host_game_button_pressed() -> void:
	# create server peer
	var server_peer = ENetMultiplayerPeer.new()
	var error = server_peer.create_server(PORT, MAX_CLIENTS)
	if error:
		log_message(error)
	else:
		name_input.editable = false
		host_game_button.disabled = true
		join_game_button.disabled = true
		start_game_button.visible = true
		multiplayer.multiplayer_peer = server_peer
		display_names_timer.start()
		
		var name = name_input.text
		log_message("Hosting server with id 1 and name %s." % name)
		update_player_info(1, name)
		

func _on_join_game_button_pressed() -> void:
	# create client peer
	var client_peer = ENetMultiplayerPeer.new()
	var error = client_peer.create_client(ADDRESS, PORT)
	if error:
		log_message(error)
	else:
		name_input.editable = false
		host_game_button.disabled = true
		join_game_button.disabled = true
		multiplayer.multiplayer_peer = client_peer
	
func _on_start_game_button_pressed() -> void:
	start_game.rpc()

func peer_connected(id):
	log_message("Player %d has entered the room!" % id)
	var my_id = multiplayer.get_unique_id()
	var my_name = name_input.text
	update_player_info.rpc_id(id, my_id, my_name)

func peer_disconnected(id):
	players.erase(id)
	log_message("Player %d has left the room!" % id)

func connection_failed():
	log_message("Failed to connect to server, please try again.")

func connected_to_server():
	var id = multiplayer.get_unique_id()
	var name = name_input.text
	display_names_timer.start()
	update_player_info(id, name)
	update_player_info.rpc(id, name)
	log_message("Connected to server with id %d and name %s." % [id, name])

func server_disconnected():
	log_message("Server disconnected, please join another room.")
	display_names_timer.stop()
	players = {}
	name_input.editable = true
	host_game_button.disabled = false
	join_game_button.disabled = false

func _on_display_names_timer_timeout() -> void:
	var msg = "Current players: "
	for id in players:
		msg += players[id]["name"] + "  "
	log_message(msg)
