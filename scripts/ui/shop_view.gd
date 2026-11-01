class_name ShopView
extends Control

## Giao diện Cửa Hàng giữa các vòng đấu (Shop Phase phong cách Balatro)
## Cung cấp Cổ Vật (Jokers) bổ trợ và Cuộn Giấy Phép (Tarots) can thiệp bàn cờ

signal shop_closed(next_ante: int)

const Relics = preload("res://scripts/core/relic_system.gd")
const Scrolls = preload("res://scripts/core/scroll_system.gd")

@onready var gold_label: Label = $PanelContainer/VBox/Header/GoldLabel
@onready var relics_container: HBoxContainer = $PanelContainer/VBox/Content/RelicsSection/RelicsContainer
@onready var scrolls_container: HBoxContainer = $PanelContainer/VBox/Content/ScrollsSection/ScrollsContainer
@onready var next_button: Button = $PanelContainer/VBox/Footer/NextButton
@onready var reroll_button: Button = $PanelContainer/VBox/Footer/RerollButton

var game_manager = null
var offered_relics: Array[String] = []
var offered_scrolls: Array[String] = []

func _ready() -> void:
	visible = false
	if next_button:
		next_button.pressed.connect(_on_next_pressed)
	if reroll_button:
		reroll_button.pressed.connect(_on_reroll_pressed)

func open_shop(p_game_manager) -> void:
	game_manager = p_game_manager
	visible = true
	_generate_shop_inventory()
	_render_shop()

func _generate_shop_inventory() -> void:
	offered_relics.clear()
	offered_scrolls.clear()
	
	var all_relic_ids = Relics.RELIC_DEFINITIONS.keys()
	all_relic_ids.shuffle()
	for r_id in all_relic_ids:
		if not game_manager.owned_relics.has(r_id):
			offered_relics.append(r_id)
			if offered_relics.size() >= 3:
				break
				
	var all_scroll_ids = Scrolls.SCROLL_DEFINITIONS.keys()
	all_scroll_ids.shuffle()
	for s_id in all_scroll_ids:
		offered_scrolls.append(s_id)
		if offered_scrolls.size() >= 2:
			break

func _render_shop() -> void:
	if not game_manager:
		return
		
	gold_label.text = "🪙 GOLD: %d" % game_manager.gold
	reroll_button.disabled = (game_manager.gold < 2)
	
	# Xây dựng danh sách Cổ Vật
	for child in relics_container.get_children():
		child.queue_free()
		
	for relic_id in offered_relics:
		var r_data: Dictionary = Relics.RELIC_DEFINITIONS[relic_id]
		var card = _create_item_card(relic_id, r_data.name, r_data.desc, r_data.cost, true)
		relics_container.add_child(card)
		
	# Xây dựng danh sách Cuộn Giấy
	for child in scrolls_container.get_children():
		child.queue_free()
		
	for scroll_id in offered_scrolls:
		var s_data: Dictionary = Scrolls.SCROLL_DEFINITIONS[scroll_id]
		var card = _create_item_card(scroll_id, s_data.name, s_data.desc, s_data.cost, false)
		scrolls_container.add_child(card)

func _create_item_card(item_id: String, item_name: String, item_desc: String, cost: int, is_relic: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(160, 200)
	
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.bg_color = Color("#1e2235")
	sb.border_color = Color("#e5b83b") if is_relic else Color("#8892b0")
	sb.set_border_width_all(2)
	pc.add_theme_stylebox_override("panel", sb)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	pc.add_child(vbox)
	
	var title := Label.new()
	var icon_prefix := ""
	if is_relic and Relics.RELIC_DEFINITIONS.has(item_id):
		icon_prefix = Relics.RELIC_DEFINITIONS[item_id].get("icon", "") + " "
	title.text = "%s%s" % [icon_prefix, item_name]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color("#ffd24d") if is_relic else Color("#4dd2ff"))
	vbox.add_child(title)
	
	var desc := Label.new()
	desc.text = item_desc
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc)
	
	var buy_btn := Button.new()
	buy_btn.text = "🪙 BUY (%d Gold)" % cost
	buy_btn.disabled = (game_manager.gold < cost)
	if is_relic and game_manager.owned_relics.size() >= 5:
		buy_btn.disabled = true
		buy_btn.text = "RELICS FULL (5/5)"
	elif not is_relic and game_manager.owned_scrolls.size() >= 2:
		buy_btn.disabled = true
		buy_btn.text = "SCROLLS FULL (2/2)"
		
	buy_btn.pressed.connect(func():
		if is_relic:
			if game_manager.buy_relic(item_id):
				offered_relics.erase(item_id)
				_render_shop()
		else:
			if game_manager.buy_scroll(item_id):
				offered_scrolls.erase(item_id)
				_render_shop()
	)
	vbox.add_child(buy_btn)
	
	return pc

func _on_reroll_pressed() -> void:
	if game_manager and game_manager.gold >= 2:
		game_manager.gold -= 2
		_generate_shop_inventory()
		_render_shop()

func _on_next_pressed() -> void:
	visible = false
	if game_manager:
		var next_ante: int = game_manager.ante + 1
		emit_signal("shop_closed", next_ante)
