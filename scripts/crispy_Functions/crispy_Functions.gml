/// @description Returns the shared variables from the CrispyTest constructor.
/// @returns {Struct}
function crispy_vars()
{
	return CrispyTest.vars;
}

/// @ignore
/// @description Helper function for Crispy to display debug messages
/// @param {Any} msg - Text to be displayed in the Output Window
function __crispy_alert(_msg)
{
	if (CRISPY_DEBUG) show_debug_message(CRISPY_NAME + $"ALERT: {_msg}");
}

/// @ignore
/// @description Helper function for Crispy to display error messages. If CRISPY_STRICT_MODE is enabled, the game will also close immediately with an error.
/// @param {Any} msg - Text to be displayed in the Output Window
function __crispy_error(_msg)
{
	if (CRISPY_DEBUG) show_debug_message(CRISPY_NAME + $"ERROR: {_msg}");
	if (CRISPY_STRICT_MODE)
	{
		show_error(CRISPY_NAME + $"FATAL ERROR: {_msg}", true);
	}
}

/// @ignore
/// @description Helper function for structs that replaces variable values with given source struct values
/// @param {Struct} unpack - Struct used to replace existing values with
/// @param {Bool} [name_must_exist=true] - Boolean flag that prevents new variable names from being added to destination struct if variable name does not already exist
/// @ignore
function __crispy_struct_unpack(_unpack, _name_must_exist = true)
{
	if (!is_struct(_unpack))
	{
		__crispy_error($"__crispy_struct_unpack() \"unpack\" expected a struct, received {typeof(_unpack)}.");
	}
	if (!is_bool(_name_must_exist))
	{
		__crispy_error($"__crispy_struct_unpack() \"name_must_exist\" expected a boolean, received {typeof(_name_must_exist)}.");
	}

	var _names = struct_get_names(_unpack);
	var _len = array_length(_names);
	for (var _i = 0; _i < _len; ++_i)
	{
		var _name = _names[_i];

		if (!CRISPY_STRUCT_UNPACK_ALLOW_DUNDER && __crispy_is_internal_variable(_name))
		{
			if (CRISPY_DEBUG)
			{
				__crispy_alert($"Variable names beginning and ending in double underscores are reserved for the framework. Skip unpacking struct name: {_name}");
			}
			continue;
		}

		if (_name_must_exist && !struct_exists(self, _name))
		{
			if (CRISPY_DEBUG)
			{
				__crispy_alert($"Variable name \"{_name}\" not found in struct, skip writing variable name.");
			}
			continue;
		}

		struct_set(self, _name, struct_get(_unpack, _name));
	}
}

/// @ignore
/// @description Helper function that returns whether or not a given variable name follows internal variable naming convention
/// @param {String} name - Name of variable to check
/// @returns {Bool} Whether the given string follows internal variable naming convention
function __crispy_is_internal_variable(_name)
{
	if (!is_string(_name))
	{
		__crispy_error($"__crispy_is_internal_variable() \"name\" expected a string, received {typeof(_name)}.");
	}

	var _len = string_length(_name);
	if (_len >= 3 && string_copy(_name, 1, 2) == "__")
	{
		return true;
	}

	return false;
}

/// @ignore
/// @description Helper function to validate unpack parameter (DRY validation)
/// @param {String} context - Context for error message (e.g., "CrispyCase")
/// @param {String} method - Method name for error message
/// @param {Any} unpack - Unpack value to validate
/// @ignore
function __crispy_validate_unpack_param(_context, _method, _unpack)
{
	if (!is_undefined(_unpack))
	{
		if (is_struct(_unpack))
		{
			__crispy_struct_unpack(_unpack);
		}
		else
		{
			__crispy_error($"{_context}{(_method != "" ? $".{_method}() " : " ")}\"unpack\" expected a struct or undefined, received {typeof(_unpack)}.");
		}
	}
}

/// @ignore
/// @description Helper function to validate struct parameter type (DRY validation)
/// @param {String} context - Context for error message
/// @param {String} method - Method name for error message
/// @param {String} param_name - Parameter name for error message
/// @param {Any} param_value - Parameter value to validate
/// @returns {Bool} True if valid struct, false otherwise
/// @ignore
function __crispy_validate_struct_param(_context, _method, _param_name, _param_value)
{
	if (!is_struct(_param_value))
	{
		__crispy_error($"{_context}{(_method != "" ? $".{_method}() " : " ")}\"({_param_name})\" expected a struct, received {typeof(_param_value)}.");
		return false;
	}
	return true;
}

/// @ignore
/// @description Helper function to validate message parameter (DRY validation)
/// @param {String} context - Context for error message
/// @param {String} method - Method name for error message
/// @param {Any} message - Message value to validate
/// @returns {Bool} True if valid message or undefined, false otherwise
/// @ignore
function __crispy_validate_message_param(_context, _method, _message)
{
	if (!is_string(_message) && !is_undefined(_message))
	{
		__crispy_error($"{_context}.{_method}() \"message\" expected either a string or undefined, received {typeof(_message)}.");
		return false;
	}
	return true;
}

/// @ignore
/// @description Helper function to get type display string (DRY type checking)
/// @param {Any} value - Value to get type display for
/// @returns {String} Constructor name if struct, otherwise typeof
/// @ignore
function __crispy_get_type_display(_value)
{
	var _type = instanceof(_value);
	if (is_undefined(_type))
	{
		_type = typeof(_value);
	}
	return _type;
}

/// @ignore
/// @description Helper function to validate and set method parameter (DRY validation)
/// @param {String} context - Context for error message
/// @param {String} method_name - Method name being set
/// @param {Any} func - Function value to validate
/// @returns {Struct} Bound method if valid, undefined otherwise
/// @ignore
function __crispy_validate_and_bind_method(_context, _method_name, _func)
{
	if (is_method(_func))
	{
		return method(self, _func);
	}
	else
	{
		__crispy_error($"{_context}.{_method_name}() \"func\" expected a function, received {typeof(_func)}.");
		return undefined;
	}
}

/// @ignore
/// @description Helper function to validate specific type parameter (DRY validation)
/// @param {String} context - Context for error message
/// @param {String} method - Method name for error message
/// @param {String} param_name - Parameter name for error message
/// @param {Any} param_value - Parameter value to validate
/// @param {String} expected_type - Expected type name (e.g., "string", "real", "bool")
/// @returns {Bool} True if valid type, false otherwise
/// @ignore
function __crispy_validate_type_param(_context, _method, _param_name, _param_value, _expected_type)
{
	var _is_valid = false;
	switch (_expected_type)
	{
		case "string":
			_is_valid = is_string(_param_value);
		break;

		case "real":
			_is_valid = is_real(_param_value);
		break;

		case "bool":
			_is_valid = is_bool(_param_value);
		break;

		case "array":
			_is_valid = is_array(_param_value);
		break;

		case "method":
			_is_valid = is_method(_param_value);
		break;

		default:
			__crispy_error($"__crispy_validate_type_param() \"expected_type\" received unknown type: {_expected_type}");
			return false;
	}
	
	if (!_is_valid)
	{
		__crispy_error($"{_context}.{_method}() \"{_param_name}\" expected a {_expected_type}, received {typeof(_param_value)}.");
		return false;
	}

	return true;
}
