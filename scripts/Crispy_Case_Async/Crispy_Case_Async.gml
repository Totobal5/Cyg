/// @description Creates an asynchronous test case driven by Begin Step, Step, and End Step events.
/// @param {String} name - Name of case
/// @param {Struct} [unpack=undefined] - Struct for struct_unpack
function CrispyCaseAsync(_name, _unpack = undefined) : CrispyCase(_name, function(){}, _unpack) constructor
{
	/// @ignore
	__is_async = true;
	/// @ignore
	__is_running = false;
	/// @ignore
	__is_complete = false;
	/// @ignore
	__host_id = noone;
	/// @ignore
	__checkpoints = [];
	/// @ignore
	__current_checkpoint = 0;
	/// @ignore
	__timeout_value = undefined;
	/// @ignore
	__timeout_unit = undefined;
	/// @ignore
	__elapsed_frames = 0;
	/// @ignore
	__run_started_at = 0;
	/// @ignore
	__suite_on_run_end_pending = false;
	/// @ignore
	__rebuild_on_start = false;

	#region METHODS

	/// @description Returns whether this case is asynchronous.
	/// @returns {Bool}
	static IsAsync = function()
	{
		return __is_async;
	}

	/// @description Returns whether this case is currently running.
	/// @returns {Bool}
	static IsRunning = function()
	{
		return __is_running;
	}

	/// @description Returns whether this case has finished running.
	/// @returns {Bool}
	static IsComplete = function()
	{
		return __is_complete;
	}

	/// @description Alias for IsComplete.
	/// @returns {Bool}
	static IsFinished = function()
	{
		return __is_complete;
	}

	/// @description Sets a timeout for this async case.
	/// @param {Real} value - Timeout amount
	/// @param {String} [unit="frames"] - Either "frames" or "seconds"
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static Timeout = function(_value, _unit = "frames")
	{
		if (!is_real(_value))
		{
			__crispy_error($"{instanceof(self)}.Timeout() \"value\" expected a real number, received {typeof(_value)}.");
			return self;
		}

		if (!is_string(_unit))
		{
			__crispy_error($"{instanceof(self)}.Timeout() \"unit\" expected a string, received {typeof(_unit)}.");
			return self;
		}

		if (_unit != "frames" && _unit != "seconds")
		{
			__crispy_error($"{instanceof(self)}.Timeout() \"unit\" expected either \"frames\" or \"seconds\", received {_unit}.");
			return self;
		}

		__timeout_value = _value;
		__timeout_unit = _unit;

		return self;
	}

	/// @description Queue a callback to run on Begin Step.
	/// @param {Function} func - Callback for Begin Step
	/// @param {Struct|Real} [context=undefined] - Execution context for callback. Defaults to this async case.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static WaitBeginStep = function(_func, _context)
	{
		return __QueueCheckpoint("begin_step", _func, "WaitBeginStep", _context);
	}

	/// @description Queue a callback to run on Step.
	/// @param {Function} func - Callback for Step
	/// @param {Struct|Real} [context=undefined] - Execution context for callback. Defaults to this async case.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static WaitStep = function(_func, _context)
	{
		return __QueueCheckpoint("step", _func, "WaitStep", _context);
	}

	/// @description Queue a callback to run on End Step.
	/// @param {Function} func - Callback for End Step
	/// @param {Struct|Real} [context=undefined] - Execution context for callback. Defaults to this async case.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static WaitEndStep = function(_func, _context)
	{
		return __QueueCheckpoint("end_step", _func, "WaitEndStep", _context);
	}

	/// @description Manually completes the async case.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static Complete = function()
	{
		if (__is_complete)
		{
			return self;
		}

		__is_running = false;
		__is_complete = true;
		__DestroyHost();
		OnRunEnd();
		TearDown();
		__duration = (get_timer() - __run_started_at) / 1000000;

		return self;
	}

	/// @description Fails the async case and completes it.
	/// @param {String} [message="Async case failed."] - Failure message
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static Fail = function(_message = "Async case failed.")
	{
		if (!__crispy_validate_message_param(instanceof(self), "Fail", _message)) return self;

		AddLog(new CrispyLog(self, {
			__pass: false,
			__msg: _message,
		}));

		return Complete();
	}

	/// @description Starts the async case and creates its host instance.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static Start = function()
	{
		if (__skipped)
		{
			__is_running = false;
			__is_complete = true;
			__duration = 0;
			return self;
		}

		ClearLogs();
		__is_complete = false;
		__is_running = true;
		__current_checkpoint = 0;
		__elapsed_frames = 0;
		__run_started_at = get_timer();

		SetUp();
		OnRunBegin();

		if (__rebuild_on_start)
		{
			__checkpoints = [];
			__test();
		}

		__CreateHost();

		if (array_length(__checkpoints) == 0)
		{
			Complete();
		}

		return self;
	}

	/// @description Compatibility alias for asynchronous execution.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static Run = function()
	{
		return Start();
	}

	/// @description Configure this async case using a builder function executed at Start.
	/// @param {Function} func - Builder that queues checkpoints
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static Configure = function(_func)
	{
		var _bound = __crispy_validate_and_bind_method(instanceof(self), "Configure", _func);
		if (is_undefined(_bound))
		{
			return self;
		}

		__test = _bound;
		__rebuild_on_start = true;

		return self;
	}

	/// @description Handles Begin Step from the async host.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static OnBeginStep = function()
	{
		if (__is_running)
		{
			++__elapsed_frames;
			__HandleEvent("begin_step");
		}

		return self;
	}

	/// @description Handles Step from the async host.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static OnStep = function()
	{
		if (__is_running)
		{
			__HandleEvent("step");
		}

		return self;
	}

	/// @description Handles End Step from the async host.
	/// @returns {Struct.CrispyCaseAsync} Self for chaining
	static OnEndStep = function()
	{
		if (__is_running)
		{
			__HandleEvent("end_step");
		}

		return self;
	}

	/// @returns {String}
	static toString = function()
	{
		return $"<Crispy Async Case(\"{__name}\")>";
	}

	/// @ignore
	static __QueueCheckpoint = function(_event_name, _func, _method_name, _context)
	{
		if (!is_method(_func))
		{
			__crispy_error($"{instanceof(self)}.{_method_name}() \"func\" expected a function, received {typeof(_func)}.");
			return self;
		}

		if (!is_undefined(_context))
		{
			var _is_instance_context = is_real(_context) && instance_exists(_context);
			if (!is_struct(_context) && !_is_instance_context)
			{
				__crispy_error($"{instanceof(self)}.{_method_name}() \"context\" expected a struct, instance id, or undefined, received {typeof(_context)}.");
				return self;
			}
		}

		var _callback_context = is_undefined(_context) ? self : _context;
		var _bound = method(_callback_context, _func);

		array_push(__checkpoints, {
			event_name: _event_name,
			callback: _bound,
			context: _callback_context,
		});

		return self;
	}

	/// @ignore
	static __HandleEvent = function(_event_name)
	{
		if (__is_complete || !__is_running)
		{
			return self;
		}

		if (__current_checkpoint >= array_length(__checkpoints))
		{
			return Complete();
		}

		var _checkpoint = __checkpoints[__current_checkpoint];
		if (_checkpoint.event_name != _event_name)
		{
			__CheckTimeout();
			return self;
		}

		var _result = _checkpoint.callback();
		if (is_bool(_result))
		{
			if (_result)
			{
				++__current_checkpoint;
			}
		}
		else
		{
			++__current_checkpoint;
		}

		if (__current_checkpoint >= array_length(__checkpoints) && __is_running)
		{
			Complete();
		}

		if (__is_running)
		{
			__CheckTimeout();
		}

		return self;
	}

	/// @ignore
	static __CheckTimeout = function()
	{
		if (is_undefined(__timeout_value) || is_undefined(__timeout_unit))
		{
			return false;
		}

		var _timed_out = false;
		switch (__timeout_unit)
		{
			case "frames":
				_timed_out = (__elapsed_frames >= __timeout_value);
			break;

			case "seconds":
				var _elapsed_seconds = (get_timer() - __run_started_at) / 1000000;
				_timed_out = (_elapsed_seconds >= __timeout_value);
			break;
		}

		if (_timed_out)
		{
			Fail($"Async case timed out after {string(__timeout_value)} {__timeout_unit}.");
		}

		return _timed_out;
	}

	/// @ignore
	static __CreateHost = function()
	{
		if (instance_exists(__host_id))
		{
			with (__host_id) instance_destroy();
		}

		var _case = self;
		__host_id = instance_create_depth(0, 0, 0, o_crispy_async);
		variable_instance_set(__host_id, "async_case", _case);
	}

	/// @ignore
	static __DestroyHost = function()
	{
		if (instance_exists(__host_id))
		{
			with (__host_id) instance_destroy();
		}

		__host_id = noone;
	}

	/// @description Sets up a discovered script to use as the async test builder.
	/// @param {Real} script - Index ID of script
	/// @ignore
	static __Discover = function(_script)
	{
		if (!is_real(_script))
		{
			__crispy_error($"{instanceof(self)}.__Discover() \"script\" expected a real number, received {typeof(_script)}.");
			return self;
		}

		if (!script_exists(_script))
		{
			__crispy_error($"{instanceof(self)}.__Discover() asset of index {_script} is not a script function.");
			return self;
		}

		__discovered_script = _script;
		__is_discovered = true;
		__test = method(self, _script);
		__rebuild_on_start = true;

		return self;
	}

	#endregion
}