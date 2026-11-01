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
		
	# 5. Guaranteed 100% Guess-Free Deductive Solvability & Dynamic Ranking across 25 random seeds
	var solvability_ok := true
	var observed_rank1_zero := false
	var observed_rank1_positive := false
	var observed_gap_greater_than_one := false
	
	for i in range(25):
		var test_board = BoardGenerator.generate_level(4, 1, i * 37 + 101)
		if not BoardGenerator.is_board_100_percent_solvable(test_board):
			print("❌ FAIL Board generation produced an ambiguous board at seed %d" % (i * 37 + 101))
			solvability_ok = false
			break
			
		# Check Rank 1 mine count and gaps
		var r_mines: Array[int] = []
		for r in range(4):
			var m := 0
			for c in range(4):
				if test_board.cells[r][c].is_mine: m += 1
			r_mines.append(m)
		for c in range(4):
			var m := 0
			for r in range(4):
				if test_board.cells[r][c].is_mine: m += 1
			r_mines.append(m)
			
		var unique_m: Array[int] = []
		for m in r_mines:
			if not unique_m.has(m): unique_m.append(m)
		unique_m.sort()
		
		if unique_m[0] == 0:
			observed_rank1_zero = true
		else:
			observed_rank1_positive = true
			
		for idx in range(unique_m.size() - 1):
			if unique_m[idx + 1] - unique_m[idx] > 1:
				observed_gap_greater_than_one = true
				
	if solvability_ok:
		print("  ✅ PASS 100% Guess-Free Solvability mathematically verified across 25 seeds (Zero 50/50)")
	else:
		all_ok = false
		
	if observed_rank1_zero and observed_rank1_positive:
		print("  ✅ PASS Dynamic Rank 1 confirmed: Rank 1 can have 0 mines or >= 1 mines depending on the board")
	else:
		print("❌ FAIL Dynamic Rank 1 distribution: zero=%s, positive=%s" % [str(observed_rank1_zero), str(observed_rank1_positive)])
		all_ok = false
		
	if observed_gap_greater_than_one:
		print("  ✅ PASS Unpredictable Mine Gaps confirmed: Ranks can differ by more than 1 mine")
	else:
		print("❌ FAIL Unpredictable Mine Gaps not observed")
		all_ok = false

	# 6. Deep Verification Across All Higher Antes (Ante 2 to Ante 8)
	var ante_grid_map := {2: 4, 3: 5, 4: 5, 5: 6, 6: 6, 7: 7, 8: 8}
	for test_ante in ante_grid_map.keys():
		var sz: int = ante_grid_map[test_ante]
		var ante_r1_zero := false
		var ante_r1_pos := false
		var ante_gap_gt1 := false
		var single_rank_found := false
		
		for seed_i in range(15):
			var b = BoardGenerator.generate_level(sz, test_ante, test_ante * 1000 + seed_i * 29)
			if not BoardGenerator.is_board_100_percent_solvable(b):
				print("❌ FAIL Board generation unsolvable at Ante %d seed %d" % [test_ante, seed_i])
				all_ok = false
				break
				
			var b_mines: Array[int] = []
			for r in range(sz):
				var m := 0
				for c in range(sz):
					if b.cells[r][c].is_mine: m += 1
				b_mines.append(m)
			for c in range(sz):
				var m := 0
				for r in range(sz):
					if b.cells[r][c].is_mine: m += 1
				b_mines.append(m)
			var u_m: Array[int] = []
			for m in b_mines:
				if not u_m.has(m): u_m.append(m)
			u_m.sort()
			
			if u_m.size() == 1: single_rank_found = true
			if u_m[0] == 0: ante_r1_zero = true
			else: ante_r1_pos = true
			for idx in range(u_m.size() - 1):
				if u_m[idx + 1] - u_m[idx] > 1: ante_gap_gt1 = true
				
		if single_rank_found:
			print("❌ FAIL Ante %d produced a single-rank board!" % test_ante)
			all_ok = false
		if not ante_r1_zero or not ante_r1_pos:
			print("❌ FAIL Ante %d has predictable Rank 1 (zero=%s, pos=%s)" % [test_ante, str(ante_r1_zero), str(ante_r1_pos)])
			all_ok = false
		if not ante_gap_gt1:
			print("❌ FAIL Ante %d has strictly gap=1 ranks" % test_ante)
			all_ok = false
			
	if all_ok:
		print("  ✅ PASS All Antes (Ante 1 to 8) verified for dynamic Rank 1, unpredictable gaps, and 100% deductive solvability!")

	return all_ok
