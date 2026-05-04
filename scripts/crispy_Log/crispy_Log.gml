/// @description Saves the result and output of assertion
/// @param {Struct} test_case - Struct that holds the test case
/// @param {Struct} [unpack=undefined] - Struct to use with crispy_struct_unpack
function CrispyLog(_test_case, _unpack = undefined) constructor
{
	if (!__crispy_validate_struct_param(instanceof(self), "", "_test_case", _test_case)) return;

	__struct_unpack = method(self, __crispy_struct_unpack);

	/// @ignore
	__verbosity = CRISPY_VERBOSITY;
	/// @ignore
	__pass = true;
	/// @ignore
	__msg = undefined;
	/// @ignore
	__helper_text = undefined;
	/// @ignore
	__skipped = false;
	/// @ignore
	__class = _test_case.__class;
	/// @ignore
	__name = _test_case.__name;
	/// @ignore
	__duration = 0;
	/// @ignore
	__display_name = undefined;

	// Create the display name of log based on CrispyCase name and class
	var _display_name = "";
	if (!is_undefined(__name))
	{
		_display_name += __name;
	}
	
	if (!is_undefined(__class))
	{
		_display_name += (_display_name != "" ? "." + __class : __class);
	}

	/// @ignore
	__display_name = _display_name;

	/// Apply supported internal overrides explicitly so CrispyLog can receive
	/// framework-owned fields without enabling global dunder unpacking.
	if (!is_undefined(_unpack))
	{
		if (!is_struct(_unpack))
		{
			__crispy_error($"{instanceof(self)} \"unpack\" expected a struct or undefined, received {typeof(_unpack)}.");
		}
		else
		{
			if (struct_exists(_unpack, "__verbosity")) __verbosity = struct_get(_unpack, "__verbosity");
			if (struct_exists(_unpack, "__pass")) __pass = struct_get(_unpack, "__pass");
			if (struct_exists(_unpack, "__msg")) __msg = struct_get(_unpack, "__msg");
			if (struct_exists(_unpack, "__helper_text")) __helper_text = struct_get(_unpack, "__helper_text");
			if (struct_exists(_unpack, "__skipped")) __skipped = struct_get(_unpack, "__skipped");
			if (struct_exists(_unpack, "__class")) __class = struct_get(_unpack, "__class");
			if (struct_exists(_unpack, "__name")) __name = struct_get(_unpack, "__name");
			if (struct_exists(_unpack, "__duration")) __duration = struct_get(_unpack, "__duration");
			if (struct_exists(_unpack, "__display_name")) __display_name = struct_get(_unpack, "__display_name");
		}
	}

	#region METHODS

	/// @description Constructs text based on outcome of test assertion and verbosity
	/// @returns {String} Text based on outcome of test assertion and verbosity
	static GetMsg = function()
	{
		var _msg = (__verbosity == 2 && __display_name != "") ? __display_name + " " : "";

		switch (__verbosity)
		{
			case 0:
				if (__skipped)
				{
					_msg += "S"; // Skipped
				}
				else
				{
					_msg += __pass ? CRISPY_PASS_MSG_SILENT : CRISPY_FAIL_MSG_SILENT;
				}
			break;

			case 1: // Think of something better for this later
			case 2:
				if (__skipped)
				{
					_msg += "...skipped";
				}
				else if (__pass)
				{
					_msg += "..." + CRISPY_PASS_MSG_VERBOSE;
					if (__duration >= 0)
					{
						var _duration_str = "";
						if (__duration < 0.001)
						{
							_duration_str = string_format(__duration * 1000000, 0, 2) + "us";
						}
						else if (__duration < 1)
						{
							_duration_str = string_format(__duration * 1000, 0, 2) + "ms";
						}
						else
						{
							_duration_str = string_format(__duration, 0, 2) + "s";
						}
						_msg += " (" + _duration_str + ")";
					}
				}
				else
				{
					var _has_msg = !is_undefined(__msg) && __msg != "";
					var _has_helper_text = !is_undefined(__helper_text) && __helper_text != "";

					if (!is_undefined(__msg) && __msg != "")
					{
						_msg += "- " + __msg;

						if (_has_helper_text)
						{
							_msg += "\n" + __helper_text;
						}
					}
					else if (_has_helper_text)
					{
						_msg += "- " + __helper_text;
					}
					else if (!_has_msg && !_has_helper_text)
					{
						_msg += "- Assertion failed.";
					}
				}
			break;
		}

		return _msg;
	}

	/// @returns {String}
	static toString = function()
	{
		return $"<Crispy Log ({(__pass ? "pass" : "fail")})>";
	}

	#endregion
}