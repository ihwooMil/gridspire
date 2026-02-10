## Custom ScrollContainer that converts vertical wheel input to horizontal scrolling.
extends ScrollContainer

const SCROLL_STEP: int = 80


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				scroll_horizontal = maxi(scroll_horizontal - SCROLL_STEP, 0)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				scroll_horizontal += SCROLL_STEP
				accept_event()
