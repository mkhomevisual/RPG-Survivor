extends Area2D # Bullet – základní node pro šíp

@export var speed: float = 200.0 # základní rychlost střely v px/s
@export var lifetime: float = 2.5 # jak dlouho střela žije (v sekundách)
@export var split_angle_deg: float = 45.0 # úhel rozdělení split střel (ve stupních)
@export var default_chain_range: float = 200.0 # defaultní dosah pro chain bounce

var base_speed: float = 0.0 # uložená původní rychlost kvůli multiplikátoru
var _direction: Vector2 = Vector2.ZERO # normovaný směr letu střely
var _time_alive: float = 0.0 # jak dlouho je střela naživu
var damage: int = 1 # kolik damage střela dává

var pierce_remaining: int = 0 # kolik nepřátel ještě může střela prostřelit (globálně, mimo R efekt)

var split_on_hit: bool = false # jestli se střela po zásahu rozdělí
var split_generations: int = 0 # kolikrát se ještě může dělení opakovat

var chain_jumps_remaining: int = 0 # kolik chain „skoků“ zbývá
var chain_range: float = 100.0 # dosah hledání dalšího cíle pro chain

var _hit_enemies: Array[Node] = [] # původně pro chain, necháme si ho zatím bokem

# ---- Ashe R – piercing uvnitř zóny ----
var _pierce_in_zone: bool = false              # zda je střela právě teď v „R zóně“
var _pierce_hit_enemies: Array[Node] = []      # seznam enemáků, které už tahle střela trefila v piercing módu

@onready var _bullet_scene: PackedScene = preload("res://Scenes/bullet-ashe.tscn") # scéna pro nově spawnuté Ashe šípy
@onready var trail: CPUParticles2D = $Trail


func _destroy_bullet() -> void:
	# Bezpečné zničení střely + necháme trail dožít
	if is_instance_valid(trail):
		trail.emitting = false
		trail.one_shot = true
		trail.reparent(get_tree().current_scene) # necháme stopu dožít ve světě
		trail.lifetime = 0.4
	queue_free()


func _ready() -> void:
	base_speed = speed # uložíme si startovní rychlost
	chain_range = default_chain_range # nastavíme počáteční chain range
	body_entered.connect(_on_body_entered) # napojíme callback na kolizi s tělem
	add_to_group("player_bullet") # označíme, že jde o hráčský projektil (pro R zónu)


func _physics_process(delta: float) -> void:
	# pohyb střely ve směru _direction
	position += _direction * speed * delta

	# životnost
	_time_alive += delta
	if _time_alive >= lifetime:
		_destroy_bullet() # použijeme naši destroy funkci (kvůli trailu)


func set_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO: # ochrana proti nulovému vektoru
		dir = Vector2.RIGHT # defaultně míříme doprava
	_direction = dir.normalized() # uložíme normovaný směr
	rotation = _direction.angle() # otočíme celý projektil podle směru (sprite míří stále „dopředu“)


func set_damage(amount: int) -> void:
	damage = amount # nastavíme poškození střely


func set_pierce(count: int) -> void:
	pierce_remaining = count # nastavíme kolik cílů může střela prostřelit (globálně)


func set_split(enabled: bool, generations: int = 1) -> void:
	split_on_hit = enabled # zapneme/vypneme split efekt
	split_generations = generations # kolik generací splitu ještě zbývá


func set_speed_multiplier(mult: float) -> void:
	if base_speed == 0.0: # když by náhodou base_speed nebyl nastaven
		base_speed = speed # uložíme aktuální rychlost
	speed = base_speed * mult # přepočítáme rychlost podle multiplikátoru


func set_chain(jumps: int, range: float) -> void:
	chain_jumps_remaining = jumps # nastavíme počet chain skoků
	chain_range = range # nastavíme dosah chainu
	_hit_enemies.clear() # vyčistíme seznam zasažených cílových enemáků (pokud ho později použijeme)


# ---- Ashe R – zapínání/vypínání piercing módu z R zóny ----
func set_pierce_in_zone(enabled: bool) -> void:
	# Tohle volá Ashe R zóna v _update_bullets() podle toho,
	# jestli je střela uvnitř / vně kruhu.
	if not enabled and _pierce_in_zone:
		# když piercing mód končí, vynulujeme seznam
		_pierce_hit_enemies.clear()

	_pierce_in_zone = enabled


