extends Control

const HERO_DATA_PATH := "res://data/heroes.json"
const ARENA_SCENE := "res://scenes/Arena.tscn"
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

var heroes: Array = []
var selected_index := 0

@onready var mode_label: Label = $Root/Header/ModeLabel
@onready var hero_list: VBoxContainer = $Root/Content/HeroList
@onready var preview: Control = $Root/Content/Details/HeroPreview
@onready var hero_name: Label = $Root/Content/Details/HeroName
@onready var role_label: Label = $Root/Content/Details/RoleLabel
@onready var stat_label: Label = $Root/Content/Details/StatLabel
@onready var ability_label: Label = $Root/Content/Details/AbilityLabel
@onready var counterplay_label: Label = $Root/Content/Details/CounterplayLabel
@onready var start_button: Button = $Root/Footer/StartButton
@onready var back_button: Button = $Root/Footer/BackButton

func _ready() -> void:
	_load_heroes()
	_build_hero_buttons()
	start_button.pressed.connect(_start_match)
	back_button.pressed.connect(_go_back)
	mode_label.text = "Mode: %s" % GameConfig.selected_mode

	var selected_id := GameConfig.selected_hero_id
	for i in heroes.size():
		if heroes[i].get("id", "") == selected_id:
			selected_index = i
			break
	_select_hero(selected_index)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
	elif event.is_action_pressed("ui_accept"):
		_start_match()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var index: int = event.keycode - KEY_1
			if index < heroes.size():
				_select_hero(index)

func _load_heroes() -> void:
	var file := FileAccess.open(HERO_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open hero data.")
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Hero data must be a JSON object.")
		return

	heroes = parsed.get("heroes", [])

func _build_hero_buttons() -> void:
	for child in hero_list.get_children():
		child.queue_free()

	for i in heroes.size():
		var hero: Dictionary = heroes[i]
		var button := Button.new()
		button.text = "%d  %s" % [i + 1, hero.get("name", "Unknown")]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(260.0, 42.0)
		button.pressed.connect(_select_hero.bind(i))
		hero_list.add_child(button)

func _select_hero(index: int) -> void:
	if heroes.is_empty():
		return

	selected_index = clampi(index, 0, heroes.size() - 1)
	var hero: Dictionary = heroes[selected_index]
	GameConfig.selected_hero_id = hero.get("id", "burst_rifle")
	preview.set_hero(GameConfig.selected_hero_id, 0)

	hero_name.text = hero.get("name", "Unknown")
	role_label.text = "%s | %s" % [String(hero.get("role", "role")).to_upper(), String(hero.get("attack_range", "range")).to_upper()]
	stat_label.text = "Health %d    Speed %d    Damage %d    Difficulty %d" % [
		hero.get("health", 0),
		hero.get("speed", 0),
		hero.get("primary_damage", 0),
		hero.get("difficulty", 0)
	]

	var abilities: Dictionary = hero.get("abilities", {})
	ability_label.text = "Primary: %s\nDash: %s\nControl: %s\nUtility: %s" % [
		abilities.get("primary", ""),
		abilities.get("dash", ""),
		abilities.get("control", ""),
		abilities.get("utility", "")
	]

	var counterplay: Array = hero.get("counterplay", [])
	counterplay_label.text = "Counterplay: %s" % " / ".join(counterplay)

	for i in hero_list.get_child_count():
		var button := hero_list.get_child(i) as Button
		button.disabled = i == selected_index

func _start_match() -> void:
	get_tree().change_scene_to_file(ARENA_SCENE)

func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
