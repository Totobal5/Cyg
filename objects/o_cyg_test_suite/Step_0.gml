/// @description Orquesta pruebas async y ejecuta runner al completar.
if (is_undefined(runner)) {
    exit;
}

if (!global.__cyg_async_test_state.started)
{
    global.__cyg_async_test_state.test_file = working_directory + "cyg_test_async.dat";
    global.__cyg_async_test_state.started = true;

    show_debug_message("CYG TEST: working_directory=" + working_directory);
    show_debug_message("CYG TEST: test_file=" + global.__cyg_async_test_state.test_file);

    Cyg.SetEncryptKey("async_key");
    Cyg.Add("game_settings", { difficulty: "hard" });

    var _test_file = global.__cyg_async_test_state.test_file;

    Cyg.Export(_test_file, "game_settings", true, function(_success) {
        show_debug_message("CYG TEST: Export callback ejecutado, success=" + string(_success));
        show_debug_message("CYG TEST: file_exists(" + global.__cyg_async_test_state.test_file + ")=" + string(file_exists(global.__cyg_async_test_state.test_file)));
        global.__cyg_async_test_state.export_done = true;
        global.__cyg_async_test_state.export_success = _success;
        global.__cyg_async_test_state.export_wait_frames = 2;

        if (!_success)
        {
            global.__cyg_async_test_state.import_done = true;
            global.__cyg_async_test_state.import_success = false;
        }
    });
}

// Esperar X frames después del export para sincronización de disco
if (global.__cyg_async_test_state.export_wait_frames > 0)
{
    global.__cyg_async_test_state.export_wait_frames--;
    if (global.__cyg_async_test_state.export_wait_frames == 0)
    {
        show_debug_message("CYG TEST: Esperados frames, iniciando Import");
        Cyg.Remove("game_settings");
        Cyg.Import(global.__cyg_async_test_state.test_file, "game_settings", true, function(_success_import, _data) {
            show_debug_message("CYG TEST: Import callback ejecutado, success=" + string(_success_import));
            show_debug_message("CYG TEST: Import data: " + string(_data));
            global.__cyg_async_test_state.import_done = true;
            global.__cyg_async_test_state.import_success = _success_import;
            global.__cyg_async_test_state.import_data = _data;
        });
    }
}

if (!tests_run && global.__cyg_async_test_state.import_done)
{
    show_debug_message("CYG TEST: Ejecutando runner.run() con async tests completados");
    tests_run = true;
    runner.run();
}
