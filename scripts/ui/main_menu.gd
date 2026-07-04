extends Control

@onready var one_v_one_button: Button = $Panel/VBox/OneVOneButton
@onready var three_v_three_button: Button = $Panel/VBox/ThreeVThreeButton
@onready var hero_lab_button: Button = $Panel/VBox/HeroLabButton

const CHARACTER_SELECT_SCENE := "res://scenes/CharacterSelect.tscn"

func _ready() -> void:
	one_v_one_button.pressed.connect(_start_one_v_one)
	three_v_three_button.pressed.connect(_start_three_v_three)
	hero_lab_button.pressed.connect(_open_hero_lab)

func _start_one_v_one() -> void:
	GameConfig.selected_mode = "1v1"
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _start_three_v_three() -> void:
	GameConfig.selected_mode = "3v3"
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _open_hero_lab() -> void:
	GameConfig.selected_mode = "Hero Lab"
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)
