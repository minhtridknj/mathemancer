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
	
	print("========================================")
	if all_passed:
		print("🎉 ALL TESTS PASSED SUCCESSFULLY!")
		get_tree().quit(0)
	else:
		push_error("❌ TESTS FAILED!")
		get_tree().quit(1)
