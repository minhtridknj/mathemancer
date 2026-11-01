class_name HUD
extends Control

## Giao diện chính cho trận chiến Mathemancer
## Quản lý: Lưới giải đố, Manh mối Kakuro & Thứ hạng Mìn, Sương mù, Khay bài Poker, và Thanh máu Boss

const TileScene = preload("res://scenes/components/tile.tscn")
const TileView = preload("res://scripts/ui/tile_view.gd")
const ScreenShake = preload("res://scripts/ui/screen_shake.gd")
const GameManagerClass = preload("res://scripts/core/game_manager.gd")
const HandEval = preload("res://scripts/core/hand_evaluator.gd")
const Relics = preload("res://scripts/core/relic_system.gd")
const FontLilita = preload("res://assets/fonts/LilitaOne-Regular.ttf")

@onready var game_manager: GameManagerClass = $GameManager
@onready var screen_shake: ScreenShake = $ScreenShake
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

# UI References
@onready var board_container: GridContainer = $CenterArea/BoardWrapper/BoardMargin/BoardGrid
@onready var row_clues_box: VBoxContainer = $CenterArea/BoardWrapper/RowClues
@onready var col_clues_box: HBoxContainer = $CenterArea/BoardWrapper/BoardMargin/ColClues
@onready var boss_hp_bar: ProgressBar = $TopBar/Margin/HBox/BossPanel/HpBar
@onready var boss_hp_label: Label = $TopBar/Margin/HBox/BossPanel/HpBar/HpLabel
@onready var boss_title_label: Label = $TopBar/Margin/HBox/BossPanel/BossTitle
@onready var plays_label: Label = $BottomBar/VBox/HandControls/PlaysLabel
@onready var gold_label: Label = $TopBar/Margin/HBox/PlayerStats/GoldLabel
@onready var ante_label: Label = $TopBar/Margin/HBox/PlayerStats/AnteLabel
@onready var hand_preview_label: Label = $BottomBar/VBox/HandControls/HandPreviewLabel
@onready var damage_preview_label: Label = $BottomBar/VBox/HandControls/DamagePreviewLabel
@onready var play_button: Button = $BottomBar/VBox/HandControls/PlayButton
@onready var tray_container: HBoxContainer = $BottomBar/VBox/TrayMargin/TrayContainer
@onready var relics_box: HBoxContainer = $TopBar/Margin/HBox/RelicsBox
@onready var damage_popup_label: Label = $DamagePopupLabel
@onready var round_won_modal: PanelContainer = $RoundWonModal
@onready var game_over_modal: PanelContainer = $GameOverModal
@onready var shop_modal: Control = $ShopOverlay

# Preloaded Sounds
var sound_click: AudioStream = preload("res://assets/audio/click1.wav")
var sound_rollover: AudioStream = preload("res://assets/audio/rollover1.wav")
var sound_switch1: AudioStream = preload("res://assets/audio/switch1.wav")
var sound_switch2: AudioStream = preload("res://assets/audio/switch2.wav")

var tile_nodes: Array = [] # 2D Array of TileView
var selected_coords: Array[Vector2i] = []

func _ready() -> void:
	# Kết nối tín hiệu GameManager
	game_manager.tile_revealed.connect(_on_gm_tile_revealed)
	game_manager.tile_flagged.connect(_on_gm_tile_flagged)
	game_manager.mine_triggered.connect(_on_gm_mine_triggered)
	game_manager.stage_dispelled.connect(_on_gm_stage_dispelled)
	game_manager.boss_damaged.connect(_on_gm_boss_damaged)
	game_manager.play_hand_resolved.connect(_on_gm_play_hand_resolved)
	game_manager.round_won.connect(_on_gm_round_won)
	game_manager.game_over.connect(_on_gm_game_over)
	game_manager.plays_changed.connect(_on_gm_plays_changed)
	game_manager.gold_changed.connect(_on_gm_gold_changed)
	
	play_button.pressed.connect(_on_play_button_pressed)
	$RoundWonModal/VBox/ShopButton.pressed.connect(_open_shop)
	$GameOverModal/VBox/RetryButton.pressed.connect(_restart_run)
	if shop_modal and shop_modal.has_signal("shop_closed"):
		shop_modal.shop_closed.connect(func(next_ante: int):
			start_new_round(next_ante)
		)
	
	round_won_modal.visible = false
	game_over_modal.visible = false
	damage_popup_label.visible = false
	
	start_new_round(1)

