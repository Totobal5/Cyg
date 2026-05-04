/// Meta-tests for Crispy testing framework
/// These tests verify that Crispy itself works correctly

// ==================== CrispyLog Tests ====================
function test_crispy_log_creates_passing_log() 
{
	var _case = new CrispyCase("test", function() {});
	var _log = new CrispyLog(_case, {
		__pass: true,
		__msg: "Test passed",
		__helper_text: "Helper"
	});
	
	AssertTrue(_log.__pass, "Log should be marked as passing");
	AssertEqual(_log.__msg, "Test passed", "Log message should match");
	AssertEqual(_log.__helper_text, "Helper", "Helper text should match");
}

function test_crispy_log_creates_failing_log() 
{
	var _case = new CrispyCase("test", function() {});
	var _log = new CrispyLog(_case, {
		__pass: false,
		__msg: "Test failed",
		__helper_text: ""
	});
	
	AssertFalse(_log.__pass, "Log should be marked as failing");
	AssertEqual(_log.__msg, "Test failed", "Log message should match");
}

function test_crispy_log_get_msg_with_helper_text()
{
	var _case = new CrispyCase("test", function() {});
	var _log = new CrispyLog(_case, {
		__pass: false,
		__helper_text: "Additional info"
	});
	
	var _full_msg = _log.GetMsg();
	AssertTrue(string_pos("Additional info", _full_msg) > 0, "Full message should contain helper text");
}

function test_crispy_log_get_msg_with_failure_message()
{
	var _case = new CrispyCase("test", function() {});
	var _log = new CrispyLog(_case, {
		__pass: false,
		__msg: "Main message",
		__helper_text: "Additional info"
	});

	var _full_msg = _log.GetMsg();
	AssertTrue(string_pos("Main message", _full_msg) > 0, "Full message should contain main message");
}

function test_crispy_log_get_msg_with_duration()
{
	var _case = new CrispyCase("timed", function() {});
	var _log = new CrispyLog(_case, {
		__pass: true,
		__duration: 0.000038,
	});

	var _full_msg = _log.GetMsg();
	AssertTrue(string_pos("38.00us", _full_msg) > 0, "Full message should contain the formatted duration");
}

// ==================== CrispyCase Tests ====================

function test_crispy_case_assert_equal_passes_with_same_values()
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertEqual(5, 5, "Values should be equal");
	
	AssertEqual(array_length(_case.__logs), 1, "Should have one log entry");
	AssertTrue(_case.__logs[0].__pass, "Assertion should pass");
}

function test_crispy_case_assert_equal_fails_with_different_values() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertEqual(5, 10, "Values should be different");
	
	AssertEqual(array_length(_case.__logs), 1, "Should have one log entry");
	AssertFalse(_case.__logs[0].__pass, "Assertion should fail");
}

function test_crispy_case_assert_deep_equal_passes_with_structs_and_arrays()
{
	var _case = new CrispyCase("test", function() {});

	var _expected = {
		stats: { hp: 10, mp: 5 },
		items: [ "sword", "shield" ],
		flags: [ true, false, true ],
	};

	var _actual = {
		stats: { hp: 10, mp: 5 },
		items: [ "sword", "shield" ],
		flags: [ true, false, true ],
	};

	_case.AssertDeepEqual(_actual, _expected, "Structs and arrays should match");

	AssertTrue(_case.__logs[0].__pass, "AssertDeepEqual should pass for matching nested data");
}

function test_crispy_case_assert_deep_equal_fails_on_difference()
{
	var _case = new CrispyCase("test", function() {});

	var _expected = {
		stats: { hp: 10, mp: 5 },
		items: [ "sword", "shield" ],
	};

	var _actual = {
		stats: { hp: 8, mp: 5 },
		items: [ "sword", "shield" ],
	};

	_case.AssertDeepEqual(_actual, _expected, "Stats should match");

	AssertFalse(_case.__logs[0].__pass, "AssertDeepEqual should fail when nested values differ");
}

function test_crispy_case_records_duration_after_run()
{
	var _case = new CrispyCase("timed", function() {
		// trivial body
	});
	_case.Run();
	AssertTrue(_case.GetDuration() >= 0, "Duration should be recorded");
}

function test_crispy_case_skip_prevents_execution() 
{
	var _case = new CrispyCase("skipped", function() {
		AssertTrue(false, "This should not run");
	});
	_case.Skip();
	_case.Run();
	AssertEqual(array_length(_case.__logs), 0, "Skipped case should have no logs");
	AssertTrue(_case.IsSkipped(), "Case should be marked as skipped");
}

function test_crispy_case_assert_contains_in_array() 
{
	var _case = new CrispyCase("contains_array", function() {
		var _arr = [1, 2, 3, 4, 5];
		AssertContains(_arr, 3, "Array should contain 3");
	});
	_case.Run();
	AssertTrue(_case.__logs[0].__pass, "AssertContains should pass with value in array");
}

function test_crispy_case_assert_contains_in_string() 
{
	var _case = new CrispyCase("contains_string", function() {
		AssertContains("hello world", "world", "String should contain 'world'");
	});
	_case.Run();
	AssertTrue(_case.__logs[0].__pass, "AssertContains should pass with substring");
}

