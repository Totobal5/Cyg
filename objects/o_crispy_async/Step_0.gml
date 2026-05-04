/// @description Relay Step to the attached async case.

if (is_struct(async_case) && struct_exists(async_case, "OnStep"))
{
	var _on_step = struct_get(async_case, "OnStep");
	if (is_method(_on_step))
	{
		var _bound = method(async_case, _on_step);
		_bound();
	}
	else
	{
		instance_destroy();
	}
}
else
{
	instance_destroy();
}
