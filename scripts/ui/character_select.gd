## Character selection screen — lets the player pick a starting character.
extends Control

const CHARACTERS: Array[Dictionary] = [
	{
		"id": "warrior",
		"name": "Warrior",
		"hp": 60,
		"speed": 100,
		"energy": 3,
		"move": 3,
		"description": "A stalwart frontliner with high HP and balanced offense.",
	},
	{
		"id": "mage",
		"name": "Mage",
		"hp": 40,
		"speed": 80,
		"energy": 3,
		"move": 2,
		"description": "An energy mage who builds stacks to unleash devastating spells.",
	},
	{
		"id": "rogue",
		"name": "Rogue",
		"hp": 45,
		"speed": 70,
		"energy": 3,
		"move": 4,
		"description": "A swift striker who excels at positioning and quick combos.",
	},
	{
		"id": "cleric",
		"name": "Cleric",
		"hp": 50,
		"speed": 90,
		"energy": 3,
		"move": 3,
		"description": "A holy healer who builds faith to shield allies and smite foes.",
	},
	{
		"id": "necromancer",
		"name": "Necromancer",
		"hp": 35,
		"speed": 85,
		"energy": 3,
		"move": 2,
		"description": "A dark caster who sacrifices allies to harvest souls for devastating power.",
	},
]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Vertical layout
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 40)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Choose Your Champion"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(title)

	# Character panels container
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(hbox)

	for data: Dictionary in CHARACTERS:
		var panel := _create_character_panel(data)
		hbox.add_child(panel)


func _create_character_panel(data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 340)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.2, 1.0)
	style.border_color = Color(0.4, 0.4, 0.55, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Name
	var name_label := Label.new()
	name_label.text = data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	vbox.add_child(name_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Stats
	var stats: Array[Array] = [
		["HP", str(data["hp"])],
		["Speed", str(data["speed"])],
		["Energy", str(data["energy"])],
		["Move", str(data["move"])],
	]
	for stat: Array in stats:
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = stat[0]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		line.add_child(label)
		var value := Label.new()
		value.text = stat[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		line.add_child(value)
		vbox.add_child(line)

	# Description
	var desc := Label.new()
	desc.text = data["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc)

	# Select button
	var button := Button.new()
	button.text = "Select"
	button.custom_minimum_size.y = 36
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.45, 0.3, 1.0)
	btn_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.55, 0.35, 1.0)
	btn_hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", btn_hover)
	button.pressed.connect(_on_character_selected.bind(data["id"]))
	vbox.add_child(button)

	return panel


func _on_character_selected(character_id: String) -> void:
	GameManager.start_new_run_with_character(character_id)
