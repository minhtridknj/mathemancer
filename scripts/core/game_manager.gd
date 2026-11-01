class_name GameManager
extends Node

## Bộ quản lý Logic chính cho trận đấu trong Mathemancer
## Quản lý lượt chơi, trạng thái bàn cờ, sát thương Boss, sương mù giải đố và tương tác Cổ vật/Cuộn giấy

const BoardGen = preload("res://scripts/core/board_generator.gd")
const HandEval = preload("res://scripts/core/hand_evaluator.gd")
const Relics = preload("res://scripts/core/relic_system.gd")
const Scrolls = preload("res://scripts/core/scroll_system.gd")

signal tile_revealed(r: int, c: int, cell_data: Dictionary)
signal tile_flagged(r: int, c: int, is_flagged: bool)
signal mine_triggered(r: int, c: int)
signal stage_dispelled(new_stage: int)
signal play_hand_resolved(hand_result: Dictionary)
signal boss_damaged(amount: int, current_hp: int)
signal round_won()
signal game_over()
signal gold_changed(new_gold: int)
signal plays_changed(new_plays: int)

var ante: int = 1
var grid_size: int = 4
var boss_hp: int = 200
var max_boss_hp: int = 200
var plays_left: int = 4
var max_plays: int = 4
var discards_left: int = 2
var gold: int = 5
var current_stage: int = 1
var correct_flags: int = 0

var board_data: Dictionary = {}
var revealed: Array = []
var flagged: Array = []
var exhausted: Array = []

var owned_relics: Array[String] = []
var owned_scrolls: Array[String] = []

func start_ante(ante_num: int, seed_val: int = -1) -> Dictionary:
	ante = ante_num
	
	# Định cỡ bàn cờ theo Ante
	if ante <= 2:
		grid_size = 4
	elif ante <= 4:
		grid_size = 5
	elif ante <= 6:
		grid_size = 6
	elif ante == 7:
		grid_size = 7
	else:
		grid_size = 8
		
	# Máu Boss theo Ante (Ante 1: 200 HP để người chơi giải xong bàn cờ có thể hạ gục Boss)
	var hp_table := [0, 200, 600, 1500, 3500, 7500, 15000, 30000, 60000]
	if ante < hp_table.size():
		boss_hp = hp_table[ante]
	else:
		boss_hp = int(60000 * pow(2, ante - 8))
	max_boss_hp = boss_hp
	
	plays_left = max_plays
	discards_left = 2
	current_stage = 1
	correct_flags = 0
	
	# Sinh bàn cờ
	board_data = BoardGen.generate_level(grid_size, ante, seed_val)
	
	# Khởi tạo ma trận trạng thái
	revealed.clear()
	flagged.clear()
	exhausted.clear()
	
	for r in range(grid_size):
		var row_rev: Array[bool] = []
		var row_flg: Array[bool] = []
		var row_exh: Array[bool] = []
		for c in range(grid_size):
			var is_given: bool = board_data.cells[r][c].is_given
			row_rev.append(is_given)
			row_flg.append(false)
			row_exh.append(false)
		revealed.append(row_rev)
		flagged.append(row_flg)
		exhausted.append(row_exh)
		
	emit_signal("plays_changed", plays_left)
	emit_signal("gold_changed", gold)
	return board_data

func click_tile(r: int, c: int) -> bool:
	if r < 0 or r >= grid_size or c < 0 or c >= grid_size:
		return false
	if revealed[r][c] or flagged[r][c] or exhausted[r][c]:
		return false
		
	revealed[r][c] = true
	var cell: Dictionary = board_data.cells[r][c]
	
	if cell.is_mine:
		plays_left -= 1
		emit_signal("mine_triggered", r, c)
		emit_signal("plays_changed", plays_left)
		if plays_left <= 0 or (boss_hp > 0 and get_remaining_safe_tiles_count() == 0):
			emit_signal("game_over")
		return false
	else:
		emit_signal("tile_revealed", r, c, cell)
		return true

func toggle_flag(r: int, c: int) -> bool:
	if r < 0 or r >= grid_size or c < 0 or c >= grid_size:
		return false
	if revealed[r][c] or exhausted[r][c]:
		return false
		
	flagged[r][c] = not flagged[r][c]
	var cell: Dictionary = board_data.cells[r][c]
	if cell.is_mine:
		if flagged[r][c]:
			correct_flags += 1
		else:
			correct_flags = maxi(0, correct_flags - 1)
			
	emit_signal("tile_flagged", r, c, flagged[r][c])
	return true

