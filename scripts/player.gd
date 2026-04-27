extends CharacterBody2D

@export var speed = 200
@export var echo_cooldown = 2.0

var current_cooldown = 0.0

func _ready():
	position = Vector2(640, 360)

func _physics_process(delta):
	# Движение
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Откат кулдауна эхо
	if current_cooldown > 0:
		current_cooldown -= delta
	
	# Эхо импульс
	if Input.is_action_just_pressed("echo") and current_cooldown <= 0:
		emit_echo()
		current_cooldown = echo_cooldown

func emit_echo():
	# Создаем визуальный импульс эхо
	var echo_wave = load("res://scripts/echo_wave.gd").new()
	add_child(echo_wave)
	echo_wave.init(position, 150, Color.WHITE, 0.5)
	
	# Оповещаем враагов
	get_tree().call_group("enemies", "on_echo", position)
