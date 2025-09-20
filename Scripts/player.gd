extends CharacterBody3D

signal player_hit

#@export var health : int = 5
@export var max_speed:float = 10.0
@export var turn_speed: float = 25.0
@export var boost_bonus := 10.0
@export var max_turn_angle: float = 30.0
@export var smooth_factor: float = 0.01
@export var turn_slowdown_factor: float = 0.05

@export var luggage : PackedScene = null

@export var blink_interval: float = 0.1
@export var blink_duration: float = 1.0
@export var blink_intensity: float = 0.7
@export var shader_material: ShaderMaterial

@onready var collision_shape = $CollisionShape3D

var forward_direction: Vector3 = Vector3(0,0,1)
var target_velocity: Vector3 = Vector3.ZERO

var boost_accel := 0.1

var blinking = false
var elapsed_time = 0.0
var all_materials = {}
var forward_speed: float = 0.0
var luggage_object = null
var input_direction : float = 0.0
var reached_end = false


var started = false
#var shop : PackedScene = preload("")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	luggage = GameManager.chosen_luggage
	if luggage == null:
		luggage = load("res://Scenes/official_luggage_mainmenu.tscn")
	luggage_object = luggage.instantiate()
	luggage_object.scale = Vector3(1, 1, 1)
	
	
	max_speed = (luggage_object.top_speed + GameManager.speed_mod) * (1.0 + 0.04 * GameManager.base_difficulty)
	smooth_factor = ((luggage_object.handling + GameManager.handling_mod) / 150.0) * .95
	boost_bonus = luggage_object.boost + GameManager.boost_mod
	turn_speed = luggage_object.strafe_speed * 1.05
	
	collision_shape.shape = luggage_object.luggage_collider.shape
	collision_shape.position = luggage_object.luggage_collider.position
	collision_shape.rotation = luggage_object.rotation
	collision_shape.shape.size = luggage_object.luggage_collider.shape.size
	
	self.add_child(luggage_object)

func _physics_process(delta: float) -> void:
	if !started:
		return
	if reached_end:
		forward_speed = move_toward(forward_speed, 0, 0.15)
		velocity = velocity.move_toward(Vector3.ZERO, 0.15)
		var forward_angle: float = atan2(forward_direction.x, forward_direction.z)
		rotation.y = lerp_angle(rotation.y, forward_angle, 0.7)
		if velocity.length() < 1.0:
			started = false
			TransitionEffect.transition_to_scene("res://Scenes/victory_screen.tscn")
	else:
		handle_player_movement(delta)
	#print(forward_speed)

	#print(velocity.length())

	# Move the luggage
	play_rolling()
	move_and_slide()
	
	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		var collider = collision.get_collider()
		if collider:
			if collider.is_in_group("obstacle"):
				on_hit_obstacle(collider)
			elif collider.is_in_group("pickup"):
				on_hit_pickup(collider)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		print(get_viewport().size.x)
		var center = get_viewport().size.x * 0.5
		print(center)
		print(event.position.x)
		if event.position.x < center:
			input_direction = 1.0
		elif event.position.x >= center:
			input_direction = -1.0
	elif event is InputEventScreenTouch and event.is_released():
		input_direction = 0.0
	#if event is InputEventScreenDrag:
		#print(event.relative.x)
		#var center = get_viewport().size.x * 0.5
		#input_direction = clamp((event.position.x - center) / center, -1.0, 1.0)
	#elif event is InputEventScreenTouch and event.is_released():
		#input_direction = 0.0

func handle_player_movement(delta:float):
	var acceleration = 5.0
	var recovery_acceleration = 3.0  # Slower when recovering from negative speed
	var deceleration = 2.0
	var boost_acceleration = 10.0

	# Acceleration and recovery
	if forward_speed < max_speed:
		if forward_speed < 0:
			forward_speed = lerp(forward_speed, 5.0, recovery_acceleration * delta)
			rotation.y += PI/16.0
			return
		else:
			forward_speed = lerp(forward_speed, max_speed, acceleration * delta)

	# Deceleration when exceeding max speed
	elif forward_speed > max_speed:
		forward_speed = lerp(forward_speed, max_speed, deceleration * delta)

	# Boost handling
	if Input.is_action_pressed("boost") and forward_speed >= max_speed * 0.95:
		forward_speed = lerp(forward_speed, max_speed + boost_bonus, boost_acceleration * delta)
	
	#if not is_on_floor():
		#velocity.y += -9.81 * delta

	# Get input for turning
	#var input_direction: float = Input.get_axis("right", "left")
	var forward_angle: float = atan2(forward_direction.x, forward_direction.z)
	var target_rotation: float = forward_angle + deg_to_rad(max_turn_angle * input_direction)
	var current_rotation: float = lerp_angle(rotation.y, target_rotation, smooth_factor)
	rotation.y = current_rotation
	
	
	
	
	var angle_diff: float = abs(current_rotation) - abs(forward_angle)
	var turning_sign = sign(current_rotation - forward_angle)
	#print("for: ", forward_angle, " targ: ", target_rotation, "cur: ", current_rotation, " dif: ", angle_diff)

	var turning_intensity: float = abs(abs(angle_diff)) / deg_to_rad(max_turn_angle)

	#print(turning_intensity)

	# Adjust speed based on the actual rotation intensity (more turn = slower)
	var speed_modifier: float = 1.0 - turning_intensity * turn_slowdown_factor
	var current_speed: float = forward_speed * speed_modifier

	# Calculate forward movement
	target_velocity = forward_direction * current_speed

	var side_dir = forward_direction.rotated(Vector3.UP, deg_to_rad(90))

	# Calculate lateral movement based on rotation
	var strafe: Vector3 = side_dir * (turn_speed * turning_intensity * turning_sign)
	#print(strafe)

	# Combine forward and strafe motion
	target_velocity += strafe
	
	#if target_velocity.length() > 0:
	#	target_velocity = target_velocity.normalized() * current_speed

	# Smooth velocity adjustment
	velocity = lerp(velocity, target_velocity, smooth_factor)

func play_rolling():
	if reached_end:
		if SoundBus.rolling_suitcase.playing:
			SoundBus.rolling_suitcase.stop()
			
	if velocity.length() > 0.1:
		if not SoundBus.rolling_suitcase.playing:
			SoundBus.rolling_suitcase.play()
	else:
		if SoundBus.rolling_suitcase.playing:
			SoundBus.rolling_suitcase.stop()

func on_hit_obstacle(collider):
	if forward_speed <= 0:
		return
	#print("ON HIT")
	GameManager.total_money = max(GameManager.total_money - 5 * 100, 0)
	Input.vibrate_handheld(100)
	velocity = forward_direction * -20
	forward_speed = -20
	
	collider.on_hit()
	
	luggage_object.collision_sound.play()
	player_hit.emit()
	start_blinking()

func on_hit_pickup(_collider):
	print("TEST")

func start_blinking():
	blinking = true
	elapsed_time = 0.0

func set_material_blink(intensity: float, alpha: float):
	if shader_material:
		shader_material.set("shader_parameter/blink_intensity", intensity)
		shader_material.set("shader_parameter/alpha", alpha)

func mix_colors(color1: Color, color2: Color, factor: float) -> Color:
	return color1.lerp(color2, factor)
	
func start():
	started = true
	pass

func finish():
	#SoundBus.rolling_suitcase.stop()
	velocity = forward_direction * velocity.length()
	reached_end = true
	