func get_remaining_safe_tiles_count() -> int:
	var count := 0
	for r in range(grid_size):
		for c in range(grid_size):
			if not board_data.cells[r][c].is_mine and not exhausted[r][c]:
				count += 1
	return count

func play_hand(selected_coords: Array[Vector2i]) -> Dictionary:
	if selected_coords.is_empty() or selected_coords.size() > 5:
		return {}
		
	var cards: Array[Dictionary] = []
	for p in selected_coords:
		if p.x < 0 or p.x >= grid_size or p.y < 0 or p.y >= grid_size:
			continue
		if exhausted[p.x][p.y]:
			continue
		cards.append(board_data.cells[p.x][p.y])
		
	if cards.is_empty():
		return {}
		
	# 1. Tính toán Hand
	var eval_res: Dictionary = HandEval.evaluate_hand(cards)
	
	# 2. Áp dụng hiệu ứng Cổ Vật (Jokers)
	var extra_state := {"correct_flags": correct_flags}
	eval_res = Relics.apply_relic_modifiers(eval_res, cards, owned_relics, extra_state)
	
	# 3. Tính tổng sát thương Chips × Mult
	var total_chips: int = int(eval_res.get("total_chips", 0))
	var mult: float = float(eval_res.get("mult", 1.0))
	var damage: int = int(round(float(total_chips) * mult))
	eval_res["damage"] = damage
	
	# 4. Gây sát thương Boss
	boss_hp = maxi(0, boss_hp - damage)
	emit_signal("boss_damaged", damage, boss_hp)
	
	# 5. Đánh dấu các ô đã đánh là Exhausted (không thể chọn lại)
	for p in selected_coords:
		exhausted[p.x][p.y] = true
		
	# 6. Trừ 1 lượt Play Hand & giải trừ sương mù tầng tiếp theo
	plays_left -= 1
	current_stage += 1
	emit_signal("plays_changed", plays_left)
	emit_signal("stage_dispelled", current_stage)
	emit_signal("play_hand_resolved", eval_res)
	
	# 7. Kiểm tra Thắng / Thua
	if boss_hp <= 0:
		var reward := 5 + plays_left * 2
		gold += reward
		emit_signal("gold_changed", gold)
		emit_signal("round_won")
	elif plays_left <= 0 or get_remaining_safe_tiles_count() == 0:
		emit_signal("game_over")
		
	return eval_res

func use_scroll(scroll_id: String, target_cell: Vector2i = Vector2i(-1, -1), extra_arg: String = "") -> bool:
	if not owned_scrolls.has(scroll_id):
		return false
		
	var target_data := {}
	if target_cell.x >= 0 and target_cell.x < grid_size and target_cell.y >= 0 and target_cell.y < grid_size:
		target_data["cell"] = board_data.cells[target_cell.x][target_cell.y]
	if extra_arg != "":
		target_data["new_suit"] = extra_arg
		
	var state := {
		"cells": board_data.cells,
		"flagged": flagged,
		"plays_left": plays_left
	}
	
	var success := Scrolls.use_scroll(scroll_id, target_data, state)
	if success:
		plays_left = int(state.get("plays_left", plays_left))
		owned_scrolls.erase(scroll_id)
		emit_signal("plays_changed", plays_left)
	return success

func buy_relic(relic_id: String) -> bool:
	if not Relics.RELIC_DEFINITIONS.has(relic_id):
		return false
	var cost: int = Relics.RELIC_DEFINITIONS[relic_id].cost
	if gold >= cost and owned_relics.size() < 5:
		gold -= cost
		owned_relics.append(relic_id)
		emit_signal("gold_changed", gold)
		return true
	return false

func buy_scroll(scroll_id: String) -> bool:
	if not Scrolls.SCROLL_DEFINITIONS.has(scroll_id):
		return false
	var cost: int = Scrolls.SCROLL_DEFINITIONS[scroll_id].cost
	if gold >= cost and owned_scrolls.size() < 2:
		gold -= cost
		owned_scrolls.append(scroll_id)
		emit_signal("gold_changed", gold)
		return true
	return false