function test_crispy_case_assert_contains_fails() 
{
	var _case = new CrispyCase("contains_fail", function() {
		var _arr = [1, 2, 3];
		AssertContains(_arr, 99, "Should fail");
	});
	_case.Run();
	AssertFalse(_case.__logs[0].__pass, "AssertContains should fail when value not found");
}

function test_crispy_case_assert_near_passes()
{
	var _case = new CrispyCase("near_pass", function() {
		AssertNear(10.05, 10.0, 0.1, "Values should be near");
	});
	_case.Run();
	AssertTrue(_case.__logs[0].__pass, "AssertNear should pass within tolerance");
}

function test_crispy_case_assert_near_fails()
{
	var _case = new CrispyCase("near_fail", function() {
		AssertNear(10.5, 10.0, 0.1, "Values should be near");
	});
	_case.Run();
	AssertFalse(_case.__logs[0].__pass, "AssertNear should fail outside tolerance");
}

function test_crispy_case_assert_true_passes()
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertTrue(true, "Should be true");
	
	AssertTrue(_case.__logs[0].__pass, "AssertTrue should pass with true value");
}

function test_crispy_case_assert_false_passes()
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertFalse(false, "Should be false");
	
	AssertTrue(_case.__logs[0].__pass, "AssertFalse should pass with false value");
}

function test_crispy_case_assert_is_noone_passes() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertIsNoone(noone, "Should be noone");
	
	AssertTrue(_case.__logs[0].__pass, "AssertIsNoone should pass with noone value");
}

function test_crispy_case_assert_is_undefined_passes() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertIsUndefined(undefined, "Should be undefined");
	
	AssertTrue(_case.__logs[0].__pass, "AssertIsUndefined should pass with undefined value");
}

function test_crispy_case_assert_raises_passes_when_error_thrown()
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertRaises(function() {
		throw "Expected error";
	}, "Should throw error");
	
	AssertTrue(_case.__logs[0].__pass, "AssertRaises should pass when function throws");
}

function test_crispy_case_assert_does_not_throw_passes() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertDoesNotThrow(function() {
		var _x = 5 + 5;
	}, "Should not throw");
	
	AssertTrue(_case.__logs[0].__pass, "AssertDoesNotThrow should pass when no error");
}

// ==================== CrispyCaseAsync Tests ====================

function test_crispy_case_async_step_checkpoint_completes()
{
	var _case = new CrispyCaseAsync("async_step_case");
	_case.async_calls = 0;

	_case
		.WaitStep(function() {
			var _hits = struct_get(self, "async_calls") + 1;
			struct_set(self, "async_calls", _hits);
			AssertEqual(struct_get(self, "async_calls"), 1, "Step checkpoint should run exactly once");
			return true;
		})
		.Timeout(10, "frames");

	_case.Start();
	_case.OnBeginStep();
	_case.OnStep();

	AssertTrue(_case.IsComplete(), "Async case should complete after step checkpoint");
	AssertFalse(_case.IsRunning(), "Async case should no longer be running");
	AssertEqual(_case.async_calls, 1, "Step checkpoint count should be 1");
}

function test_crispy_case_async_timeout_fails_case()
{
	var _case = new CrispyCaseAsync("async_timeout_case")
		.WaitEndStep(function() {
			return false;
		})
		.Timeout(1, "frames");

	_case.Start();
	_case.OnBeginStep();

	AssertTrue(_case.IsComplete(), "Async case should complete after timeout");
	AssertFalse(_case.__logs[0].__pass, "Timeout should produce a failing log");
}

function test_crispy_case_async_callback_context_defaults_to_case()
{
	var _case = new CrispyCaseAsync("async_context_default_case");

	_case
		.WaitStep(function() {
			callback_flag = true;
			return true;
		})
		.Timeout(10, "frames");

	_case.Start();
	_case.OnBeginStep();
	_case.OnStep();

	AssertTrue(_case.IsComplete(), "Async case should complete with default context callback");
	AssertTrue(_case.callback_flag, "Default callback context should be the async case");
}

function test_crispy_case_async_callback_context_can_be_custom()
{
	var _context = {
		hits: 0,
	};

	var _case = new CrispyCaseAsync("async_context_custom_case")
		.WaitStep(function() {
			++hits;
			return hits >= 1;
		}, _context)
		.Timeout(10, "frames");

	_case.Start();
	_case.OnBeginStep();
	_case.OnStep();

	AssertTrue(_case.IsComplete(), "Async case should complete with custom context callback");
	AssertEqual(_context.hits, 1, "Custom callback context should update its own state");
}

// ==================== CrispySuite Tests ====================

function test_crispy_suite_creates_with_name()
{
	var _suite = new CrispySuite("test_suite");
	
	AssertEqual(_suite.__name, "test_suite", "Suite name should match");
	AssertEqual(array_length(_suite.__tests), 0, "Suite should start with no tests");
}

