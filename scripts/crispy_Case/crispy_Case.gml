/// @description Creates a Test case object to run assertions
/// @param {String} name - Name of case
/// @param {Function} func - Function for test assertion
/// @param {Struct} [unpack=undefined] - Struct for struct_unpack
function CrispyCase(_name, _func, _unpack = undefined) : CrispyTest(_name) constructor
{
	if (!is_method(_func))
	{
		__crispy_error($"{instanceof(self)} \"func\" expected a function, received {typeof(_func)}.");
	}

	/// @ignore
	__class = instanceof(self);
	/// @ignore
	__parent = undefined;
	/// @ignore
	__test = method(self, _func);
	/// @ignore
	__logs = [];
	/// @ignore
	__duration = 0;
	/// @ignore
	__is_discovered = false;
	/// @ignore
	__discovered_script = undefined;
	/// @ignore
	__skipped = false;
	/// @ignore
	__only = false;

	/// Run struct unpacker if unpack argument was provided
	/// Stays after all variables are initialized so they may be overwritten
	__crispy_validate_unpack_param(instanceof(self), "", _unpack);

	// Getters

	/// @description Get the class name of this test case
	/// @returns {String} Class name of the test case
	static GetClass = function()
	{
		return __class;
	}

	/// @description Get all logs of this test case
	/// @returns {Array} Array of logs
	static GetLogs = function()
	{
		return __logs;
	}

	/// @description Get the duration of the last run in seconds
	/// @returns {Real} Duration in seconds
	static GetDuration = function()
	{
		return __duration;
	}

	/// @description Check if this test case is skipped
	/// @returns {Bool} Whether the test is skipped
	static IsSkipped = function()
	{
		return __skipped;
	}

	// Methods

	/// @description Adds a Log to the array of logs
	/// @param {Struct} log - Log struct
	/// @returns {Struct.CrispyCase} Self for chaining
	static AddLog = function(_log)
	{
		if (!__crispy_validate_struct_param(instanceof(self), "AddLog", "log", _log)) return;
		array_push(__logs, _log);

		return self;
	}

	/// @description Clears array of Logs
	/// @returns {Struct.CrispyCase} Self for chaining
	static ClearLogs = function()
	{
		__logs = [];
		return self;
	}

	/// @description Mark this test case as skipped
	/// @returns {Struct.CrispyCase} Self for chaining
	static Skip = function()
	{
		__skipped = true;
		return self;
	}

	/// @description Mark this test case to run only (all others in suite/runner skipped)
	/// @returns {Struct.CrispyCase} Self for chaining
	static Only = function()
	{
		__only = true;
		return self;
	}

	/// @description Test that a value is contained in array or string
	/// @param {Any} container - Array or string to search in
	/// @param {Any} value - Value to find
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertContains = function(_container, _value, _message)
	{
		// Check supplied arguments
		if (argument_count < 2)
		{
			show_error($"{instanceof(self)}.AssertContains() expected 2 arguments, received {argument_count}.", true);
		}

		if (!__crispy_validate_message_param(instanceof(self), "AssertContains", _message)) return self;

		var _found = false;

		if (is_array(_container))
		{
			var _i = 0; repeat (array_length(_container))
			{
				if (_container[_i] == _value)
				{
					_found = true;
					break;
				}
				++_i;
			}
		}
		else if (is_string(_container))
		{
			_found = (string_pos(_value, _container) > 0);
		}
		else
		{
			__crispy_error($"{instanceof(self)}.AssertContains() \"container\" expected an array or string, received {typeof(_container)}.");
			return self;
		}

		if (_found)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: $"value not found in container: {_value}",
			}));
		}

		return self;
	}

	/// @description Test that two numbers are approximately equal within a tolerance
	/// @param {Real} actual - Actual value
	/// @param {Real} expected - Expected value
	/// @param {Real} tolerance - Maximum allowed difference
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertNear = function(_actual, _expected, _tolerance, _message)
	{
		// Check supplied arguments
		if (argument_count < 3)
		{
			show_error($"{instanceof(self)}.AssertNear() expected 3 arguments, received {argument_count}.", true);
		}

		if (!is_real(_actual) || !is_real(_expected) || !is_real(_tolerance))
		{
			__crispy_error($"{instanceof(self)}.AssertNear() all arguments must be real numbers.");
			return self;
		}

		if (!__crispy_validate_message_param(instanceof(self), "AssertNear", _message)) return self;

		var _diff = abs(_actual - _expected);

		if (_diff <= _tolerance)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: $"values differ by {_diff}, tolerance is {_tolerance}: {_actual} vs {_expected}",
			}));
		}

		return self;
	}
	/// @param {Any} first - First value
	/// @param {Any} second - Second value to check against first
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertEqual = function(_first, _second, _message)
	{
		// Check supplied arguments
		if (argument_count < 2)
		{
			show_error($"{instanceof(self)}.AssertEqual() expected 2 arguments, received {argument_count}.", true);
		}

		if (!__crispy_validate_message_param(instanceof(self), "AssertEqual", _message)) return;

		// Check types of first and second
		if (typeof(_first) != typeof(_second))
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: $"Supplied value types are not equal: {typeof(_first)} and {typeof(_second)}.",
			}));

			return self;
		}

		if (_first == _second)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: $"first and second are not equal: {_first}, {_second}",
			}));
		}

		return self;
	}

	/// @description Test deep equality between two values (arrays/structs recurse)
	/// @param {Any} first - First value
	/// @param {Any} second - Second value to check against first
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertDeepEqual = function(_first, _second, _message)
	{
		// Check supplied arguments
		if (argument_count < 2)
		{
			show_error($"{instanceof(self)}.AssertDeepEqual() expected 2 arguments, received {argument_count}.", true);
		}
        
		if (!__crispy_validate_message_param(instanceof(self), "AssertDeepEqual", _message)) return self;
        
		if (__DeepEqual(_first, _second))
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "first and second are not deeply equal.",
			}));
		}

		return self;
	}

	/// @description Test that first and second are not equal
	/// @param {Any} first - First type to check
	/// @param {Any} second - Second type to check against
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertNotEqual = function(_first, _second, _message)
	{
		// Check supplied arguments
		if (argument_count < 2)
		{
			show_error($"{instanceof(self)}.AssertNotEqual() expected 2 arguments, received {argument_count}.", true);
		}

		if (!__crispy_validate_message_param(instanceof(self), "AssertNotEqual", _message)) return self;
		
		var _outcome = (typeof(_first) != typeof(_second) );
		if (!_outcome) { _outcome = (_first != _second); }

		if (_outcome)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: $"first and second are equal: {_first}, {_second}",
			}));
		}

		return self;
	}

	/// @description Test whether the provided expression is true. The test will first try to convert the expression to a boolean, then check if it equals true
	/// @param {Any} expr - Expression to check
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertTrue = function(_expr, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertTrue() expected 1 argument, received {argument_count}.", true);
		}

		if (!__crispy_validate_message_param(instanceof(self), "AssertTrue", _message)) return self;

		try
		{
			bool(_expr);
		}
		catch (err)
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__helper_text: $"Unable to convert {typeof(_expr)} into boolean. Cannot evaluate.",
			}));
			
			return self;
		}

		if (_expr)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "Expression is not true.",
			}));
		}
		
		return self;
	}

	/// @description Test whether the provided expression is false. The test will first try to convert the expression to a boolean, then check if it equals false
	/// @param {Any} expr - Expression to check
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertFalse = function(_expr, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertFalse() expected 1 argument, received {argument_count}.", true);
		}
		if (!__crispy_validate_message_param(instanceof(self), "AssertFalse", _message)) return self;

		try
		{
			bool(_expr);
		}
		catch (err)
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__helper_text: $"Unable to convert {typeof(_expr)} into boolean. Cannot evaluate.",
			}));

			return self;
		}
		
		if (!_expr)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "Expression is not false.",
			}));
		}

		return self;
	}

	/// @description Test whether the provided expression is noone
	/// @param {Any} expr - Expression to check
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertIsNoone = function(_expr, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertIsNoone() expected 1 argument, received {argument_count}.", true);
		}
		if (!__crispy_validate_message_param(instanceof(self), "AssertIsNoone", _message)) return self;
		
		if (_expr == noone)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "Expression is not noone.",
			}));
		}

		return self;
	}

	/// @description Test whether the provided expression is not noone
	/// @param {Any} expr - Expression to check
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertIsNotNoone = function(_expr, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertIsNotNoone() expected 1 argument, received {argument_count}.", true);
		}
		if (!__crispy_validate_message_param(instanceof(self), "AssertIsNotNoone", _message)) return self;
		
		if (_expr != noone)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "Expression is noone.",
			}));
		}

		return self;
	}

	/// @description Test whether the provided expression is undefined
	/// @param {Any} expr - Expression to check
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertIsUndefined = function(_expr, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertIsUndefined() expected 1 argument, received {argument_count}.", true);
		}
		if (!__crispy_validate_message_param(instanceof(self), "AssertIsUndefined", _message)) return self;
		
		if (is_undefined(_expr))
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "Expression is not undefined.",
			}));
		}

		return self;
	}

	/// @description Test whether the provided expression is not undefined
	/// @param {Any} expr - Expression to check
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertIsNotUndefined = function(_expr, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertIsNotUndefined() expected 1 argument, received {argument_count}.", true);
		}
		if (!__crispy_validate_message_param(instanceof(self), "AssertIsNotUndefined", _message)) return self;
		
		if (!is_undefined(_expr))
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}
		else
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "Expression is undefined.",
			}));
		}

		return self;
	}

	/// @description Test whether the provided function will throw an error message
	/// @param {Function} func - Function to check whether it throws an error message
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertRaises = function(_func, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertRaises() expected 1 argument, received {argument_count}.", true);
		}

		if (!is_method(_func))
		{
			__crispy_error($"{instanceof(self)}.AssertRaises() \"func\" expected a function, received {typeof(_func)}.");
		}
		if (!__crispy_validate_message_param(instanceof(self), "AssertRaises", _message)) return self;
		
		try
		{
			_func();
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: "Error message was not thrown.",
			}));
		}
		catch (err)
		{
			AddLog(new CrispyLog(self, {
				__pass: true,
			}));
		}

		return self;
	}

	/// @description Test the value of the error message thrown in the provided function
	/// @param {Function} func - Function ran to throw an error message
	/// @param {String} value - Value of error message to check
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertRaiseErrorValue = function(_func, _value, _message)
	{
		// Check supplied arguments
		if (argument_count < 2)
		{
			show_error($"{instanceof(self)}.AssertRaiseErrorValue() expected 2 arguments, received {argument_count}.", true);
		}

		if (!is_method(_func))
		{
			__crispy_error($"{instanceof(self)}.AssertRaiseErrorValue() \"func\" expected a function, received {typeof(_func)}.");
		}
		
		if (!is_string(_value))
		{
			__crispy_error($"{instanceof(self)}.AssertRaiseErrorValue() \"value\" expected a string, received {typeof(_value)}.");
		}
		
		if (!__crispy_validate_message_param(instanceof(self), "AssertRaiseErrorValue", _message)) return self;
		
		try
		{
			_func();
			AddLog(new CrispyLog(self, {
				__pass: false,
				__helper_text: "Error message was not thrown.",
			}));
		}
		catch (err)
		{
			// If the error message was thrown using show_error, use the
			// message value from the exception struct for the assertion
			if (is_struct(err) && struct_exists(err, "message") && is_string(err.message))
			{
				err = err.message;
			}

			if (err == _value)
			{
				AddLog(new CrispyLog(self, {
					__pass: true,
				}));
			}
			else
			{
				AddLog(new CrispyLog(self, {
					__pass: false,
					__msg: _message,
					__helper_text: $"Error message is not equal to value: \"{err}\" != \"{_value}\"",
				}));
			}
		}

		return self;
	}

	/// @description Test whether the provided function runs without throwing an error
	/// @param {Function} func - Function to check whether it executes safely
	/// @param {String} [message] - Custom message to output on failure
	/// @returns {Struct.CrispyCase} Self for chaining
	static AssertDoesNotThrow = function(_func, _message)
	{
		// Check supplied arguments
		if (argument_count < 1)
		{
			show_error($"{instanceof(self)}.AssertDoesNotThrow() expected 1 argument, received {argument_count}.", true);
		}

		if (!is_method(_func))
		{
			__crispy_error($"{instanceof(self)}.AssertDoesNotThrow() \"func\" expected a function, received {typeof(_func)}.");
		}

		if (!__crispy_validate_message_param(instanceof(self), "AssertDoesNotThrow", _message)) return self;
		
		try
		{
			_func();
			AddLog(new CrispyLog(self, {
				__pass: true,
				__msg: _message,
			}));
		}
		catch (err)
		{
			AddLog(new CrispyLog(self, {
				__pass: false,
				__msg: _message,
				__helper_text: $"An unexpected error was thrown: {err}",
			}));
		}

		return self;
	}

	/// @description Function ran before test, used to set up test
	/// @param {Function} [func] - Method to override __SetUp with
	/// @returns {Struct.CrispyCase} Self for chaining
	static SetUp = function(_func)
	{
		if (!is_undefined(_func))
		{
			var _bound = __crispy_validate_and_bind_method(instanceof(self), "SetUp", _func);
			if (!is_undefined(_bound))
			{
				__SetUp = _bound;
			}
		}
		else
		{
			ClearLogs();
			if (is_method(__SetUp))
			{
				__SetUp();
			}
		}

		return self;
	}

	/// @description Function ran after test, used to clean up test
	/// @param {Function} [func] - Method to override __TearDown with
	/// @returns {Struct.CrispyCase} Self for chaining
	static TearDown = function(_func)
	{
		if (!is_undefined(_func))
		{
			var _bound = __crispy_validate_and_bind_method(instanceof(self), "TearDown", _func);
			if (!is_undefined(_bound))
			{
				__TearDown = _bound;
			}
		}
		else
		{
			if (is_method(__TearDown))
			{
				__TearDown();
			}
		}
		
		return self;
	}

	/// @description Set of functions to run in order for the test
	static Run = function()
	{
		if (__skipped) return self;
		
		var _start_time = get_timer();
		
		SetUp();
		OnRunBegin();
		
		__test();

		OnRunEnd();
		TearDown();
		
		__duration = (get_timer() - _start_time) / 1000000;
		
		return self;
	}

	/// @description Sets up a discovered script to use as the test
	/// @param {Real} script - Index ID of script
	/// @ignore
	static __Discover = function(_script)
	{
		if (!is_real(_script))
		{
			__crispy_error($"{instanceof(self)}.__Discover() \"script\" expected a real number, received {typeof(_script)}.");
		}

		if (!script_exists(_script))
		{
			__crispy_error($"{instanceof(self)}.__Discover() asset of index {_script} is not a script function.");
		}
		
		__discovered_script = _script;
		__is_discovered = true;
		__test = method(self, _script);
	}

	/// @returns {String}
	static toString = function()
	{
		return $"<Crispy Case(\"{__name}\")>";
	}
    
    /// @ignore
    static __DeepEqual = function(_a, _b)
		{
			if (typeof(_a) != typeof(_b)) return false;

			if (is_array(_a))
			{
				if (array_length(_a) != array_length(_b)) return false;

				var _i = 0; repeat (array_length(_a))
				{
					if (!__DeepEqual(_a[_i], _b[_i])) return false;
					++_i;
				}

				return true;
			}

			if (is_struct(_a))
			{
				var _a_keys = struct_get_names(_a);
				var _b_keys = struct_get_names(_b);
				if (array_length(_a_keys) != array_length(_b_keys)) return false;

				array_sort(_a_keys, true);
				array_sort(_b_keys, true);

				var _k = 0; repeat (array_length(_a_keys))
				{
					var _name = _a_keys[_k];
					if (_name != _b_keys[_k]) return false;
					if (!__DeepEqual(struct_get(_a, _name), struct_get(_b, _name))) return false;
					++_k;
				}

				return true;
			}

			return (_a == _b);
		}
}