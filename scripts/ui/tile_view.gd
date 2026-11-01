class_name TileView
extends PanelContainer

## Thành phần giao diện của từng ô số trên bàn cờ Mathemancer
## Hỗ trợ: Lật 3D (flip Tween), Cắm cờ nảy, Nổ mìn bùng cháy, Đánh dấu ô đã tiêu hao

signal tile_clicked(r: int, c: int, is_right_click: bool)
signal tile_selected_toggled(r: int, c: int, is_selected: bool)

@onready var bg_panel: Panel = $BgPanel
@onready var val_label: Label = $CenterContainer/VBoxContainer/ValLabel
@onready var suit_label: Label = $CenterContainer/VBoxContainer/SuitLabel
@onready var status_label: Label = $StatusLabel
@onready var anim_tween: Tween = null

var row: int = 0
var col: int = 0
var cell_data: Dictionary = {}
var is_revealed: bool = false
var is_flagged: bool = false
var is_exhausted: bool = false
var is_selected: bool = false

# Bảng màu đại diện cho 4 Chất nguyên tố
const SUIT_COLORS = {
	"flame": Color("#ff4d4d"),   # Hỏa - Đỏ rực
	"frost": Color("#4dd2ff"),   # Băng - Lam sáng
	"spark": Color("#ffd24d"),   # Lôi - Vàng điện
	"shadow": Color("#b84dff"),  # Ám - Tím huyền bí
	"neutral": Color("#8892b0")
}

const SUIT_ICONS = {
	"flame": "🔥",
	"frost": "❄️",
	"spark": "⚡",
	"shadow": "🌑"
}

func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_update_visuals()

func setup(r: int, c: int, p_cell_data: Dictionary, p_revealed: bool, p_flagged: bool, p_exhausted: bool) -> void:
	row = r
	col = c
	cell_data = p_cell_data
	is_revealed = p_revealed
	is_flagged = p_flagged
	is_exhausted = p_exhausted
	is_selected = false
	_update_visuals()

func set_tile_data(p_cell_data: Dictionary) -> void:
	cell_data = p_cell_data
	_update_visuals()

func update_cell_data(p_cell_data: Dictionary) -> void:
	cell_data = p_cell_data
	_update_visuals()

func _on_gui_input(event: InputEvent) -> void:
	if is_exhausted:
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_revealed:
				# Click mở ô bí mật
				if not is_flagged:
					emit_signal("tile_clicked", row, col, false)
			else:
				# Ô đã mở và an toàn -> chọn hoặc bỏ chọn đưa vào Khay bài
				if not cell_data.get("is_mine", false):
					toggle_selection()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if not is_revealed:
				emit_signal("tile_clicked", row, col, true)

func toggle_selection() -> void:
	if is_exhausted or not is_revealed:
		return
	is_selected = not is_selected
	_update_visuals()
	_update_selection_anim()
	emit_signal("tile_selected_toggled", row, col, is_selected)

func set_selected(selected: bool) -> void:
	if is_selected == selected:
		return
	is_selected = selected
	_update_visuals()
	_update_selection_anim()

func _update_selection_anim() -> void:
	# Đảm bảo không thay đổi position hoặc scale làm xô lệch hoặc đè lên các ô khác trong GridContainer
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_selected:
		tw.tween_property(self, "modulate", Color(1.25, 1.25, 1.35, 1.0), 0.15)
	else:
		tw.tween_property(self, "modulate", Color.WHITE, 0.15)

func reveal(p_cell_data: Dictionary, animate: bool = true) -> void:
	cell_data = p_cell_data
	is_revealed = true
	is_flagged = false
	
	if animate:
		# Animation lật thẻ bài
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		pivot_offset = size / 2.0
		tw.tween_property(self, "scale:x", 0.0, 0.12)
		tw.tween_callback(Callable(self, "_update_visuals"))
		tw.tween_property(self, "scale:x", 1.0, 0.12)
		tw.tween_callback(func(): scale = Vector2.ONE)
	else:
		_update_visuals()

func set_flag(flagged: bool, animate: bool = true) -> void:
	is_flagged = flagged
	_update_visuals()
	if animate and is_flagged:
		# Animation cắm cờ nảy nhẹ
		var tw = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		pivot_offset = size / 2.0
		scale = Vector2(0.85, 0.85)
		tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)
		tw.tween_callback(func(): scale = Vector2.ONE)

func trigger_explosion() -> void:
	# Animation nổ bom đỏ chớp
	is_revealed = true
	_update_visuals()
	var tw = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pivot_offset = size / 2.0
	scale = Vector2(1.2, 1.2)
	modulate = Color(3.0, 0.3, 0.3, 1.0)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.35)
	tw.parallel().tween_property(self, "modulate", Color.WHITE, 0.4)
	tw.tween_callback(func(): scale = Vector2.ONE)

func set_exhausted(exhausted: bool) -> void:
	is_exhausted = exhausted
	is_selected = false
	if is_exhausted:
		modulate = Color(0.5, 0.5, 0.5, 0.45)
	else:
		modulate = Color.WHITE

func _update_visuals() -> void:
	if not is_inside_tree():
		return
		
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	
	if not is_revealed:
		val_label.text = ""
		suit_label.text = ""
		if is_flagged:
			status_label.text = "🚩"
			sb.bg_color = Color("#2a1a1a")
			sb.border_color = Color("#ff4444")
			sb.set_border_width_all(2)
		else:
			status_label.text = "?"
			sb.bg_color = Color("#181c2b")
			sb.border_color = Color("#2f3750")
			sb.set_border_width_all(2)
	else:
		if cell_data.get("is_mine", false):
			status_label.text = "💥"
			val_label.text = ""
			suit_label.text = ""
			sb.bg_color = Color("#3d1414")
			sb.border_color = Color("#ff2222")
			sb.set_border_width_all(2)
		else:
			status_label.text = ""
			var val: int = int(cell_data.get("val", 0))
			var suit: String = str(cell_data.get("suit", "neutral"))
			var suit_color: Color = SUIT_COLORS.get(suit, Color.WHITE)
			var icon: String = SUIT_ICONS.get(suit, "")
			
			val_label.text = str(val)
			suit_label.text = icon
			val_label.add_theme_color_override("font_color", suit_color)
			
			sb.bg_color = Color("#111827")
			if is_selected:
				sb.border_color = Color("#ffd24d") # Golden glowing selection border
				sb.set_border_width_all(3)
				sb.bg_color = Color("#1e2338")
			elif cell_data.get("is_given", false):
				# Ô ban đầu (anchor) có viền vàng hoàng gia
				sb.border_color = Color("#e5b83b")
				sb.set_border_width_all(2)
			else:
				sb.border_color = suit_color.darkened(0.3)
				sb.set_border_width_all(1)
				
	add_theme_stylebox_override("panel", sb)

func _on_mouse_entered() -> void:
	if not is_exhausted and not is_selected:
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate", Color(1.15, 1.15, 1.2, 1.0), 0.1)

func _on_mouse_exited() -> void:
	if not is_exhausted and not is_selected:
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate", Color.WHITE, 0.1)
