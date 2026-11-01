class_name TestBoardGenerator
extends RefCounted

const BoardGenerator = preload("res://scripts/core/board_generator.gd")

static func run_tests() -> bool:
	print("--- Running TestBoardGenerator ---")
	var all_ok := true
	
	# Test level generation for grid_size = 4, ante = 1
	var level = BoardGenerator.generate_level(4, 1, 12345)
	
	# 1. Structure check
	if level.is_empty() or not level.has("cells") or not level.has("row_clues") or not level.has("col_clues"):
		print("❌ FAIL: Level dictionary missing required keys")
		return false
	
	var cells: Array = level.cells
	var row_clues: Array = level.row_clues
	var col_clues: Array = level.col_clues
	
	if cells.size() != 4 or row_clues.size() != 4 or col_clues.size() != 4:
		print("❌ FAIL: Grid size mismatch")
		all_ok = false
	else:
		print("  ✅ PASS Grid size matches 4x4")
		
	# 2. Kakuro Sums check & Sudoku Unique Digits check
	var kakuro_ok := true
	var sudoku_ok := true
	var given_count := 0
	
	# Check rows
	for r in range(4):
		var calc_sum := 0
		var seen_digits := {}
		for c in range(4):
			var cell = cells[r][c]
			if cell.is_given:
				given_count += 1
			if not cell.is_mine:
				calc_sum += cell.val
				if seen_digits.has(cell.val):
					sudoku_ok = false
					print("❌ FAIL Sudoku duplicate in Row %d: val %d" % [r, cell.val])
				seen_digits[cell.val] = true
		if calc_sum != row_clues[r].sum:
			kakuro_ok = false
			print("❌ FAIL Kakuro sum mismatch in Row %d: calc %d != target %d" % [r, calc_sum, row_clues[r].sum])
			
	# Check cols
	for c in range(4):
		var calc_sum := 0
		var seen_digits := {}
		for r in range(4):
			var cell = cells[r][c]
			if not cell.is_mine:
				calc_sum += cell.val
				if seen_digits.has(cell.val):
					sudoku_ok = false
					print("❌ FAIL Sudoku duplicate in Col %d: val %d" % [c, cell.val])
				seen_digits[cell.val] = true
		if calc_sum != col_clues[c].sum:
			kakuro_ok = false
			print("❌ FAIL Kakuro sum mismatch in Col %d: calc %d != target %d" % [c, calc_sum, col_clues[c].sum])
			
	if kakuro_ok:
		print("  ✅ PASS Kakuro sums strictly match safe cell sums")
	else:
		all_ok = false
		
	if sudoku_ok:
		print("  ✅ PASS Sudoku unique digits respected across all lines")
	else:
		all_ok = false
		
	if given_count >= 2:
		print("  ✅ PASS Initial anchor numbers given: %d cells" % given_count)
	else:
		print("❌ FAIL: Anchor numbers given too few: %d" % given_count)
		all_ok = false

	# 3. Ordinal Mine Ranking check
	var rank_ok := true
	var line_mines: Array[int] = []
	var line_ranks: Array[int] = []
	
	for r in range(4):
		var m := 0
		for c in range(4):
			if cells[r][c].is_mine: m += 1
		line_mines.append(m)
		line_ranks.append(row_clues[r].rank)
		
	for c in range(4):
		var m := 0
		for r in range(4):
			if cells[r][c].is_mine: m += 1
		line_mines.append(m)
		line_ranks.append(col_clues[c].rank)
		
	# Verify that if line i has fewer mines than line j, rank_i < rank_j
	# and if line i has same mines as line j, rank_i == rank_j
	for i in range(line_mines.size()):
		for j in range(line_mines.size()):
			if line_mines[i] < line_mines[j] and line_ranks[i] >= line_ranks[j]:
				rank_ok = false
				print("❌ FAIL Mine Ranking: line %d (mines=%d, rank=%d) should have lower rank than line %d (mines=%d, rank=%d)" % [i, line_mines[i], line_ranks[i], j, line_mines[j], line_ranks[j]])
			elif line_mines[i] == line_mines[j] and line_ranks[i] != line_ranks[j]:
				rank_ok = false
				print("❌ FAIL Mine Ranking: line %d and %d have same mines %d but different ranks (%d vs %d)" % [i, j, line_mines[i], line_ranks[i], line_ranks[j]])
				
	if rank_ok:
		print("  ✅ PASS Ordinal Mine Ranking verified 100% strictly")
	else:
		all_ok = false
		
	# 4. Staged Fog of War check
	var has_stage_1 := false
	var has_stage_2 := false
	for clue in row_clues + col_clues:
		if clue.unlocked_at_stage == 1: has_stage_1 = true
		if clue.unlocked_at_stage >= 2: has_stage_2 = true
		
	if has_stage_1 and has_stage_2:
		print("  ✅ PASS Staged Fog of War partitioning confirmed (Stage 1 + Stage 2)")
	else:
		print("❌ FAIL Staged Fog of War missing stages")
		all_ok = false
		
	return all_ok
