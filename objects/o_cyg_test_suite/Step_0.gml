/// @description Advance the Crispy runner while async cases are active.
if (!is_undefined(runner) && runner.IsRunning())
{
	runner.Update();
}