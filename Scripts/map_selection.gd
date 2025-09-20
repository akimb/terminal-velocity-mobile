extends Control

var prev_scene = null
var map_select_on : bool = false

@onready var trip_start = $"Trip Start"
@onready var back = $Buttons/Back
@onready var fly = $Buttons/Fly
@onready var h_box_container = $ScrollContainer/Panel/HBoxContainer
@onready var scroll_container = $ScrollContainer

var transition_screen : PackedScene = preload("res://Scenes/transition_screen.tscn")
var level_select : PackedScene = preload("res://Scenes/new_level_select2.tscn")
var level = null

func _ready():
	fly.disabled = true
	trip_start.text = "Trip Start: " + Time.get_date_string_from_system(false)
	
	for i in GameManager.max_levels:
		level = level_select.instantiate()
		level.level_selected.connect(level_selected)
		level.current_level = i
		h_box_container.add_child(level)
	
	var new_sep = $ScrollContainer/Panel/HBoxContainer/VSeparator.duplicate()
	$ScrollContainer/Panel/HBoxContainer.add_child(new_sep)
	
	
	for levels in h_box_container.get_children():
		if !levels is VSeparator:
			levels.set_disable()

func reset():
	fly.disabled = true
	scroll_container.scroll_horizontal = ((382.185 + 50) * GameManager.current_level) - 382.185/2.0
	for levels in h_box_container.get_children():
		if !levels is VSeparator:
			levels.set_disable()

func level_selected():
	fly.disabled = false

func _on_back_pressed():
	SoundBus.button.play()
	SoundBus.whoosh.play()
	self.visible = false
	if prev_scene:
		prev_scene.visible = true
	map_select_on = !map_select_on

func _on_fly_pressed():
	self.visible = false
	SoundBus.start_game.play()
	SoundBus.airport_ambience.stop()
	SoundBus.song_2.stop()
	SoundBus.song_3.stop()
	TransitionEffect.transition_to_scene("res://Scenes/transition_screen.tscn")
