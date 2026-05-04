/// @description Runner to hold test suites and iterates through each CrispySuite, running its tests
/// @param {String} name - Name of runner
/// @param {Struct} [unpack=undefined] - Struct for crispy_struct_unpack
function CrispyRunner(_name, _unpack = undefined) : CrispyTest(_name) constructor
{
	/// @ignore
	__start_time = 0;
	/// @ignore
	__stop_time = 0;
	/// @ignore
	__total_time = 0;
	/// @ignore
	__display_time = "0";
	/// @ignore
	__suites = [];
	/// @ignore
	__logs = [];
	/// @ignore
	__discovered = undefined;
	/// @ignore
	__current_suite_index = 0;
	/// @ignore
	__is_running = false;
	/// @ignore
	__is_complete = false;

	/// Run struct unpacker if unpack argument was provided
	/// Stays after all variables are initialized so they may be overwritten
	__crispy_validate_unpack_param(instanceof(self), "", _unpack);

	#region METHODS

	/// @description Adds a Log to the array of logs
	/// @param {Struct} log - Log struct to add to logs
	/// @returns {Struct.CrispyRunner} Self for chaining
	static AddLog = function(_log)
	{
		array_push(__logs, _log);
		return self;
	}

	/// @description Adds Logs to the array of logs
	/// @param {Struct} input - Adds logs of the input to logs
	static CaptureLogs = function(_input)
	{
		var _i;
		switch (instanceof(_input))
		{
			case "CrispyLog":
				AddLog(_input);
			break;

			case "CrispyCase":
			case "CrispyCaseAsync":
				var _case_logs_len = array_length(_input.__logs);
				var _case_pass = true;
				var _case_msg = undefined;
				var _case_helper_text = undefined;
				var _failure_lines = [];
				var _failure_index = 0;

				_i = 0; repeat (_case_logs_len)
				{
					var _log = _input.__logs[_i];
					if (!_log.__pass)
					{
						_case_pass = false;
						++_failure_index;

						var _line = "";
						if (!is_undefined(_log.__msg) && _log.__msg != "")
						{
							_line = _log.__msg;
						}
						else if (!is_undefined(_log.__helper_text) && _log.__helper_text != "")
						{
							_line = _log.__helper_text;
						}
						else
						{
							_line = "Assertion failed.";
						}

						array_push(_failure_lines, $"[{string(_failure_index)}] {_line}");
					}

					++_i;
				}

				if (!_case_pass)
				{
					_case_msg = $"{string(_failure_index)} assertion failure(s)";

					var _details = "";
					var _j = 0; repeat (array_length(_failure_lines))
					{
						if (_j > 0) _details += "\n";
						_details += _failure_lines[_j];
						++_j;
					}

					_case_helper_text = _details;
				}

				AddLog(new CrispyLog(_input, {
					__pass: _case_pass,
					__msg: _case_msg,
					__helper_text: _case_helper_text,
					__duration: _input.__duration,
					__skipped: _input.__skipped,
				}) );
			break;
			
			case "CrispySuite":
				var _k = 0; repeat (array_length(_input.__tests) )
				{
					var _case = _input.__tests[_k];
					CaptureLogs(_case);
					++_k;
				}
			break;

			default:
				__crispy_error($"{instanceof(self)}.CaptureLogs() \"_input\" expected an instance of either CrispyLog, CrispyCase, or CrispySuite, received {__crispy_get_type_display(_input)}.");
			break;
		}
	}

	/// @description Adds TestSuite to array of suites
	/// @param {Struct} test_suite - TestSuite to add
	/// @returns {Struct.CrispyRunner} Self for chaining
	static AddTestSuite = function(_test_suite)
	{
		if (instanceof(_test_suite) != "CrispySuite")
		{
			__crispy_error($"{instanceof(self)}.AddTestSuite() \"_test_suite\" expected an instance of CrispySuite, received {__crispy_get_type_display(_test_suite)}.");
		}

		_test_suite.__parent = self;
		array_push(__suites, _test_suite);
		return self;
	}

	/// @description Creates a horizontal row string used to visually separate sections
	/// @param {String} [str="-"] - String to concat n times
	/// @param {Real} [count=70] - Number of times to concat str
	/// @returns {String} String of horizontal row
	static Hr = function(_str = "-", _count = 70)
	{
		if (!__crispy_validate_type_param(instanceof(self), "Hr", "_str", _str, "string")) return "";
		if (!__crispy_validate_type_param(instanceof(self), "Hr", "_count", _count, "real")) return "";
		
		var _hr = ""; repeat(_count) { _hr += _str; }
		return _hr;
	}

	/// @description Returns whether the runner is currently active.
	/// @returns {Bool}
	static IsRunning = function()
	{
		return __is_running;
	}

	/// @description Returns whether the runner has completed its current run.
	/// @returns {Bool}
	static IsComplete = function()
	{
		return __is_complete;
	}
	
	/// @description Runs test suites and logs results
	/// @returns {Struct.CrispyRunner} Self for chaining
	static Run = function()
	{
		SetUp();
		__current_suite_index = 0;
		__is_running = true;
		__is_complete = false;
		__AdvanceSuites();

		return self;
	}

	/// @description Updates the active suite and advances the run when async suites complete.
	/// @returns {Struct.CrispyRunner} Self for chaining
	static Update = function()
	{
		if (!__is_running)
		{
			return self;
		}

		__AdvanceSuites();

		return self;
	}

	/// @description Clears logs, starts timer, and runs __SetUp
	/// @param {Function} [func] - Method to override __SetUp with
	/// @returns {Struct.CrispyRunner} Self for chaining
	static SetUp = function(_func)
	{
		if (!is_undefined(_func))
		{
			if (is_method(_func))
			{
				__SetUp = method(self, _func);
			}
			else
			{
				__crispy_error($"{instanceof(self)}.SetUp() \"_func\" expected a function, received {typeof(_func)}.");
			}
		}
		else
		{
			__logs = [];
			__start_time = get_timer();
			__is_complete = false;
			if (is_method(__SetUp)) { __SetUp(); }
		}

		return self;
	}

	/// @ignore
	static __AdvanceSuites = function()
	{
		var _len = array_length(__suites);
		while (__current_suite_index < _len)
		{
			var _suite = __suites[__current_suite_index];

			if (!_suite.IsRunning() && !_suite.IsComplete())
			{
				OnRunBegin();
				_suite.Run();
			}
			else if (_suite.IsRunning())
			{
				_suite.Update();
			}

			if (_suite.IsComplete())
			{
				CaptureLogs(_suite);
				OnRunEnd();
				++__current_suite_index;
				continue;
			}

			return self;
		}

		if (__is_running)
		{
			__is_running = false;
			__is_complete = true;
			TearDown();
		}

		return self;
	}

	/// @description Function ran after test, used to clean up test
	/// @param {Function} [func] - Method to override __TearDown with
	/// @returns {Struct.CrispyRunner} Self for chaining
	static TearDown = function(_func)
	{
		if (!is_undefined(_func))
		{
			if (is_method(_func))
			{
				__TearDown = method(self, _func);
			}
			else
			{
				__crispy_error($"{instanceof(self)}.TearDown() \"_func\" expected a function, received {typeof(_func)}.");
			}
		}
		else
		{
			if (CRISPY_DEBUG && CRISPY_SILENCE_PASSING_TESTS_OUTPUT)
			{
				__crispy_alert("Passing test messages are silenced.");
			}

			// Get total run time
			__stop_time = get_timer();
			__total_time = __stop_time - __start_time;
			__display_time = string_format(__total_time / 1000000, 0, CRISPY_TIME_PRECISION);

			// Display silent test results
			var _passed_tests = 0;
			var _len = array_length(__logs);
			var _t = "";
			var _j = 0;

			if (_len > 0 && CRISPY_STATUS_OUTPUT_LENGTH != 0)
			{
				var _row_len = abs(CRISPY_STATUS_OUTPUT_LENGTH);
				var _row = "";
				for (var _i = 0; _i < _len; ++_i)
				{
					if (__logs[_i].__pass)
					{
						++_passed_tests;
						_row += CRISPY_PASS_MSG_SILENT;
					}
					else
					{
						_row += CRISPY_FAIL_MSG_SILENT;
					}
					++_j;

					if (_row_len > 0 && _j == _row_len && _i != _len - 1)
					{
						_t += _row + "\n";
						_row = "";
						_j = 0;
					}
				}
				_t += _row;
			}

			Output(_t);

			// Horizontal row
			Output(Hr() );
			
			// Show individual log messages
			var _i = 0; repeat (_len)
			{
				// _passed_tests already counted in status output loop above

				if (!CRISPY_SILENCE_PASSING_TESTS_OUTPUT || !__logs[_i].__pass)
				{
					var _msg = __logs[_i].GetMsg();
					if (_msg != "") { Output(_msg); }
				}

				++_i;
			}

			// Finish by showing entire time it took to run the tests
			var _string_tests = _len == 1 ? "test" : "tests";
			Output("");
			Output(string(_len) + " " + _string_tests + " ran in " + __display_time + "s");

			if (_passed_tests == _len)
			{
				Output(string_upper(CRISPY_PASS_MSG_VERBOSE));
			}
			else
			{
				Output(string_upper(CRISPY_FAIL_MSG_VERBOSE) + "ED (failures==" + string(_len - _passed_tests) + ")");
			}

			// Run TearDown method
			if (is_method(__TearDown) ) { __TearDown(); }
		}
		
		return self;
	}

	/// @description Function for discovering individual test functions within scripts, and adds them to a TestSuite
	/// @param {Struct} [test_suite=undefined] - TestSuite to add discovered test script to, else create a temporary TestSuite
	/// @param {String} [script_start_pattern="test_"] - String that script functions need to start with in order to be discoverable
	/// @returns {Struct.CrispyRunner} Self for chaining
	static Discover = function(_test_suite, _script_start_pattern = "test_")
	{
		if (!is_string(_script_start_pattern))
		{
			__crispy_error($"{instanceof(self)}.Discover() \"_script_start_pattern\" expected a string, received {typeof(_script_start_pattern)}.");
		}

		// Cache all script functions
		if (is_undefined(__discovered))
		{
			__discovered = [];
			var _i = 100000; // Range of custom scripts is 100000 onwards
			var _missing_streak = 0;
			var _max_missing_streak = 2048;

			// Script IDs can contain gaps, so keep scanning until enough consecutive misses suggest the range ended.
			while (_missing_streak < _max_missing_streak)
			{
				if (!script_exists(_i) )
				{
					++_missing_streak;
					++_i;
					continue;
				}

				_missing_streak = 0;
				
				var _script_name = script_get_name(_i);
				// Skip adding functions that are not named script functions
				if (string_count("_gml_Object_", _script_name) != 0 || string_count("_gml_GlobalScript_", _script_name) != 0)
				{
					++_i;
					continue;
				}

				array_push(__discovered, {
					name: _script_name,
					func: _i,
					discovered: false
				});
				
				if (CRISPY_DEBUG) { __crispy_alert($"Discovered script function: {_script_name} ({string(_i)})."); }
				++_i;
			}

			if (CRISPY_DEBUG)
			{
				__crispy_alert($"Stopped discovery scan after {_max_missing_streak} consecutive missing script IDs.");
			}
		}

		var _created_test_suite = is_undefined(_test_suite);

		// If value is passed for _test_suite
		if (!is_undefined(_test_suite))
		{
			if (instanceof(_test_suite) != "CrispySuite")
			{
				var _type = !is_undefined(instanceof(_test_suite)) ? instanceof(_test_suite) : typeof(_test_suite);
				__crispy_error($"{instanceof(self)}.Discover() \"_test_suite\" expected an instance of CrispySuite, received {_type}.");
			}
			// Throw error if test_suite was not previously added to test_runner
			if (_test_suite.__parent != self)
			{
				__crispy_error($"{instanceof(self)}.Discover() \"_test_suite\" parent is not self.\nProvided CrispySuite may not have been added to {__name} prior to running Discover.");
			}
		}
		else
		{
			_test_suite = new CrispySuite("__discovered_test_suite__");
		}

		// Throw error if function pattern is an empty string
		var _pattern_len = string_length(_script_start_pattern);
		if (_pattern_len == 0)
		{
			show_error($"{instanceof(self)}.Discover() \"_script_start_pattern\" cannot be an empty string.", true);
		}
		
		// Discover scripts matching the start pattern and add as test cases
		var _len = array_length(__discovered);
		for (var _i = 0; _i < _len; ++_i)
		{
			var _script = __discovered[_i];
			if (_script.discovered) continue;

			var _script_name = _script.name;
			if (string_length(_script_name) >= _pattern_len && string_copy(_script_name, 1, _pattern_len) == _script_start_pattern)
			{
				var _is_async_script = (string_pos("_async", _script_name) > 0);
				var _test_case = _is_async_script
					? new CrispyCaseAsync(_script_name)
					: new CrispyCase(_script_name, function(){});

				_test_case.__Discover(_script.func);
				_test_suite.AddCase(_test_case);
				_script.discovered = true;
			}
		}

		if (_created_test_suite)
		{
			if (array_length(_test_suite.__tests) == 0)
			{
				delete _test_suite;
				if (CRISPY_DEBUG) { __crispy_alert($"{__name}.Discover() local CrispySuite deleted."); }
			}
			else
			{
				AddTestSuite(_test_suite);
				if (CRISPY_DEBUG) { __crispy_alert($"{__name}.Discover() local CrispySuite added: {_test_suite.__name}"); }
			}
		}

		return self;
	}

	/// @description Pass input to __Output if string. Overwrite __Output if function
	/// @param {String|Function} input - String to output or function to overwrite __Output
	static Output = function(_input)
	{
		if (is_undefined(_input))
		{
			__crispy_error($"{instanceof(self)}.Output() expected 1 argument, received 0 argument(s).");
			return;
		}

		var _type = typeof(_input);
		if (_type == "string")
		{
			__Output(_input);
		}
		else if (_type == "method")
		{
			__Output = method(self, _input);
		}
		else
		{
			__crispy_error($"{instanceof(self)}.Output() \"_input\" expected either a string or method, received {_type}.");
		}
	}

	/// @description Function that gets called on output. This function can be overwritten by a function passed into the Output() function
	/// @param {String} message - By default, prints string to Output Console
	/// @ignore
	static __Output = function(_message)
	{
		show_debug_message(_message);
	}

	/// @returns {String}
	static toString = function()
	{
		return $"<Crispy Runner(\"{__name}\")>";
	}

	#endregion
}
