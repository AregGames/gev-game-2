extends Node2D

func _ready():
	# Создаем игрока
	var player = preload("res://scenes/player.tscn").instantiate()
	add_child(player)
	
	# Создаем границы лабиринта
	create_walls()
	
	# Создаем врагов
	spawn_enemies()

func create_walls():
	# Создаем простую границу лабиринта
	var static_body = StaticBody2D.new()
	add_child(static_body)
	
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(1280, 720)
	collision_shape.shape = rectangle_shape
	collision_shape.position = Vector2(640, 360)
	static_body.add_child(collision_shape)

func spawn_enemies():
	# Спауним несколько врагов на уровне
	var spawn_positions = [
		Vector2(200, 200),
		Vector2(1000, 200),
		Vector2(200, 600),
		Vector2(1000, 600)
	]
	
	for pos in spawn_positions:
		var enemy = preload("res://scenes/enemy.tscn").instantiate()
		enemy.position = pos
		add_child(enemy)

func _draw():
	# Рисуем пол (полностью черный)
	draw_rect(Rect2(0, 0, 1280, 720), Color.BLACK)
	
	# Рисуем стены (границы)
	draw_rect(Rect2(0, 0, 1280, 20), Color.DARK_GRAY)     # Верх
	draw_rect(Rect2(0, 700, 1280, 20), Color.DARK_GRAY)   # Низ
	draw_rect(Rect2(0, 0, 20, 720), Color.DARK_GRAY)      # Лево
	draw_rect(Rect2(1260, 0, 20, 720), Color.DARK_GRAY)   # Право

func _draw():
	# Рисуем пол (полностью черный)
	draw_rect(Rect2(0, 0, 1280, 720), Color.BLACK)
	
	# Рисуем стены (границы)
	draw_rect(Rect2(0, 0, 1280, 20), Color.DARK_GRAY)     # Верх
	draw_rect(Rect2(0, 700, 1280, 20), Color.DARK_GRAY)   # Низ
	draw_rect(Rect2(0, 0, 20, 720), Color.DARK_GRAY)      # Лево
	draw_rect(Rect2(1260, 0, 20, 720), Color.DARK_GRAY)   # Право