func play_sfx(stream: AudioStream) -> void:
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()

func start_new_round(ante_num: int) -> void:
	round_won_modal.visible = false
	game_over_modal.visible = false
	selected_coords.clear()
	
	game_manager.start_ante(ante_num)
	_build_board_ui()
	_update_boss_ui()
	_update_stats_ui()
	_update_hand_tray()

func _update_boss_ui() -> void:
	var boss_names := [
		"",
		"ARITHMETIC IMP - NUMERIS",
		"MINISTER OF KAKURO - SUMUS",
		"SUDOKU METEOR - ORDRIS",
		"VOID ARITHMANCER - ZEROX",
		"POLYHEDRAL MASTER - POLYGON",
		"HYPERCUBE ARCHON - TESSERACT",
		"LORD OF PROBABILITY - FORTUNA",
		"SUPREME MATHEMANCER - CHRONOS"
	]
	var b_name: String = boss_names[game_manager.ante] if game_manager.ante < boss_names.size() else "SUPREME BOSS"
	boss_title_label.text = "ANTE %d: %s" % [game_manager.ante, b_name]
	boss_hp_bar.max_value = game_manager.max_boss_hp
	boss_hp_bar.value = game_manager.boss_hp
	boss_hp_label.text = "%d / %d HP" % [game_manager.boss_hp, game_manager.max_boss_hp]

func _update_stats_ui() -> void:
	gold_label.text = "🪙 %d GOLD" % game_manager.gold
	ante_label.text = "ANTE: %d / 8" % game_manager.ante
	plays_label.text = "⚔️ PLAYS: %d / %d" % [game_manager.plays_left, game_manager.max_plays]
	_update_relics_ui()

func _update_relics_ui() -> void:
	for child in relics_box.get_children():
		child.queue_free()
	for relic_id in game_manager.owned_relics:
		if Relics.RELIC_DEFINITIONS.has(relic_id):
			var r_info: Dictionary = Relics.RELIC_DEFINITIONS[relic_id]
			var badge := Label.new()
			badge.text = "[ %s ]" % r_info.name
			badge.tooltip_text = r_info.desc
			badge.add_theme_color_override("font_color", Color("#ffd24d"))
			relics_box.add_child(badge)

func _build_board_ui() -> void:
	for child in board_container.get_children():
		child.queue_free()
	tile_nodes.clear()
	
	var sz: int = game_manager.grid_size
	board_container.columns = sz
	
	# Xây dựng Column Clues và Row Clues
	_update_clues_ui()
		
	# Xây dựng Bàn cờ các ô số
	for r in range(sz):
		var row_tiles: Array = []
		for c in range(sz):
			var tile: TileView = TileScene.instantiate()
			var cell_data: Dictionary = game_manager.board_data.cells[r][c]
			var is_rev: bool = game_manager.revealed[r][c]
			var is_flg: bool = game_manager.flagged[r][c]
			var is_exh: bool = game_manager.exhausted[r][c]
			
			tile.setup(r, c, cell_data, is_rev, is_flg, is_exh)
			tile.tile_clicked.connect(_on_tile_clicked)
			tile.tile_selected_toggled.connect(_on_tile_selected_toggled)
			board_container.add_child(tile)
			row_tiles.append(tile)
		tile_nodes.append(row_tiles)

func _update_clues_ui() -> void:
	for child in row_clues_box.get_children():
		child.queue_free()
	for child in col_clues_box.get_children():
		child.queue_free()
		
	var sz: int = game_manager.grid_size
	
	# Xây dựng Column Clues (Kakuro Sum và Thứ hạng mìn phía trên)
	for c in range(sz):
		var clue_data: Dictionary = game_manager.board_data.col_clues[c]
		var panel := _create_clue_badge(clue_data, false)
		col_clues_box.add_child(panel)
		
	# Ô góc trên bên trái (Corner Header) để căn hàng ngang chuẩn xác tuyệt đối với ColClues và BoardGrid
	var corner := PanelContainer.new()
	corner.custom_minimum_size = Vector2(80, 48)
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.bg_color = Color("#11131c")
	sb.border_color = Color("#1d2233")
	sb.set_border_width_all(1)
	corner.add_theme_stylebox_override("panel", sb)
	
	var corner_lbl := Label.new()
	corner_lbl.text = "∑ / Rank"
	corner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	corner_lbl.add_theme_font_override("font", FontLilita)
	corner_lbl.add_theme_font_size_override("font_size", 12)
	corner_lbl.add_theme_color_override("font_color", Color("#404a68"))
	corner.add_child(corner_lbl)
	corner.tooltip_text = "Clues Legend:\n∑ = Safe Numbers Sum\nRank = Relative Mine Count (Rank 1 has fewest mines)"
	row_clues_box.add_child(corner)
		
	# Xây dựng Row Clues
	for r in range(sz):
		var r_clue: Dictionary = game_manager.board_data.row_clues[r]
		var r_panel := _create_clue_badge(r_clue, true)
		row_clues_box.add_child(r_panel)

