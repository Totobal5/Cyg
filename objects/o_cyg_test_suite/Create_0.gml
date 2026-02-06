runner = new TestRunner("Systemall_Tests");

tests_run = false;

// Inicializar estado de pruebas async
global.__cyg_async_test_state = {
    started: false,
    export_done: false,
    export_success: false,
    export_wait_frames: 0,
    import_done: false,
    import_success: false,
    import_data: undefined,
    test_file: undefined
};

__cyg_test_core(runner);
__cyg_test_async_io(runner);