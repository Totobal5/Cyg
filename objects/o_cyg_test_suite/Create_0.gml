runner = new CrispyRunner("cyg_runner");

__cyg_test_core(runner);
__cyg_test_async_io(runner);
__cyg_test_storage_resilience(runner);
__cyg_test_chacha(runner);
__cyg_test_path_validation(runner);

runner.Run();