func _create_clue_badge(clue_data: Dictionary, is_row: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_border_width_all(1)
	
	if is_row:
		pc.custom_minimum_size = Vector2(80, 64)
	else:
		pc.custom_minimum_size = Vector2(64, 48)
		
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	pc.add_child(vbox)
	
	# Kiểm tra Sương mù (Fog of War)
	var is_locked: bool = clue_data.unlocked_at_stage > game_manager.current_stage
	if is_locked:
		sb.bg_color = Color("#11131c")
		sb.border_color = Color("#1d2233")
		pc.add_theme_stylebox_override("panel", sb)
		
		var fog_label := Label.new()
		fog_label.text = "🔒 FOG"
		fog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fog_label.add_theme_font_override("font", FontLilita)
		fog_label.add_theme_font_size_override("font_size", 14)
		fog_label.add_theme_color_override("font_color", Color("#5a6480"))
		vbox.add_child(fog_label)
		pc.tooltip_text = "🔒 Fog of War: Play a hand to dispel the fog and unlock this clue!"
	else:
		sb.bg_color = Color("#181c2b")
		sb.border_color = Color("#2e3750")
		pc.add_theme_stylebox_override("panel", sb)
		
		var sum_lbl := Label.new()
		sum_lbl.text = "∑ %d" % clue_data.sum
		sum_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sum_lbl.add_theme_font_override("font", FontLilita)
		sum_lbl.add_theme_font_size_override("font_size", 16)
		sum_lbl.add_theme_color_override("font_color", Color("#4dd2ff"))
		vbox.add_child(sum_lbl)
		
		var rank_lbl := Label.new()
		rank_lbl.text = "Rank %d" % clue_data.rank
		rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_lbl.add_theme_font_override("font", FontLilita)
		rank_lbl.add_theme_font_size_override("font_size", 13)
		rank_lbl.add_theme_color_override("font_color", Color("#ffd24d"))
		vbox.add_child(rank_lbl)
		
		var direction := "Row" if is_row else "Column"
		pc.tooltip_text = "%s Clue:\nSafe sum = %d\nMine Rank = %d (Rank 1 has lowest mines)" % [direction, clue_data.sum, clue_data.rank]
		
	return pc

func _on_tile_clicked(r: int, c: int, is_right_click: bool) -> void:
	if is_right_click:
		play_sfx(sound_rollover)
		game_manager.toggle_flag(r, c)
	else:
		play_sfx(sound_click)
		game_manager.click_tile(r, c)

func _on_tile_selected_toggled(r: int, c: int, is_selected: bool) -> void:
	var coord := Vector2i(r, c)
	if is_selected:
		if selected_coords.size() < 5 and not selected_coords.has(coord):
			selected_coords.append(coord)
			play_sfx(sound_switch1)
		else:
			# Đã chọn tối đa 5 lá
			tile_nodes[r][c].set_selected(false)
	else:
		selected_coords.erase(coord)
		play_sfx(sound_rollover)
	_update_hand_tray()

func _return_card_from_tray(p: Vector2i) -> void:
	if selected_coords.has(p):
		selected_coords.erase(p)
		if p.x < tile_nodes.size() and p.y < tile_nodes[p.x].size():
			tile_nodes[p.x][p.y].set_selected(false)
		play_sfx(sound_rollover)
		_update_hand_tray()

func _update_hand_tray() -> void:
	for child in tray_container.get_children():
		child.queue_free()
		
	# Xây dựng 5 ô thẻ bài trên hàng khay chơi (Hand Tray Row)
	for i in range(5):
		if i < selected_coords.size():
			var p: Vector2i = selected_coords[i]
			var cell: Dictionary = game_manager.board_data.cells[p.x][p.y]
			var card_slot := PanelContainer.new()
			card_slot.custom_minimum_size = Vector2(72, 88)
			card_slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			var s_color: Color = TileView.SUIT_COLORS.get(cell.suit, Color.WHITE)
			var s_icon: String = TileView.SUIT_ICONS.get(cell.suit, "")
			
			var sb := StyleBoxFlat.new()
			sb.corner_radius_top_left = 8
			sb.corner_radius_top_right = 8
			sb.corner_radius_bottom_left = 8
			sb.corner_radius_bottom_right = 8
			sb.bg_color = Color("#181f33")
			sb.border_color = s_color
			sb.set_border_width_all(2)
			sb.shadow_color = Color(0, 0, 0, 0.4)
			sb.shadow_size = 4
			card_slot.add_theme_stylebox_override("panel", sb)
			
			var vbox := VBoxContainer.new()
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_theme_constant_override("separation", 2)
			card_slot.add_child(vbox)
			
			var val_lbl := Label.new()
			val_lbl.text = str(cell.val)
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			val_lbl.add_theme_font_override("font", FontLilita)
			val_lbl.add_theme_font_size_override("font_size", 22)
			val_lbl.add_theme_color_override("font_color", s_color)
			vbox.add_child(val_lbl)
			
			var suit_lbl := Label.new()
			suit_lbl.text = s_icon
			suit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			suit_lbl.add_theme_font_size_override("font_size", 16)
			vbox.add_child(suit_lbl)
			
			var ret_lbl := Label.new()
			ret_lbl.text = "✕ RETURN"
			ret_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ret_lbl.add_theme_font_size_override("font_size", 9)
			ret_lbl.add_theme_color_override("font_color", Color("#94a3b8"))
			vbox.add_child(ret_lbl)
			
			card_slot.tooltip_text = "Card [ %d %s ]\nClick to return this card to the board" % [cell.val, s_icon]
			
			# Tương tác click để bỏ bài quay trở lại bàn cờ
			card_slot.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_return_card_from_tray(p)
			)
			tray_container.add_child(card_slot)
		else:
			# Ô khay bài còn trống (Empty Slot)
			var empty_slot := PanelContainer.new()
			empty_slot.custom_minimum_size = Vector2(72, 88)
			
			var sb := StyleBoxFlat.new()
			sb.corner_radius_top_left = 8
			sb.corner_radius_top_right = 8
			sb.corner_radius_bottom_left = 8
			sb.corner_radius_bottom_right = 8
			sb.bg_color = Color("#0e121d")
			sb.border_color = Color("#22283a")
			sb.set_border_width_all(1)
			empty_slot.add_theme_stylebox_override("panel", sb)
			
			var vbox := VBoxContainer.new()
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			vbox.add_theme_constant_override("separation", 2)
			empty_slot.add_child(vbox)
			
			var num_lbl := Label.new()
			num_lbl.text = "[ %d ]" % (i + 1)
			num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			num_lbl.add_theme_font_override("font", FontLilita)
			num_lbl.add_theme_font_size_override("font_size", 14)
			num_lbl.add_theme_color_override("font_color", Color("#3b4461"))
			vbox.add_child(num_lbl)
			
			var hint_lbl := Label.new()
			hint_lbl.text = "EMPTY"
			hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint_lbl.add_theme_font_size_override("font_size", 9)
			hint_lbl.add_theme_color_override("font_color", Color("#2a3249"))
			vbox.add_child(hint_lbl)
			
			empty_slot.tooltip_text = "Card Slot %d (Empty)\nSelect a revealed tile on the board to place it here" % (i + 1)
			tray_container.add_child(empty_slot)
			
	if selected_coords.is_empty():
		hand_preview_label.text = "Select 1 to 5 revealed tiles on the board"
		damage_preview_label.text = "0 Chips × 0 Mult = 0 Damage"
		play_button.disabled = true
		return
		
	var selected_cards: Array[Dictionary] = []
	for p in selected_coords:
		var cell: Dictionary = game_manager.board_data.cells[p.x][p.y]
		selected_cards.append(cell)
		
	var eval_res: Dictionary = HandEval.evaluate_hand(selected_cards)
	var extra_state := {"correct_flags": game_manager.correct_flags}
	eval_res = Relics.apply_relic_modifiers(eval_res, selected_cards, game_manager.owned_relics, extra_state)
	
	var chips: int = eval_res.total_chips
	var mult: float = eval_res.mult
	var dmg: int = int(round(float(chips) * mult))
	
	hand_preview_label.text = "🔥 %s (%s)" % [eval_res.get("name", ""), eval_res.get("type", "")]
	damage_preview_label.text = "%d Chips × %.1f Mult = %d Damage" % [chips, mult, dmg]
	play_button.disabled = (game_manager.plays_left <= 0)

