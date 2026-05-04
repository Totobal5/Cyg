/// @description Testing suite that holds tests
/// @param {String} name - Name of suite
/// @param {Struct} [unpack=undefined] - Struct for crispy_struct_unpack
/// @return {Struct.CrispySuite} description
function CrispySuite(_name, _unpack = undefined) : CrispyTest(_name) constructor 
{
	/// @ignore
	__parent = undefined;

	/// @ignore
	__tests = [];
	/// @ignore
	__is_running = false;
	/// @ignore
	__is_complete = false;

	/// Run struct unpacker if unpack argument was provided
	/// Stays after all variables are initialized so they may be overwritten
	__crispy_validate_unpack_param(instanceof(self), "", _unpack);

	#region METHODS

	/// @description Adds CrispyCase to array of cases
	/// @param {Struct} test_case - CrispyCase to add
	/// @returns {Struct.CrispySuite} Self for chaining
	static AddCase = function(_test_case)
	{
		var _class = instanceof(_test_case);
		if (_class != "CrispyCase" && _class != "CrispyCaseAsync")
		{
			var _type = !is_undefined(instanceof(_test_case)) ? instanceof(_test_case) : typeof(_test_case);
			__crispy_error($"{instanceof(self)}.AddCase() \"_test_case\" expected an instance of CrispyCase or CrispyCaseAsync, received {_type}.");
		}
		
		_test_case.__parent = self;
		array_push(__tests, _test_case);

		return self;
	}

	/// @description Returns whether the suite is currently running.
	/// @returns {Bool}
	static IsRunning = function()
	{
		return __is_running;
	}

	/// @description Returns whether the suite has completed.
	/// @returns {Bool}
	static IsComplete = function()
	{
		return __is_complete;
	}

	/// @description Event that runs before all tests to set up variables. Can also overwrite __SetUp
	/// @param {Function} [func] - Function to overwrite __SetUp
	/// @return {Struct.CrispySuite} Self for chaining
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
			if (is_method(__SetUp))
			{
				__SetUp();
			}
		}

		return self;
	}

	/// @description Event that runs after all tests to clean up variables. Can also overwrite __TearDown
	/// @param {Function} [func] - Function to overwrite __TearDown
	/// @return {Struct.CrispySuite} Self for chaining
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

	/// @description Runs tests
	/// @returns {Struct.CrispySuite} Self for chaining
	static Run = function()
	{
		__is_complete = false;
		__is_running = true;
		SetUp();

		var _has_async_running = false;
		var i = 0; repeat(array_length(__tests) )
		{
			var _test = __tests[i++];
			OnRunBegin();

			if (instanceof(_test) == "CrispyCaseAsync")
			{
				_test.__suite_on_run_end_pending = true;
				_test.Start();

				if (_test.IsComplete())
				{
					if (_test.__suite_on_run_end_pending)
					{
						OnRunEnd();
						_test.__suite_on_run_end_pending = false;
					}
				}
				else
				{
					_has_async_running = true;
				}
			}
			else
			{
				_test.Run();
				OnRunEnd();
			}
		}

		if (!_has_async_running)
		{
			__FinalizeRun();
		}

		return self;
	}

	/// @description Updates asynchronous tests and finalizes the suite when they complete.
	/// @returns {Struct.CrispySuite} Self for chaining
	static Update = function()
	{
		if (!__is_running)
		{
			return self;
		}

		var _has_async_running = false;
		var _i = 0; repeat(array_length(__tests))
		{
			var _test = __tests[_i++];
			if (instanceof(_test) != "CrispyCaseAsync")
			{
				continue;
			}

			if (_test.IsRunning())
			{
				_has_async_running = true;
				continue;
			}

			if (_test.__suite_on_run_end_pending && _test.IsComplete())
			{
				OnRunEnd();
				_test.__suite_on_run_end_pending = false;
			}
		}

		if (!_has_async_running)
		{
			__FinalizeRun();
		}

		return self;
	}

	/// @ignore
	static __FinalizeRun = function()
	{
		if (__is_complete)
		{
			return self;
		}

		TearDown();
		__is_running = false;
		__is_complete = true;

		return self;
	}

	/// @returns {String}
	static toString = function()
	{
		return $"<Crispy Suite(\"{__name}\")>";
	}

	#endregion
}