function test_crispy_suite_adds_test_case()
{
	var _suite = new CrispySuite("test_suite");
	var _case = new CrispyCase("test_case", function() {});
	
	_suite.AddCase(_case);
	
	AssertEqual(array_length(_suite.__tests), 1, "Suite should have one test");
}

function test_crispy_suite_setup_runs_before_tests()
{
	CrispyTest.vars.setup_ran = false;
	
	var _suite = new CrispySuite("test_suite");
	_suite.SetUp(function() {
		CrispyTest.vars.setup_ran = true;
	});
	
	var _case = new CrispyCase("test", function() {
		AssertTrue(CrispyTest.vars.setup_ran, "SetUp should have run");
	});
	_suite.AddCase(_case);
	
	_suite.Run();
	
	AssertTrue(CrispyTest.vars.setup_ran, "SetUp should have executed");
}

function test_crispy_suite_teardown_runs_after_tests()
{
	CrispyTest.vars.teardown_ran = false;
	
	var _suite = new CrispySuite("test_suite");
	_suite.TearDown(function() {
		CrispyTest.vars.teardown_ran = true;
	});
	
	var _case = new CrispyCase("test", function() {});
	_suite.AddCase(_case);
	
	_suite.Run();
	
	AssertTrue(CrispyTest.vars.teardown_ran, "TearDown should have executed");
}

// ==================== CrispyRunner Tests ====================

function test_crispy_runner_creates_with_name() 
{
	var _runner = new CrispyRunner("test_runner");
	
	AssertEqual(_runner.__name, "test_runner", "Runner name should match");
	AssertEqual(array_length(_runner.__suites), 0, "Runner should start with no suites");
}

function test_crispy_runner_adds_test_suite() 
{
	var _runner = new CrispyRunner("test_runner");
	var _suite = new CrispySuite("test_suite");
	
	_runner.AddTestSuite(_suite);
	
	AssertEqual(array_length(_runner.__suites), 1, "Runner should have one suite");
}

function test_crispy_runner_captures_logs_from_suite()
{
	var _runner = new CrispyRunner("test_runner");
	var _suite = new CrispySuite("test_suite");
	var _case = new CrispyCase("test", function() {
		AssertTrue(true, "This should pass");
	});
	
	_suite.AddCase(_case);
	_case.Run();
	_runner.CaptureLogs(_suite);
	
	AssertEqual(array_length(_runner.__logs), 1, "Runner should capture one log");
	AssertTrue(_runner.__logs[0].__pass, "Captured log should be passing");
}

function test_crispy_runner_hr_creates_horizontal_line()
{
	var _runner = new CrispyRunner("test_runner");
	var _hr = _runner.Hr("-", 10);
	
	AssertEqual(_hr, "----------", "HR should create 10 dashes");
}

// ==================== Discovery Tests ====================

function test_crispy_runner_discover_finds_functions()
{
	var _runner = new CrispyRunner("test_runner");
	var _suite = new CrispySuite("discovery_suite");
	
	_runner.AddTestSuite(_suite);
	_runner.Discover(_suite, "test_crispy_log_");
	
	AssertTrue(array_length(_suite.__tests) > 0, "Discover should find test functions");
}

function test_crispy_runner_discover_creates_async_case_for_async_function_name()
{
	var _runner = new CrispyRunner("test_runner");
	var _suite = new CrispySuite("discovery_async_suite");

	_runner.AddTestSuite(_suite);
	_runner.Discover(_suite, "test_discoverable_async_");

	AssertTrue(array_length(_suite.__tests) > 0, "Discover should find async discoverable functions");
	AssertEqual(instanceof(_suite.__tests[0]), "CrispyCaseAsync", "Discover should create CrispyCaseAsync for async script names");
}

// ==================== Shared State Tests ====================

function test_crispy_shared_vars_accessible()
{
	CrispyTest.vars.test_value = 42;
	
	AssertEqual(CrispyTest.vars.test_value, 42, "Shared vars should be accessible");
}

function test_crispy_shared_vars_persists_across_tests() 
{
	CrispyTest.vars.counter = 0;
	CrispyTest.vars.counter += 1;
	
	AssertEqual(CrispyTest.vars.counter, 1, "Shared vars should persist");
}

// ==================== Type Validation Tests ====================

function test_crispy_case_assert_equal_fails_different_types() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertEqual(5, "5", "Should fail with different types");
	
	AssertFalse(_case.__logs[0].__pass, "AssertEqual should fail with different types");
}

function test_crispy_case_assert_not_equal_passes_different_values() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertNotEqual(5, 10, "Values are different");
	
	AssertTrue(_case.__logs[0].__pass, "AssertNotEqual should pass with different values");
}

function test_crispy_case_assert_is_not_noone_passes() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertIsNotNoone(5, "Should not be noone");
	
	AssertTrue(_case.__logs[0].__pass, "AssertIsNotNoone should pass with non-noone value");
}

function test_crispy_case_assert_is_not_undefined_passes() 
{
	var _case = new CrispyCase("test", function() {});
	_case.AssertIsNotUndefined(5, "Should not be undefined");
	
	AssertTrue(_case.__logs[0].__pass, "AssertIsNotUndefined should pass with defined value");
}