func _on_play_button_pressed() -> void:
	if selected_coords.is_empty():
		return
	play_sfx(sound_switch2)
	game_manager.play_hand(selected_coords)
	selected_coords.clear()
	_update_hand_tray()

# GameManager Signal Handlers
func _on_gm_tile_revealed(r: int, c: int, cell_data: Dictionary) -> void:
	if r < tile_nodes.size() and c < tile_nodes[r].size():
		tile_nodes[r][c].reveal(cell_data)

func _on_gm_tile_flagged(r: int, c: int, is_flagged: bool) -> void:
	if r < tile_nodes.size() and c < tile_nodes[r].size():
		tile_nodes[r][c].set_flag(is_flagged)

func _on_gm_mine_triggered(r: int, c: int) -> void:
	play_sfx(sound_switch2)
	screen_shake.add_trauma(0.65) # Rung lắc dữ dội khi nổ mìn
	if r < tile_nodes.size() and c < tile_nodes[r].size():
		tile_nodes[r][c].trigger_explosion()

func _on_gm_stage_dispelled(_new_stage: int) -> void:
	# Cập nhật lại các ô clue (giải trừ sương mù cho các hàng/cột tiếp theo)
	play_sfx(sound_switch1)
	_update_clues_ui()

func _on_gm_boss_damaged(amount: int, current_hp: int) -> void:
	# Hiệu ứng tụt máu mượt mà
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(boss_hp_bar, "value", float(current_hp), 0.35)
	boss_hp_label.text = "%d / %d HP" % [current_hp, game_manager.max_boss_hp]
	
	# Popup số sát thương bay lên
	damage_popup_label.visible = true
	damage_popup_label.text = "-%d HP!" % amount
	damage_popup_label.scale = Vector2(1.3, 1.3)
	damage_popup_label.modulate = Color(1.5, 0.4, 0.4, 1.0)
	var p_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	p_tw.tween_property(damage_popup_label, "position:y", damage_popup_label.position.y - 30.0, 0.6)
	p_tw.parallel().tween_property(damage_popup_label, "modulate:a", 0.0, 0.6)
	p_tw.tween_callback(func():
		damage_popup_label.visible = false
		damage_popup_label.position.y += 30.0
	)
	
	if amount >= 150:
		screen_shake.add_trauma(0.35)