func _on_body_entered(body: Node) -> void:
	# Kolize se vším, co má tělo (PhysicsBody2D)

	if not body.is_in_group("enemy"): # ignorujeme cokoliv, co není enemy
		return
	if body.has_method("is_dead") and body.is_dead(): # mrtvé cíle ignorujeme
		return

	# Pokud jsme v piercing módu a už jsme tohoto enemáka trefili,
	# nechceme ho znovu hitovat každým frame kolize.
	if _pierce_in_zone and body in _pierce_hit_enemies:
		return

	var did_hit := false # flag jestli jsme skutečně dali damage

	if body.has_method("take_damage"): # pokud target umí přijmout damage
		body.take_damage(damage) # udělíme damage
		did_hit = true # označíme, že zásah proběhl

	if body.has_method("apply_knockback"): # pokud umí knockback
		body.apply_knockback(_direction) # aplikujeme knockback směrem letu střely

	if not did_hit: # pokud jsme vlastně nic nezasáhli
		return # dál nic neřešíme

	# ===== PIERCE MÓD UVNITŘ ASHE R ZÓNY =====
	if _pierce_in_zone:
		# uvnitř zóny: střela má „nekonečný pierce“
		# => jen si poznamenáme, že jsme tohoto enemáka už trefili
		_pierce_hit_enemies.append(body)
		# chain/split/pierce_remaining se uvnitř R zóny neřeší
		# střela letí dál, dokud nedojde lifetime nebo neopustí zónu
		return

	# ===== KLASICKÁ LOGIKA MIMO R ZÓNU =====

	# ---- CHAIN BOUNCE ----
	if chain_jumps_remaining > 0: # pokud má střela ještě chain skoky
		_hit_enemies.append(body) # přidáme current cíl do seznamu (do budoucna na anti-repeat)
		if _spawn_chain_bullet(body as Node2D): # zkusíme vytvořit další chain střelu
			_destroy_bullet() # pokud se chain povedl, tahle střela končí
			return

	# ---- SPLIT ----
	if split_on_hit and split_generations > 0: # pokud máme povolený split a ještě generace
		_spawn_split_bullets() # vytvoříme dvě nové střely v úhlech +-split_angle

	# ---- PIERCE ----
	if pierce_remaining > 0: # pokud máme průstřely
		pierce_remaining -= 1 # odečteme jeden průstřel
		if pierce_remaining > 0: # pokud ještě nějaké zbývají
			return # střela letí dál

	# pokud už žádné průstřely nezbyly ⇒ střela zmizí
	_destroy_bullet()


func _spawn_chain_bullet(from_enemy: Node2D) -> bool:
	if _bullet_scene == null: # pokud nemáme scénu pro nový bullet
		return false

	var world := get_tree().current_scene # získáme current scénu
	if world == null or not world.has_node("Enemies"): # pokud nemáme root „Enemies“
		return false

	var enemies_root := world.get_node("Enemies") # root node pro všechny enemáky
	var best: Node2D = null # nejlepší (nejbližší) cíl
	var best_dist2: float = chain_range * chain_range # čtverec maximální vzdálenosti

	for child in enemies_root.get_children(): # projdeme všechny děti v „Enemies“
		if not child.is_in_group("enemy"): # ignorujeme ne-enemy
			continue
		if child == from_enemy: # ignorujeme ten samý cíl
			continue
		if child.has_method("is_dead") and child.is_dead(): # ignorujeme mrtvé
			continue

		var d2 := from_enemy.global_position.distance_squared_to(child.global_position) # spočítáme vzdálenost^2
		if d2 < best_dist2: # pokud je blíž než dosavadní nejlepší
			best_dist2 = d2 # uložíme novou nejlepší vzdálenost
			best = child # a nového nejlepšího nepřítele

	if best == null: # nenašli jsme vhodný další cíl
		return false

	var b := _bullet_scene.instantiate() # vytvoříme nový chain bullet
	world.add_child(b) # přidáme ho do scény
	b.global_position = from_enemy.global_position # start pozice je u předchozího cíle

	var dir := best.global_position - from_enemy.global_position # směr k novému cíli
	if b.has_method("set_direction"):
		b.set_direction(dir) # nastavíme směr (rotace se řeší uvnitř set_direction)
	if b.has_method("set_damage"):
		b.set_damage(damage) # předáme damage

	var mult := 1.0 # výchozí multiplikátor rychlosti
	if base_speed != 0.0: # pokud máme uloženou base_speed
		mult = speed / base_speed # spočítáme aktuální multiplikátor
	if b.has_method("set_speed_multiplier"):
		b.set_speed_multiplier(mult) # nastavíme stejný multiplikátor novému bulletu

	if chain_jumps_remaining - 1 > 0 and b.has_method("set_chain"): # pokud zbývají další skoky
		b.set_chain(chain_jumps_remaining - 1, chain_range) # nastavíme nový počet skoků

	return true # chain bullet byl úspěšně vytvořen


func _spawn_split_bullets() -> void:
	if _bullet_scene == null: # bez scény nemáme co spawnovat
		return

	var world := get_tree().current_scene # current scéna
	if world == null:
		return

	var base_dir := _direction # základní směr aktuální střely
	var angle_rad := deg_to_rad(split_angle_deg) # převedeme split úhel na radiány
	var dir1 := base_dir.rotated(angle_rad) # první směr = +úhel
	var dir2 := base_dir.rotated(-angle_rad) # druhý směr = -úhel

	for d in [dir1, dir2]: # projdeme oba směry
		var b := _bullet_scene.instantiate() # vytvoříme nový bullet
		world.add_child(b) # přidáme do scény
		b.global_position = global_position # start pozice je pozice původní střely

		if b.has_method("set_direction"):
			b.set_direction(d) # nastavíme směr (a rotaci) rozdělené střely
		if b.has_method("set_damage"):
			b.set_damage(damage) # předáme damage

		if pierce_remaining > 0 and b.has_method("set_pierce"):
			b.set_pierce(pierce_remaining) # průstřely přeneseme i na nové střely

		var next_gen := split_generations - 1 # snížíme generaci splitu
		if next_gen > 0 and b.has_method("set_split"):
			b.set_split(true, next_gen) # pokud ještě nějaké generace zbývají, zapneme split i u nich
