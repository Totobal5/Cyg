var runner = new TestRunner("Systemall_Tests");

__cyg_test_core(runner);

__cyg_test_sync_io(runner);

__cyg_test_async_io(runner);

__cyg_test_persistent_file(runner);

runner.run();