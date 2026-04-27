extends CharacterBody2D

@export var speed = 100
@export var alert_distance = 400

var is_alert = false
var alert_timer = 0.0
var last_heard_position = Vector2.ZERO

func _ready():
	add_to_group("enemies")

func _physics_process(delta):
	if is_alert:
		alert_timer -= delta
		if alert_timer <= 0:
			is_alert = false
			modulate = Color.WHITE
		else:
			# Движемся к последней услышанной позиции
			var direction = (last_heard_position - position).normalized()
			velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()

func on_echo(echo_pos: Vector2):
	var distance = position.distance_to(echo_pos)
	
	# Если враг услышал звук в пределах диапазона
	if distance < alert_distance:
		is_alert = true
		alert_timer = 3.0  # Враг ищет 3 секунды
		last_heard_position = echo_pos
		modulate = Color.RED

func _draw():
	draw_circle(Vector2.ZERO, 8, Color.YELLOW if is_alert else Color.WHITE)