func _on_gm_play_hand_resolved(_res: Dictionary) -> void:
	# Đánh dấu các ô đã đánh sang trạng thái exhausted
	for r in range(game_manager.grid_size):
		for c in range(game_manager.grid_size):
			if game_manager.exhausted[r][c]:
				tile_nodes[r][c].set_exhausted(true)

func _on_gm_plays_changed(new_plays: int) -> void:
	plays_label.text = "⚔️ PLAYS: %d / %d" % [new_plays, game_manager.max_plays]

func _on_gm_gold_changed(new_gold: int) -> void:
	gold_label.text = "🪙 %d GOLD" % new_gold

func _on_gm_round_won() -> void:
	round_won_modal.visible = true
	$RoundWonModal/VBox/MsgLabel.text = "🎉 ANTE %d CLEARED!\nReward: +%d Gold" % [game_manager.ante, 5 + game_manager.plays_left * 2]

func _on_gm_game_over() -> void:
	game_over_modal.visible = true
	var msg_label: Label = $GameOverModal/VBox/MsgLabel
	if game_manager.boss_hp > 0 and game_manager.get_remaining_safe_tiles_count() == 0:
		msg_label.text = "All safe tiles on the board have been exhausted,\nbut the Boss survived with %d HP left!\nTry crafting stronger poker hands next run." % game_manager.boss_hp
	else:
		msg_label.text = "You ran out of plays before defeating the Boss (%d HP left).\nTry crafting stronger poker hands next run!" % game_manager.boss_hp

func _open_shop() -> void:
	round_won_modal.visible = false
	if shop_modal and shop_modal.has_method("open_shop"):
		shop_modal.open_shop(game_manager)

func _restart_run() -> void:
	game_manager.owned_relics.clear()
	game_manager.owned_scrolls.clear()
	game_manager.gold = 5
	start_new_round(1)
