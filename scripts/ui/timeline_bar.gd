## Displays the turn order timeline as a vertical list of character portraits/names.
## Updates whenever the timeline changes.
class_name TimelineBar
extends VBoxContainer

@onready var title_label: Label = %TitleLabel

const PREVIEW_COUNT: int = 10


func _ready() -> void:
	BattleManager.timeline_updated.connect(_refresh)
	BattleManager.turn_started.connect(func(_c: CharacterData) -> void: _refresh())
	BattleManager.battle_started.connect(_refresh)


func _refresh() -> void:
	# Remove old entries (keep the title label)
	for child: Node in get_children():
		if child != title_label:
			child.queue_free()

	var preview: Array[CharacterData] = BattleManager.get_timeline_preview(PREVIEW_COUNT)
	for i: int in preview.size():
		var ch: CharacterData = preview[i]
		var entry: HBoxContainer = _create_entry(ch, i == 0)
		add_child(entry)


func _create_entry(character: CharacterData, is_current: bool) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	# Portrait
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(28, 28)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if character.portrait:
		portrait.texture = character.portrait
	hbox.add_child(portrait)

	# Name + speed
	var label := Label.new()
	var arrow: String = ">> " if is_current else "     "
	label.text = "%s%s (SPD %d)" % [arrow, character.character_name, character.get_effective_speed()]

	if character.faction == Enums.Faction.PLAYER:
		label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

	if is_current:
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3))

	hbox.add_child(label)

	# HP indicator
	var hp_label := Label.new()
	hp_label.text = "%d/%d" % [character.current_hp, character.max_hp]
	hp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hbox.add_child(hp_label)

	return hbox
