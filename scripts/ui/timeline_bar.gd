## Displays the turn order timeline as a horizontal slider at the top of the screen.
## Shows character portraits in order with the current turn highlighted.
class_name TimelineBar
extends HBoxContainer

const PREVIEW_COUNT: int = 10
const ENTRY_WIDTH: float = 80.0
const ENTRY_HEIGHT: float = 56.0


func _ready() -> void:
	BattleManager.timeline_updated.connect(_refresh)
	BattleManager.turn_started.connect(func(_c: CharacterData) -> void: _refresh())
	BattleManager.battle_started.connect(_refresh)


func _refresh() -> void:
	for child: Node in get_children():
		child.queue_free()

	var preview: Array[CharacterData] = BattleManager.get_timeline_preview(PREVIEW_COUNT)
	for i: int in preview.size():
		var ch: CharacterData = preview[i]
		var entry: PanelContainer = _create_entry(ch, i == 0)
		add_child(entry)

		# Draw arrow between entries (except after last)
		if i < preview.size() - 1:
			var arrow := Label.new()
			arrow.text = ">"
			arrow.add_theme_font_size_override("font_size", 14)
			arrow.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			add_child(arrow)


func _create_entry(character: CharacterData, is_current: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ENTRY_WIDTH, ENTRY_HEIGHT)

	# Background style
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2

	if is_current:
		style.bg_color = Color(0.4, 0.35, 0.1, 0.9)
		style.border_color = Color(1.0, 0.9, 0.3)
		style.border_width_bottom = 3
	elif character.faction == Enums.Faction.PLAYER:
		style.bg_color = Color(0.1, 0.15, 0.25, 0.8)
		style.border_color = Color(0.3, 0.6, 1.0, 0.5)
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.25, 0.1, 0.1, 0.8)
		style.border_color = Color(1.0, 0.3, 0.3, 0.5)
		style.border_width_bottom = 2

	panel.add_theme_stylebox_override("panel", style)

	# Content layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# Name
	var name_label := Label.new()
	name_label.text = character.character_name
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_current:
		name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))
	elif character.faction == Enums.Faction.PLAYER:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	vbox.add_child(name_label)

	# HP bar
	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 8)
	hp_bar.max_value = character.max_hp
	hp_bar.value = character.current_hp
	hp_bar.show_percentage = false
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.2, 0.7, 0.3)
	hp_style.corner_radius_top_left = 2
	hp_style.corner_radius_top_right = 2
	hp_style.corner_radius_bottom_left = 2
	hp_style.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	vbox.add_child(hp_bar)

	# HP text + SPD
	var info_label := Label.new()
	info_label.text = "%dHP  SPD%d" % [character.current_hp, character.get_effective_speed()]
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	return panel
