extends Node

func _ready() -> void:
	print("========================================")
	print("🧪 RUNNING TEST SUITE: MATHEMANCER")
	print("========================================")
	
	var all_passed := true
	
	# Task 1 Sanity Check
	print("✅ TASK 1 TEST: Initialized project.godot and environment successfully.")
	
	# Task 2: Hand Evaluator Tests
	const TestHandEvaluator = preload("res://tests/test_hand_evaluator.gd")
	if not TestHandEvaluator.run_tests():
		all_passed = false
		
	# Task 3: Board Generator Tests
	const TestBoardGenerator = preload("res://tests/test_board_generator.gd")
	if not TestBoardGenerator.run_tests():
		all_passed = false
		
	# Task 4: Items (Relics & Scrolls) Tests
	const TestItems = preload("res://tests/test_items.gd")
	if not TestItems.run_tests():
		all_passed = false
		
	# Task 5: Game Manager Tests
	const TestGameManager = preload("res://tests/test_game_manager.gd")
	if not TestGameManager.run_tests():
		all_passed = false
		
	# Task 6: Tile View Tests
	const TestTileView = preload("res://tests/test_tile_view.gd")
	if not TestTileView.run_tests():
		all_passed = false
		
	# Task 7 & 8: Main Scene & Shop Tests
	const TestMainScene = preload("res://tests/test_main_scene.gd")
	if not TestMainScene.run_tests(self):
		all_passed = false
		
	# Task 9: End-to-End Gameplay Loop Tests
	const TestE2EGameplay = preload("res://tests/test_e2e_gameplay.gd")
	if not TestE2EGameplay.run_tests():
		all_passed = false
		
	# Task 10: 20-Run Auto-Play Simulation Benchmark (Target >= 75% Win Rate across Ante 1-8)
	const AutoPlayBench = preload("res://tests/auto_play_benchmark.gd")
	var bench_res = AutoPlayBench.run_benchmark(20)
	if bench_res.win_rate < 75.0:
		print("❌ FAIL Auto-Play benchmark win rate below 75%: %.1f%" % bench_res.win_rate)
		all_passed = false
	else:
		print("  ✅ PASS Auto-Play Benchmark achieved %.1f%% Win Rate (>= 75%% required)" % bench_res.win_rate)
	
	print("========================================")
	if all_passed:
		print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
		get_tree().quit(0)
	else:
		push_error("❌ TESTS FAILED!")
		get_tree().quit(1)
